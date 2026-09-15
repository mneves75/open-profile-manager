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

  @Test("Numeric authentication flags fail closed")
  func rejectsNumericAuthenticationFlag() throws {
    let profile = try testProfile()
    let status = CodexStatusService.parseStatus(
      profile: profile,
      messages: [Data("{\"id\":2,\"result\":{\"account\":null,\"requiresOpenaiAuth\":0}}".utf8)]
    )
    #expect(status.state == .notAuthenticated)
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
        "{\"id\":3,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":1.5},\"secondary\":{\"usedPercent\":12,\"resetsAt\":true,\"windowDurationMins\":9223372036854775808},\"credits\":{\"hasCredits\":1,\"unlimited\":0}}}}"
          .utf8),
    ]

    let status = CodexStatusService.parseStatus(profile: profile, messages: messages)
    #expect(status.account?.email == nil)
    #expect(status.account?.planType == nil)
    #expect(status.rateLimits?.primary == nil)
    #expect(status.rateLimits?.secondary?.usedPercent == 12)
    #expect(status.rateLimits?.secondary?.resetsAt == nil)
    #expect(status.rateLimits?.secondary?.windowDurationMinutes == nil)
    #expect(status.rateLimits?.hasCredits == nil)
    #expect(status.rateLimits?.unlimitedCredits == nil)
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

  @Test("Cooperative app-server termination does not consume the grace period")
  func cooperativeTermination() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusTerminationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let marker = root.appendingPathComponent("response-ready")
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      trap 'exit 0' TERM
      IFS= read -r _
      printf '%s\\n' '{"id":1,"result":{}}'
      IFS= read -r _
      IFS= read -r _
      IFS= read -r _
      /usr/bin/touch "$CODEX_HOME/response-ready"
      printf '%s\\n' '{"id":2,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}'
      printf '%s\\n' '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":1}}}}'
      while :; do :; done
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("termination"),
      displayName: "Termination",
      codexHome: root
    )

    let status = CodexStatusService(timeout: 2).readStatus(
      for: profile,
      codexExecutable: executable,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    let responseDate = try #require(
      marker.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    )
    #expect(status.state == .available)
    #expect(Date().timeIntervalSince(responseDate) < 0.09)
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

  @Test("An unterminated final record cannot bypass the record-count limit")
  func boundsUnterminatedFinalRecord() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusFinalRecordTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      IFS= read -r _
      printf '%s\\n' '{\"id\":1,\"result\":{}}'
      IFS= read -r _
      IFS= read -r _
      IFS= read -r _
      printf '%s\\n' '{\"id\":2,\"result\":{\"account\":{\"type\":\"chatgpt\"},\"requiresOpenaiAuth\":true}}'
      index=0
      while [ "$index" -lt 254 ]; do
        printf '{}\\n'
        index=$((index + 1))
      done
      printf '%s' '{\"id\":3,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":1}}}}'
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("final-record"),
      displayName: "Final record",
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

  @Test("Batch status reads use supplied profiles concurrently and preserve requested order")
  func readsStatusesConcurrently() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusBatchTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)

    let registryDirectory = root.appendingPathComponent("registry", isDirectory: true)
    let registryURL = registryDirectory.appendingPathComponent("profiles.json")
    let manager = try ProfileManager(
      registryURL: registryURL,
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

    let listedProfiles = try manager.listProfiles()
    let alpha = try #require(listedProfiles.first { $0.id.rawValue == "alpha" })
    let beta = try #require(listedProfiles.first { $0.id.rawValue == "beta" })
    try Data("{malformed".utf8).write(to: registryURL)
    #expect(chmod(registryURL.path, 0o600) == 0)

    let statuses = await manager.statuses(
      profiles: [beta, alpha],
      service: CodexStatusService(timeout: 3),
      codexExecutable: executable
    )
    #expect(statuses.map(\.profileID.rawValue) == ["beta", "alpha"])
    #expect(statuses.allSatisfy { $0.state == .available })
  }

  @Test("Blocked app-server reads leave Swift's cooperative pool available")
  func statusReadsDoNotOccupyCooperativePool() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusPoolTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)

    let registryDirectory = root.appendingPathComponent("registry", isDirectory: true)
    let manager = try ProfileManager(
      registryURL: registryDirectory.appendingPathComponent("profiles.json"),
      applicationSupportDirectory: registryDirectory
    )
    var profiles: [Profile] = []
    for id in ["alpha", "beta"] {
      profiles.append(
        try manager.addProfile(
          id: id,
          displayName: id.capitalized,
          codexHome: root.appendingPathComponent("\(id)-home", isDirectory: true)
        ))
    }

    // Each read waits for a release file that only a separate Swift task creates.
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      barrier=$(/usr/bin/dirname "$CODEX_HOME")
      /usr/bin/touch "$barrier/ready-$(/usr/bin/basename "$CODEX_HOME")"
      attempts=0
      while [ ! -f "$barrier/release" ]; do
        attempts=$((attempts + 1))
        [ "$attempts" -lt 300 ] || exit 1
        /bin/sleep 0.01
      done
      IFS= read -r _
      printf '%s\\n' '{"id":1,"result":{}}'
      IFS= read -r _
      IFS= read -r _
      IFS= read -r _
      printf '%s\\n' '{"id":2,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}'
      printf '%s\\n' '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":1}}}}'
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)

    let releaser = Task {
      let ready = ["alpha-home", "beta-home"].map {
        root.appendingPathComponent("ready-\($0)").path
      }
      while !ready.allSatisfy(FileManager.default.fileExists(atPath:)) {
        try await Task.sleep(for: .milliseconds(10))
      }
      FileManager.default.createFile(
        atPath: root.appendingPathComponent("release").path, contents: nil)
    }
    defer { releaser.cancel() }

    let statuses = await manager.statuses(
      profiles: profiles,
      service: CodexStatusService(timeout: 5),
      codexExecutable: executable
    )
    #expect(statuses.map(\.profileID.rawValue) == ["alpha", "beta"])
    #expect(statuses.allSatisfy { $0.state == .available })
  }

  @Test("Cancelling a status batch stops running reads and starts no more")
  func cancellingStatusBatchStopsReads() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexStatusCancelTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)

    let registryDirectory = root.appendingPathComponent("registry", isDirectory: true)
    let manager = try ProfileManager(
      registryURL: registryDirectory.appendingPathComponent("profiles.json"),
      applicationSupportDirectory: registryDirectory
    )
    var profiles: [Profile] = []
    for id in ["p1", "p2", "p3", "p4", "p5"] {
      profiles.append(
        try manager.addProfile(
          id: id,
          displayName: id,
          codexHome: root.appendingPathComponent("\(id)-home", isDirectory: true)
        ))
    }

    // Each fake app-server announces itself, then hangs without answering.
    let executable = root.appendingPathComponent("fake-codex")
    let script = """
      #!/bin/sh
      /usr/bin/touch "$(/usr/bin/dirname "$CODEX_HOME")/ready-$(/usr/bin/basename "$CODEX_HOME")"
      exec /bin/sleep 30
      """
    try Data(script.utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)

    let readyCount = {
      (try? FileManager.default.contentsOfDirectory(atPath: root.path))?
        .filter { $0.hasPrefix("ready-") }.count ?? 0
    }
    let profileCount = profiles.count
    let batch = Task {
      await manager.statuses(
        profiles: profiles,
        service: CodexStatusService(timeout: 8),
        codexExecutable: executable
      )
    }
    let readyDeadline = ContinuousClock.now + .seconds(5)
    while readyCount() < 4, ContinuousClock.now < readyDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(readyCount() == 4)

    let cancelledAt = ContinuousClock.now
    batch.cancel()
    let statuses = await batch.value
    #expect(ContinuousClock.now - cancelledAt < .seconds(4))
    // The fifth read is still scheduled but stops before starting a process, so every profile
    // keeps one result.
    #expect(readyCount() == 4)
    #expect(statuses.count == profileCount)
    #expect(statuses.allSatisfy { $0.state == .unavailable })
  }

  private func testProfile() throws -> Profile {
    try Profile(
      id: ProfileID("status"),
      displayName: "Status",
      codexHome: URL(fileURLWithPath: "/tmp/opm-status")
    )
  }
}
