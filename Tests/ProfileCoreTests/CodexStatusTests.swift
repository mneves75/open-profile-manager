import Foundation
import Testing

@testable import ProfileCore

@Suite("Codex app-server status")
struct CodexStatusTests {
  @Test("Documented account and rate-limit fields parse from JSONL")
  func parsesDocumentedFields() throws {
    let profile = try testProfile()
    let messages = [
      Data("{\"id\":1,\"result\":{\"userAgent\":\"ignored\"}}".utf8),
      Data(
        "{\"id\":2,\"result\":{\"account\":{\"type\":\"chatgpt\",\"email\":\"person@example.com\",\"planType\":\"plus\",\"ignored\":\"value\"},\"requiresOpenaiAuth\":true}}"
          .utf8),
      Data(
        "{\"id\":3,\"result\":{\"rateLimits\":{\"planType\":\"plus\",\"primary\":{\"usedPercent\":12,\"resetsAt\":1234,\"windowDurationMins\":300},\"secondary\":{\"usedPercent\":34,\"resetsAt\":5678,\"windowDurationMins\":10080},\"credits\":{\"hasCredits\":true,\"unlimited\":false,\"balance\":\"9.5\"}},\"rateLimitResetCredits\":{\"availableCount\":5}}}"
          .utf8),
    ]

    let status = CodexStatusService.parseStatus(profile: profile, messages: messages)
    #expect(status.state == .available)
    #expect(
      status.account
        == AccountSummary(
          type: "chatgpt",
          email: "person@example.com",
          planType: "plus"
        ))
    #expect(status.rateLimits?.primary?.usedPercent == 12)
    #expect(status.rateLimits?.secondary?.windowDurationMinutes == 10_080)
    #expect(status.rateLimits?.hasCredits == true)
    #expect(status.rateLimits?.unlimitedCredits == false)
  }

  @Test("Missing account is a typed unauthenticated status")
  func notAuthenticated() throws {
    let profile = try testProfile()
    let status = CodexStatusService.parseStatus(
      profile: profile,
      messages: [Data("{\"id\":2,\"result\":{\"account\":null,\"requiresOpenaiAuth\":true}}".utf8)]
    )
    #expect(status.state == .notAuthenticated)
    #expect(status.account == nil)
    #expect(status.message?.contains("opm login status") == true)
  }

  @Test("Profiles that do not require OpenAI auth remain available")
  func authenticationNotRequired() throws {
    let profile = try testProfile()
    let status = CodexStatusService.parseStatus(
      profile: profile,
      messages: [Data("{\"id\":2,\"result\":{\"account\":null,\"requiresOpenaiAuth\":false}}".utf8)]
    )
    #expect(status.state == .available)
    #expect(status.account == nil)
  }

  @Test("Untrusted status fields are bounded and validated")
  func boundsParsedFields() throws {
    let profile = try testProfile()
    let oversizedEmail = String(repeating: "e", count: 321)
    let messages = [
      Data(
        "{\"id\":2,\"result\":{\"account\":{\"type\":\"chatgpt\",\"email\":\"\(oversizedEmail)\",\"planType\":\"plus\\nspoof\"},\"requiresOpenaiAuth\":true}}"
          .utf8),
      Data(
        "{\"id\":3,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":1001}}}}"
          .utf8),
    ]

    let status = CodexStatusService.parseStatus(profile: profile, messages: messages)
    #expect(status.account?.email == nil)
    #expect(status.account?.planType == nil)
    #expect(status.rateLimits?.primary == nil)
  }

  @Test("Child output is bounded and the child is terminated promptly")
  func boundsHostileOutput() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("status"),
      displayName: "Status",
      codexHome: root
    )
    let service = CodexStatusService(timeout: 0.25, outputLimit: 2_048)
    let start = ContinuousClock.now
    let status = service.readStatus(
      for: profile,
      codexExecutable: URL(fileURLWithPath: "/usr/bin/yes"),
      environment: ["PATH": "/usr/bin"]
    )
    let elapsed = start.duration(to: .now)
    #expect(status.state == .unavailable)
    #expect(elapsed < .seconds(2))
  }

  @Test("Output limits remain enforced after account status arrives")
  func boundsOutputAfterAccountResponse() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusLateOutputTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      IFS= read -r _
      printf '%s\\n' '{"id":1,"result":{}}'
      IFS= read -r _
      IFS= read -r _
      printf '%s\\n' '{"id":2,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}'
      /bin/sleep 0.1
      /usr/bin/yes X | /usr/bin/head -c 4096
      /bin/sleep 1
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("late-output"),
      displayName: "Late output",
      codexHome: root
    )

    let status = CodexStatusService(timeout: 2, outputLimit: 512).readStatus(
      for: profile,
      codexExecutable: executable,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(status.state == .unavailable)
    #expect(status.message == "Codex app-server exceeded the status output limit.")
  }

  @Test("Closed app-server input reports failure without SIGPIPE")
  func closedAppServerInput() throws {
    let pipe = Pipe()
    try pipe.fileHandleForReading.close()

    #expect(
      !CodexStatusService.writeSafely(
        Data("request\n".utf8),
        to: pipe.fileHandleForWriting
      )
    )
  }

  @Test("Record counts are bounded independently of output bytes")
  func boundsTinyRecords() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusRecordTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      IFS= read -r _
      printf '%s\\n' '{"id":1,"result":{}}'
      IFS= read -r _
      IFS= read -r _
      printf '%s\\n' '{"id":2,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}'
      /bin/sleep 0.1
      index=0
      while [ "$index" -lt 300 ]; do
        printf '{}\\n'
        index=$((index + 1))
      done
      /bin/sleep 1
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("records"),
      displayName: "Records",
      codexHome: root
    )

    let status = CodexStatusService(timeout: 2, outputLimit: 4_096).readStatus(
      for: profile,
      codexExecutable: executable,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(status.state == .unavailable)
    #expect(status.message == "Codex app-server exceeded the status output limit.")
  }

  @Test("Batch status reads run concurrently and preserve requested order")
  func readsStatusesConcurrently() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusBatchTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)

    let registryDirectory = root.appendingPathComponent("registry", isDirectory: true)
    let manager = try ProfileManager(
      registryURL: registryDirectory.appendingPathComponent("profiles.json"),
      applicationSupportDirectory: registryDirectory
    )
    for id in ["alpha", "beta"] {
      _ = try manager.addProfile(
        id: id,
        displayName: id.capitalized,
        codexHome: root.appendingPathComponent("\(id)-home", isDirectory: true)
      )
    }

    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      barrier=$(/usr/bin/dirname "$CODEX_HOME")
      profile=$(/usr/bin/basename "$CODEX_HOME")
      /usr/bin/touch "$barrier/ready-$profile"
      attempts=0
      while [ ! -f "$barrier/ready-alpha-home" ] || [ ! -f "$barrier/ready-beta-home" ]; do
        attempts=$((attempts + 1))
        [ "$attempts" -lt 200 ] || exit 1
        /bin/sleep 0.01
      done
      IFS= read -r _
      printf '%s\n' '{"id":1,"result":{}}'
      IFS= read -r _
      IFS= read -r _
      IFS= read -r _
      printf '%s\n' '{"id":2,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}'
      printf '%s\n' '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":1}}}}'
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)

    let statuses = try await manager.statuses(
      profileIDs: ["beta", "alpha"],
      service: CodexStatusService(timeout: 3),
      codexExecutable: executable
    )
    #expect(statuses.map(\.profileID.rawValue) == ["beta", "alpha"])
    #expect(statuses.allSatisfy { $0.state == .available })
  }

  private func testProfile() throws -> Profile {
    try Profile(
      id: ProfileID("status"),
      displayName: "Status",
      codexHome: URL(fileURLWithPath: "/tmp/opm-status")
    )
  }
}
