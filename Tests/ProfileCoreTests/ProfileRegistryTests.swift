import Darwin
import Foundation
import Testing

@testable import ProfileCore

@Suite("Profile registry")
struct ProfileRegistryTests {
  @Test("CRUD persists atomically with private modes")
  func persistenceAndModes() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("private/profiles.json")
    let codexHome = root.appendingPathComponent("homes/work", isDirectory: true)
    let registry = try ProfileRegistry(registryURL: registryURL)
    let profile = try Profile(
      id: ProfileID("work"),
      displayName: "Work",
      codexHome: codexHome
    )

    try registry.add(profile)
    #expect(try registry.list() == [profile])
    #expect(mode(at: registryURL) == 0o600)
    #expect(mode(at: registryURL.deletingLastPathComponent()) == 0o700)
    #expect(mode(at: codexHome) == 0o700)
    #expect(try siblingTemporaryFiles(of: registryURL).isEmpty)

    let updated = try registry.update(
      profile.id,
      with: ProfileUpdate(displayName: "Updated")
    )
    #expect(updated.displayName == "Updated")
    #expect(try registry.get(profile.id).displayName == "Updated")
    #expect(try registry.remove(profile.id).id == profile.id)
    #expect(try registry.list().isEmpty)
  }

  @Test("Duplicate IDs are rejected without changing the registry")
  func duplicateID() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ProfileRegistry(registryURL: root.appendingPathComponent("profiles.json"))
    let first = try Profile(
      id: ProfileID("same"),
      displayName: "First",
      codexHome: root.appendingPathComponent("first")
    )
    let duplicate = try Profile(
      id: ProfileID("same"),
      displayName: "Second",
      codexHome: root.appendingPathComponent("second")
    )
    try registry.add(first)
    #expect(throws: ProfileCoreError.self) {
      try registry.add(duplicate)
    }
    let persisted = try registry.list()
    #expect(persisted.map(\.id) == [first.id])
    #expect(persisted.map(\.displayName) == [first.displayName])
  }

  @Test("Profiles cannot share or nest their storage directories")
  func directoryIsolation() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ProfileRegistry(registryURL: root.appendingPathComponent("profiles.json"))
    let firstHome = root.appendingPathComponent("first-home", isDirectory: true)
    let first = try Profile(
      id: ProfileID("first"),
      displayName: "First",
      codexHome: firstHome
    )
    try registry.add(first)

    let shared = try Profile(
      id: ProfileID("shared"),
      displayName: "Shared",
      codexHome: firstHome
    )
    #expect(throws: ProfileCoreError.self) {
      try registry.add(shared)
    }

    let nested = try Profile(
      id: ProfileID("nested"),
      displayName: "Nested",
      codexHome: firstHome.appendingPathComponent("nested", isDirectory: true)
    )
    #expect(throws: ProfileCoreError.self) {
      try registry.add(nested)
    }

    if firstHome.path.hasPrefix("/var/") {
      let physicalAlias = try Profile(
        id: ProfileID("physical-alias"),
        displayName: "Physical alias",
        codexHome: URL(fileURLWithPath: "/private\(firstHome.path)", isDirectory: true)
      )
      #expect(throws: ProfileCoreError.self) {
        try registry.add(physicalAlias)
      }
    }

    let derivedGUICollision = try Profile(
      id: ProfileID("derived-collision"),
      displayName: "Derived collision",
      codexHome: root.appendingPathComponent("gui/first", isDirectory: true)
    )
    #expect(throws: ProfileCoreError.self) {
      try registry.add(derivedGUICollision)
    }

    let second = try Profile(
      id: ProfileID("second"),
      displayName: "Second",
      codexHome: root.appendingPathComponent("second-home", isDirectory: true)
    )
    try registry.add(second)
    #expect(throws: ProfileCoreError.self) {
      try registry.update(second.id, with: ProfileUpdate(codexHome: firstHome))
    }
  }

  @Test("Directory isolation recognizes macOS firmlink aliases")
  func firmlinkDirectoryIsolation() throws {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let physicalHome = URL(
      fileURLWithPath: "/System/Volumes/Data\(home.path)",
      isDirectory: true
    )
    let suffix = "opm-firmlink-test-\(UUID().uuidString)"

    #expect(
      try ProfileRegistry.directoriesOverlap(
        home.appendingPathComponent(suffix, isDirectory: true),
        physicalHome.appendingPathComponent(suffix, isDirectory: true)
      )
    )
  }

  @Test("Persisted profiles must satisfy directory isolation")
  func persistedDirectoryIsolation() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    let sharedHome = root.appendingPathComponent("shared-home", isDirectory: true).path
    let fixture = """
      {"schemaVersion":1,"profiles":[
        {"id":"first","displayName":"First","codexHome":"\(sharedHome)"},
        {"id":"second","displayName":"Second","codexHome":"\(sharedHome)"}
      ]}
      """
    try writeRegistryFixture(Data(fixture.utf8), to: registryURL)

    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.self) {
      try registry.list()
    }
  }

  @Test("Custom registry names cannot collide with their derived lock files")
  func customRegistryLockName() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent(".profiles.lock")
    let registry = try ProfileRegistry(registryURL: registryURL)
    let profile = try Profile(
      id: ProfileID("custom-name"),
      displayName: "Custom name",
      codexHome: root.appendingPathComponent("custom-home")
    )

    try registry.add(profile)
    #expect(try registry.list().map(\.id) == [profile.id])
    #expect(FileManager.default.fileExists(atPath: registryURL.path))
    let lockURL = root.appendingPathComponent(".opm-lock-.profiles.lock")
    #expect(FileManager.default.fileExists(atPath: lockURL.path))
  }

  @Test("Registry filenames cannot enter the reserved lock namespace")
  func reservedRegistryLockName() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    for fileName in [".opm-lock-profiles.json", ".OPM-LOCK-profiles.json"] {
      let registryURL = root.appendingPathComponent(fileName)
      #expect(throws: ProfileCoreError.self) {
        try ProfileRegistry(registryURL: registryURL)
      }
    }
  }

  @Test("Concurrent writers do not lose profile updates")
  func concurrentWriters() async throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")

    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<20 {
        group.addTask {
          let registry = try ProfileRegistry(registryURL: registryURL)
          let profile = try Profile(
            id: ProfileID("profile-\(index)"),
            displayName: "Profile \(index)",
            codexHome: root.appendingPathComponent("home-\(index)")
          )
          try registry.add(profile)
        }
      }
      try await group.waitForAll()
    }

    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(try registry.list().count == 20)
  }

  @Test("Malformed registries fail closed")
  func malformedRegistry() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    try writeRegistryFixture(Data("{not-json".utf8), to: registryURL)
    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.malformedRegistry) {
      try registry.list()
    }
  }

  @Test("Relative paths in registry data fail closed")
  func relativeRegistryPath() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    let fixture =
      "{\"schemaVersion\":1,\"profiles\":[{\"id\":\"bad\",\"displayName\":\"Bad\",\"codexHome\":\"relative/path\"}]}"
    try writeRegistryFixture(Data(fixture.utf8), to: registryURL)
    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.malformedRegistry) {
      try registry.list()
    }
  }

  @Test("Unknown schema versions are rejected")
  func unsupportedSchema() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    try writeRegistryFixture(
      Data("{\"schemaVersion\":99,\"profiles\":[]}".utf8),
      to: registryURL
    )
    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.unsupportedRegistryVersion(99)) {
      try registry.list()
    }
  }

  @Test("A registry symlink is rejected instead of followed")
  func registrySymlink() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("target.json")
    let registryURL = root.appendingPathComponent("profiles.json")
    try Data("{\"schemaVersion\":1,\"profiles\":[]}".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(at: registryURL, withDestinationURL: target)
    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.self) {
      try registry.list()
    }
  }

  @Test("A dangling registry symlink is rejected instead of treated as missing")
  func danglingRegistrySymlink() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    let missingTarget = root.appendingPathComponent("missing.json")
    try FileManager.default.createSymbolicLink(
      at: registryURL,
      withDestinationURL: missingTarget
    )

    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.self) {
      try registry.list()
    }
    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: registryURL.path)
        == missingTarget.path
    )
  }

  @Test("A registry FIFO is rejected without waiting for a writer")
  func registryFIFO() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    #expect(mkfifo(registryURL.path, 0o600) == 0)

    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.self) {
      try registry.list()
    }
  }

  @Test("Oversized registries fail before decoding")
  func oversizedRegistry() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    try writeRegistryFixture(Data(repeating: 0x20, count: 1_048_577), to: registryURL)
    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.registryTooLarge) {
      try registry.list()
    }
  }

  @Test("Oversized registry encodings are rejected before writing")
  func rejectsOversizedSaveData() {
    #expect(throws: ProfileCoreError.registryTooLarge) {
      try ProfileRegistry.validateRegistrySize(1_048_577)
    }
    #expect(throws: Never.self) {
      try ProfileRegistry.validateRegistrySize(1_048_576)
    }
  }

  @Test("Existing profile directories must already be private")
  func rejectsBroadDirectoryPermissions() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ProfileRegistry(registryURL: root.appendingPathComponent("profiles.json"))
    for (index, unsafeMode) in [0o000, 0o500, 0o600, 0o755].enumerated() {
      let codexHome = root.appendingPathComponent("unsafe-home-\(index)", isDirectory: true)
      try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: false)
      #expect(chmod(codexHome.path, mode_t(unsafeMode)) == 0)
      let profile = try Profile(
        id: ProfileID("unsafe-mode-\(index)"),
        displayName: "Unsafe mode \(index)",
        codexHome: codexHome
      )

      #expect(throws: ProfileCoreError.self) {
        try registry.add(profile)
      }
      #expect(mode(at: codexHome) == mode_t(unsafeMode))
    }
  }

  @Test("Registry reads require current-user ownership and mode 0600")
  func rejectsBroadRegistryPermissions() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registryURL = root.appendingPathComponent("profiles.json")
    try writeRegistryFixture(
      Data("{\"schemaVersion\":1,\"profiles\":[]}".utf8),
      to: registryURL
    )
    #expect(chmod(registryURL.path, 0o644) == 0)

    let registry = try ProfileRegistry(registryURL: registryURL)
    #expect(throws: ProfileCoreError.self) {
      try registry.list()
    }
  }

  @Test("Private paths reject unsafe leaf, ancestor, and registry ACLs")
  func accessControlLists() throws {
    let directRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directRoot) }
    let unsafeHome = directRoot.appendingPathComponent("acl-home", isDirectory: true)
    try FileManager.default.createDirectory(at: unsafeHome, withIntermediateDirectories: false)
    #expect(chmod(unsafeHome.path, 0o700) == 0)
    try addACL("everyone allow read,readattr,readextattr,readsecurity", to: unsafeHome)
    let directRegistry = try ProfileRegistry(
      registryURL: directRoot.appendingPathComponent("direct/profiles.json")
    )
    let unsafeProfile = try Profile(
      id: ProfileID("acl-unsafe"),
      displayName: "ACL unsafe",
      codexHome: unsafeHome
    )
    #expect(throws: ProfileCoreError.self) {
      try directRegistry.add(unsafeProfile)
    }

    let inheritedRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: inheritedRoot) }
    try addACL(
      "everyone allow list,search,file_inherit,directory_inherit",
      to: inheritedRoot
    )
    let registryURL = inheritedRoot.appendingPathComponent("registry/profiles.json")
    let inheritedRegistry = try ProfileRegistry(registryURL: registryURL)
    let inheritedHome = inheritedRoot.appendingPathComponent("home", isDirectory: true)
    let inheritedProfile = try Profile(
      id: ProfileID("acl-clean"),
      displayName: "ACL clean",
      codexHome: inheritedHome
    )
    #expect(throws: ProfileCoreError.self) {
      try inheritedRegistry.add(inheritedProfile)
    }

    let fileRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: fileRoot) }
    let fileRegistryURL = fileRoot.appendingPathComponent("profiles.json")
    let fileRegistry = try ProfileRegistry(registryURL: fileRegistryURL)
    let fileProfile = try Profile(
      id: ProfileID("acl-file"),
      displayName: "ACL file",
      codexHome: fileRoot.appendingPathComponent("home", isDirectory: true)
    )
    try fileRegistry.add(fileProfile)
    try addACL("everyone allow read", to: fileRegistryURL)
    #expect(throws: ProfileCoreError.self) {
      try fileRegistry.list()
    }
  }

  @Test("Every newly created private path component is hardened")
  func createdDirectoryHardening() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let parent = root.appendingPathComponent("new-parent", isDirectory: true)
    let child = parent.appendingPathComponent("new-child", isDirectory: true)

    try PrivateDirectory.ensure(child, operation: "create test directory")
    #expect(mode(at: parent) == 0o700)
    #expect(mode(at: child) == 0o700)
  }

  @Test("Private directories beneath untrusted writable ancestors are rejected")
  func writableAncestorRejection() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let writableParent = root.appendingPathComponent("shared", isDirectory: true)
    let privateChild = writableParent.appendingPathComponent("private", isDirectory: true)
    try FileManager.default.createDirectory(at: privateChild, withIntermediateDirectories: true)
    #expect(chmod(writableParent.path, 0o777) == 0)
    #expect(chmod(privateChild.path, 0o700) == 0)

    #expect(throws: ProfileCoreError.self) {
      try PrivateDirectory.ensure(privateChild, operation: "validate test directory")
    }
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProfileRegistryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    guard chmod(url.path, 0o700) == 0 else {
      throw ProfileCoreError.filesystem(operation: "secure the test directory")
    }
    return url
  }

  private func mode(at url: URL) -> mode_t? {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return nil }
    return information.st_mode & 0o777
  }

  private func siblingTemporaryFiles(of registryURL: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(
      atPath: registryURL.deletingLastPathComponent().path
    ).filter { $0.hasPrefix(".profiles.") && $0.hasSuffix(".tmp") }
  }

  private func writeRegistryFixture(_ data: Data, to url: URL) throws {
    try data.write(to: url)
    guard chmod(url.path, 0o600) == 0 else {
      throw ProfileCoreError.filesystem(operation: "secure the registry fixture")
    }
  }

  private func addACL(_ entry: String, to url: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/chmod")
    process.arguments = ["+a", entry, url.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ProfileCoreError.filesystem(operation: "add the test ACL")
    }
  }
}
