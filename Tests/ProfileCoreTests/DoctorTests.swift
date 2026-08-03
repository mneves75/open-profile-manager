import Darwin
import Foundation
import Testing

@testable import ProfileCore

@Suite("Doctor diagnostics")
struct DoctorTests {
  @Test("Doctor validates the effective automatic GUI directory")
  func automaticGUIDataDirectory() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("registry/profiles.json")
    let supportDirectory = root.appendingPathComponent("support", isDirectory: true)
    let registry = try ProfileRegistry(
      registryURL: registryURL,
      applicationSupportDirectory: supportDirectory
    )
    let profile = try Profile(
      id: ProfileID("automatic"),
      displayName: "Automatic",
      codexHome: root.appendingPathComponent("codex", isDirectory: true)
    )
    try registry.add(profile)

    let missingReport = DoctorService().run(
      registry: registry,
      profile: profile,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(guiCheck(in: missingReport)?.state == .pass)

    let automaticDirectory = supportDirectory.appendingPathComponent(
      "gui/automatic",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: automaticDirectory,
      withIntermediateDirectories: true
    )
    #expect(chmod(automaticDirectory.path, 0o755) == 0)
    let unsafeReport = DoctorService().run(
      registry: registry,
      profile: profile,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(guiCheck(in: unsafeReport)?.state == .failure)
  }

  @Test("Doctor rejects missing registry and GUI paths beneath symlinks")
  func missingPathsBeneathSymlinks() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("target", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    #expect(chmod(target.path, 0o700) == 0)

    let registryLink = root.appendingPathComponent("registry-link", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: registryLink, withDestinationURL: target)
    let unsafeRegistry = try ProfileRegistry(
      registryURL: registryLink.appendingPathComponent("profiles.json")
    )
    let registryReport = DoctorService().run(
      registry: unsafeRegistry,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(registryReport.checks.first { $0.name == "Profile registry" }?.state == .failure)

    let safeRegistryURL = root.appendingPathComponent("safe/profiles.json")
    let support = root.appendingPathComponent("support", isDirectory: true)
    let safeRegistry = try ProfileRegistry(
      registryURL: safeRegistryURL,
      applicationSupportDirectory: support
    )
    let profile = try Profile(
      id: ProfileID("automatic"),
      displayName: "Automatic",
      codexHome: root.appendingPathComponent("codex", isDirectory: true)
    )
    try safeRegistry.add(profile)
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: false)
    #expect(chmod(support.path, 0o700) == 0)
    try FileManager.default.createSymbolicLink(
      at: support.appendingPathComponent("gui", isDirectory: true),
      withDestinationURL: target
    )
    let guiReport = DoctorService().run(
      registry: safeRegistry,
      profile: profile,
      environment: ["PATH": "/usr/bin:/bin"]
    )
    #expect(guiCheck(in: guiReport)?.state == .failure)
  }

  private func guiCheck(in report: DoctorReport) -> DoctorCheck? {
    report.checks.first { $0.name == "GUI data directory (automatic)" }
  }

  private func privateTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("DoctorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    guard chmod(url.path, 0o700) == 0 else {
      throw ProfileCoreError.filesystem(operation: "secure the test directory")
    }
    return url
  }
}
