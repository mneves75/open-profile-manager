import Foundation
import Testing

@testable import ProfileCore

@Suite("Launch planning")
struct LaunchPlannerTests {
  @Test("Executable discovery merges Finder-safe fallback locations")
  func finderFallbackDiscovery() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExecutableLocatorTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let localBin = root.appendingPathComponent(".local/bin", isDirectory: true)
    try FileManager.default.createDirectory(at: localBin, withIntermediateDirectories: true)
    let executable = localBin.appendingPathComponent("profile-tool")
    try Data("fixture".utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let falseBin = root.appendingPathComponent("false-bin", isDirectory: true)
    let falseExecutable = falseBin.appendingPathComponent("profile-tool", isDirectory: true)
    try FileManager.default.createDirectory(at: falseExecutable, withIntermediateDirectories: true)
    #expect(chmod(falseExecutable.path, 0o700) == 0)

    let resolved = try ExecutableLocator.resolve(
      "profile-tool",
      environment: ["PATH": falseBin.path],
      homeDirectory: root
    )
    #expect(resolved == executable.standardizedFileURL)
    #expect(throws: ProfileCoreError.self) {
      try ExecutableLocator.resolve(falseExecutable.path, homeDirectory: root)
    }
    let symlink = root.appendingPathComponent("linked-tool", isDirectory: false)
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: executable)
    #expect(try ExecutableLocator.resolve(symlink.path, homeDirectory: root) == executable)
  }

  @Test("Codex arguments are preserved and never interpreted")
  func argumentPreservation() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let codexHome = root.appendingPathComponent("codex home; untouched", isDirectory: true)
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: false)
    #expect(chmod(codexHome.path, 0o700) == 0)
    let profile = try testProfile(codexHome: codexHome)
    let planner = try LaunchPlanner(
      applicationSupportDirectory: URL(fileURLWithPath: "/tmp/opm-support"))
    let arguments = [
      "exec",
      "$(touch /tmp/should-not-exist)",
      "; rm -rf /",
      "space preserved",
      "quote'\"value",
      "--",
      "-leading-option",
    ]
    let accessTokenKey = ["CODEX", "ACCESS", "TOKEN"].joined(separator: "_")
    let apiKey = ["CODEX", "API", "KEY"].joined(separator: "_")
    let openAIAPIKey = ["OPENAI", "API", "KEY"].joined(separator: "_")
    let sqliteHomeKey = ["CODEX", "SQLITE", "HOME"].joined(separator: "_")
    var environment = [
      "PATH": "/usr/bin",
      "KEEP": "yes",
      "CODEX_HOME": "/wrong",
      "PROVIDER_SETTING": "retained",
    ]
    environment[accessTokenKey] = "ignored"
    environment[apiKey] = "ignored"
    environment[openAIAPIKey] = "ignored"
    environment[sqliteHomeKey] = "/wrong-state"
    let plan = try planner.codexPlan(
      for: profile,
      arguments: arguments,
      codexExecutable: URL(fileURLWithPath: "/usr/bin/true"),
      environment: environment
    )

    #expect(plan.executableURL.path == "/usr/bin/true")
    #expect(plan.arguments == arguments)
    #expect(plan.environment["CODEX_HOME"] == profile.codexHome.path)
    #expect(plan.environment["KEEP"] == "yes")
    #expect(plan.environment[accessTokenKey] == nil)
    #expect(plan.environment[apiKey] == nil)
    #expect(plan.environment[openAIAPIKey] == nil)
    #expect(plan.environment[sqliteHomeKey] == nil)
    #expect(plan.environment["PROVIDER_SETTING"] == "retained")
  }

  @Test("App plans use open argument arrays and a per-profile directory")
  func applicationPlan() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LaunchPlannerTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let app = root.appendingPathComponent("ChatGPT.app", isDirectory: true)
    try createApplication(at: app)
    let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: false)
    #expect(chmod(codexHome.path, 0o700) == 0)
    let profile = try testProfile(codexHome: codexHome)
    let planner = try LaunchPlanner(
      applicationSupportDirectory: root.appendingPathComponent("support"))
    let plan = try planner.appPlan(for: profile, explicitAppURL: app)

    #expect(plan.executableURL.path == "/usr/bin/open")
    #expect(
      plan.arguments == [
        "-n",
        "--env",
        "CODEX_HOME=\(profile.codexHome.path)",
        "-a",
        app.path,
        "--args",
        "--user-data-dir=\(root.appendingPathComponent("support/gui/injection").path)",
      ])
    #expect(plan.environment["CODEX_HOME"] == profile.codexHome.path)
  }

  @Test("Application discovery skips malformed bundles")
  func skipsMalformedApplicationBundles() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let malformed = root.appendingPathComponent("ChatGPT.app", isDirectory: true)
    let valid = root.appendingPathComponent("Codex.app", isDirectory: true)
    try FileManager.default.createDirectory(at: malformed, withIntermediateDirectories: false)
    try createApplication(at: valid)
    let planner = try LaunchPlanner(applicationSupportDirectory: root)

    #expect(
      try planner.discoverApplication(
        explicitAppURL: nil,
        candidateURLs: [malformed, valid]
      ) == valid.standardizedFileURL
    )
    #expect(throws: ProfileCoreError.applicationNotFound) {
      try planner.discoverApplication(explicitAppURL: malformed)
    }
  }

  @Test("Application discovery bounds property-list reads")
  func boundsApplicationPropertyLists() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fifo = root.appendingPathComponent("FIFO.app", isDirectory: true)
    let oversized = root.appendingPathComponent("Oversized.app", isDirectory: true)
    let valid = root.appendingPathComponent("Valid.app", isDirectory: true)
    for app in [fifo, oversized, valid] {
      try createApplication(at: app)
    }
    let fifoPlist = fifo.appendingPathComponent("Contents/Info.plist")
    try FileManager.default.removeItem(at: fifoPlist)
    #expect(mkfifo(fifoPlist.path, 0o600) == 0)
    try Data(repeating: 0x20, count: 262_145).write(
      to: oversized.appendingPathComponent("Contents/Info.plist")
    )
    let planner = try LaunchPlanner(applicationSupportDirectory: root)

    #expect(
      try planner.discoverApplication(
        explicitAppURL: nil,
        candidateURLs: [fifo, oversized, valid]
      ) == valid.standardizedFileURL
    )
  }

  @Test("Application discovery includes the per-user Applications directory")
  func discoversApplicationInUserDirectory() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let app = root.appendingPathComponent("Applications/ChatGPT.app", isDirectory: true)
    try createApplication(at: app)
    let planner = try LaunchPlanner(applicationSupportDirectory: root)

    #expect(
      try planner.discoverApplication(explicitAppURL: nil, homeDirectory: root)
        == app.standardizedFileURL
    )
  }

  @Test("Launch plans revalidate a persisted CODEX_HOME")
  func rejectsUnsafePersistedHome() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let codexHome = root.appendingPathComponent("unsafe-home", isDirectory: true)
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: false)
    #expect(chmod(codexHome.path, 0o500) == 0)
    let profile = try testProfile(codexHome: codexHome)
    let planner = try LaunchPlanner(applicationSupportDirectory: root)

    #expect(throws: ProfileCoreError.self) {
      try planner.codexPlan(
        for: profile,
        arguments: [],
        codexExecutable: URL(fileURLWithPath: "/usr/bin/true")
      )
    }
  }

  @Test("GUI directory creation rejects symlinked ancestors without mutation")
  func rejectsSymlinkedGUIAncestor() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("target", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    #expect(chmod(target.path, 0o700) == 0)
    let support = root.appendingPathComponent("support", isDirectory: true)
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: false)
    #expect(chmod(support.path, 0o700) == 0)
    try FileManager.default.createSymbolicLink(
      at: support.appendingPathComponent("gui", isDirectory: true),
      withDestinationURL: target
    )
    let codexHome = root.appendingPathComponent("codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: false)
    #expect(chmod(codexHome.path, 0o700) == 0)
    let profile = try testProfile(codexHome: codexHome)
    let planner = try LaunchPlanner(applicationSupportDirectory: support)

    #expect(throws: ProfileCoreError.self) {
      try planner.prepareAppDataDirectory(for: profile)
    }
    #expect(
      !FileManager.default.fileExists(atPath: target.appendingPathComponent("injection").path))
  }

  private func testProfile(codexHome: URL) throws -> Profile {
    try Profile(
      id: ProfileID("injection"),
      displayName: "Injection Test",
      codexHome: codexHome
    )
  }

  private func privateTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LaunchPlannerTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    guard chmod(url.path, 0o700) == 0 else {
      throw ProfileCoreError.filesystem(operation: "secure the test directory")
    }
    return url
  }

  private func createApplication(at url: URL) throws {
    let macOS = url.appendingPathComponent("Contents/MacOS", isDirectory: true)
    try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
    let executable = macOS.appendingPathComponent("TestApplication", isDirectory: false)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    #expect(chmod(executable.path, 0o700) == 0)
    let plist: [String: Any] = [
      "CFBundleExecutable": "TestApplication",
      "CFBundleIdentifier": "dev.openprofilemanager.test",
      "CFBundlePackageType": "APPL",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    try data.write(
      to: url.appendingPathComponent("Contents/Info.plist", isDirectory: false)
    )
  }
}
