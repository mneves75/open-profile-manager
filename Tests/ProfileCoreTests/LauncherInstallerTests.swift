import CoreFoundation
import Darwin
import Foundation
import Testing

@testable import ProfileCore

@Suite("Finder launchers")
struct LauncherInstallerTests {
  @Test("Generated launchers contain only the executable path and validated profile ID")
  func launcherContainsNoAuthenticationData() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LauncherInstallerTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let profile = try Profile(
      id: ProfileID("safe-profile"),
      displayName: "Safe Profile",
      codexHome: root.appendingPathComponent("secret-auth-home")
    )
    let installer = LauncherInstaller(shouldSign: false)
    let launcher = try installer.install(
      profile: profile,
      opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
      destinationDirectory: root
    )

    let executable = launcher.appendingPathComponent("Contents/MacOS/launch")
    let executableData = try Data(contentsOf: executable)
    let sourceExecutableData = try Data(contentsOf: URL(fileURLWithPath: "/usr/bin/true"))
    #expect(executableData == sourceExecutableData)
    #expect(!executableData.starts(with: Data("#!".utf8)))

    let plistURL = launcher.appendingPathComponent("Contents/Info.plist")
    let plistData = try Data(contentsOf: plistURL)
    let plist = try #require(
      PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
    )
    #expect(plist["OPMManagedLauncher"] as? Bool == true)
    #expect(plist["OPMProfileID"] as? String == profile.id.rawValue)
    #expect(mode(at: launcher) == 0o700)
    #expect(mode(at: launcher.appendingPathComponent("Contents")) == 0o700)
    #expect(mode(at: launcher.appendingPathComponent("Contents/MacOS")) == 0o700)
    #expect(mode(at: executable) == 0o700)
    #expect(mode(at: plistURL) == 0o600)
    #expect(!plistData.contains(Data(profile.codexHome.path.utf8)))
    #expect(
      !FileManager.default.fileExists(
        atPath: launcher.appendingPathComponent("Contents/Resources/ChatGPT.app").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: launcher.appendingPathComponent("Contents/Resources/Codex.app").path
      ))
    let replaced = try installer.install(
      profile: profile,
      opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
      destinationDirectory: root
    )
    #expect(replaced == launcher)
    #expect(try installer.remove(profileID: profile.id, destinationDirectory: root))
    #expect(!FileManager.default.fileExists(atPath: launcher.path))
  }

  @Test("Launcher executables must be regular files")
  func rejectsExecutableSymlink() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LauncherInstallerTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let symlink = root.appendingPathComponent("opm-link")
    try FileManager.default.createSymbolicLink(
      at: symlink,
      withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
    )
    let profile = try Profile(
      id: ProfileID("symlink"),
      displayName: "Symlink",
      codexHome: root.appendingPathComponent("home")
    )

    #expect(throws: ProfileCoreError.self) {
      try LauncherInstaller(shouldSign: false).install(
        profile: profile,
        opmExecutable: symlink,
        destinationDirectory: root
      )
    }
  }

  @Test("Distinct profile IDs produce distinct launcher bundle identifiers")
  func bundleIdentifiersAreInjective() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LauncherIdentifierTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    #expect(chmod(root.path, 0o700) == 0)
    let installer = LauncherInstaller(shouldSign: false)
    var identifiers = Set<String>()

    for value in ["work-team", "work_team"] {
      let profile = try Profile(
        id: ProfileID(value),
        displayName: value,
        codexHome: root.appendingPathComponent("home-\(value)")
      )
      let launcher = try installer.install(
        profile: profile,
        opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
        destinationDirectory: root
      )
      let data = try Data(
        contentsOf: launcher.appendingPathComponent("Contents/Info.plist", isDirectory: false)
      )
      let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
      )
      identifiers.insert(try #require(plist["CFBundleIdentifier"] as? String))
    }

    #expect(identifiers.count == 2)
  }

  @Test("Launcher destinations must be private directories")
  func rejectsUnsafeDestinations() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let broad = root.appendingPathComponent("broad", isDirectory: true)
    try FileManager.default.createDirectory(at: broad, withIntermediateDirectories: false)
    #expect(chmod(broad.path, 0o777) == 0)
    let linked = root.appendingPathComponent("linked", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: broad)
    let profile = try Profile(
      id: ProfileID("unsafe-destination"),
      displayName: "Unsafe destination",
      codexHome: root.appendingPathComponent("home")
    )
    let installer = LauncherInstaller(shouldSign: false)

    for destination in [broad, linked] {
      #expect(throws: ProfileCoreError.self) {
        try installer.install(
          profile: profile,
          opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
          destinationDirectory: destination
        )
      }
    }
    #expect(mode(at: broad) == 0o777)
  }

  @Test("Dangling launcher symlinks are rejected as unmanaged entries")
  func rejectsDanglingLauncherSymlink() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let installer = LauncherInstaller(shouldSign: false)
    let profile = try Profile(
      id: ProfileID("dangling"),
      displayName: "Dangling",
      codexHome: root.appendingPathComponent("home")
    )
    let launcher = installer.launcherURL(for: profile.id, destinationDirectory: root)
    try FileManager.default.createSymbolicLink(
      at: launcher,
      withDestinationURL: root.appendingPathComponent("missing")
    )

    #expect(throws: ProfileCoreError.self) {
      try installer.remove(profileID: profile.id, destinationDirectory: root)
    }
    #expect(throws: ProfileCoreError.self) {
      try installer.install(
        profile: profile,
        opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
        destinationDirectory: root
      )
    }
    var information = stat()
    #expect(lstat(launcher.path, &information) == 0)
  }

  @Test("Managed launcher inspection rejects FIFOs and oversized property lists")
  func boundsManagedLauncherPlists() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let installer = LauncherInstaller(shouldSign: false)

    for (id, useFIFO) in [("fifo-plist", true), ("large-plist", false)] {
      let profile = try Profile(
        id: ProfileID(id),
        displayName: id,
        codexHome: root.appendingPathComponent("home-\(id)")
      )
      let launcher = installer.launcherURL(for: profile.id, destinationDirectory: root)
      let contents = launcher.appendingPathComponent("Contents", isDirectory: true)
      try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
      let plist = contents.appendingPathComponent("Info.plist")
      if useFIFO {
        #expect(mkfifo(plist.path, 0o600) == 0)
      } else {
        try Data(repeating: 0x20, count: 262_145).write(to: plist)
      }

      #expect(throws: ProfileCoreError.self) {
        try installer.install(
          profile: profile,
          opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
          destinationDirectory: root
        )
      }
    }
  }

  @Test("Numeric managed markers are rejected without replacing the launcher")
  func rejectsNumericManagedMarker() throws {
    let root = try privateTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let installer = LauncherInstaller(shouldSign: false)
    let profile = try Profile(
      id: ProfileID("numeric-marker"),
      displayName: "Numeric marker",
      codexHome: root.appendingPathComponent("home")
    )
    let launcher = try installer.install(
      profile: profile,
      opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
      destinationDirectory: root
    )
    let plistURL = launcher.appendingPathComponent("Contents/Info.plist")
    let data = try Data(contentsOf: plistURL)
    var plist = try #require(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )
    plist["OPMManagedLauncher"] = 1
    let numericMarkerData = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    try numericMarkerData.write(to: plistURL)
    #expect(chmod(plistURL.path, 0o600) == 0)

    #expect(throws: ProfileCoreError.self) {
      try installer.remove(profileID: profile.id, destinationDirectory: root)
    }
    #expect(throws: ProfileCoreError.self) {
      try installer.install(
        profile: profile,
        opmExecutable: URL(fileURLWithPath: "/usr/bin/true"),
        destinationDirectory: root
      )
    }

    let preservedData = try Data(contentsOf: plistURL)
    let preservedPlist = try #require(
      PropertyListSerialization.propertyList(from: preservedData, format: nil) as? [String: Any]
    )
    let marker = try #require(preservedPlist["OPMManagedLauncher"] as? NSNumber)
    #expect(CFGetTypeID(marker) != CFBooleanGetTypeID())
    #expect(marker.intValue == 1)
  }

  private func privateTemporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("LauncherInstallerTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    guard chmod(root.path, 0o700) == 0 else {
      throw ProfileCoreError.filesystem(operation: "secure the launcher test directory")
    }
    return root
  }

  private func mode(at url: URL) -> mode_t? {
    var information = stat()
    guard lstat(url.path, &information) == 0 else { return nil }
    return information.st_mode & 0o777
  }
}
