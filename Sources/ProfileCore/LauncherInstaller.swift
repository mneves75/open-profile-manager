import Darwin
import Foundation

public struct LauncherInstaller: Sendable {
  private static let maximumLauncherPlistBytes = 262_144

  public let shouldSign: Bool

  public init(shouldSign: Bool = true) {
    self.shouldSign = shouldSign
  }

  public static func defaultDestination(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL {
    homeDirectory.appendingPathComponent("Applications", isDirectory: true)
  }

  @discardableResult
  public func install(
    profile: Profile,
    opmExecutable: URL,
    destinationDirectory: URL = Self.defaultDestination()
  ) throws -> URL {
    let destination = try validatedDestination(destinationDirectory)
    let executable = try Profile.normalizedAbsoluteURL(opmExecutable, field: "opm executable")
    var executableInformation = stat()
    guard lstat(executable.path, &executableInformation) == 0,
      executableInformation.st_mode & S_IFMT == S_IFREG,
      FileManager.default.isExecutableFile(atPath: executable.path)
    else {
      throw ProfileCoreError.executableNotFound(executable.path)
    }
    let finalURL = launcherURL(for: profile.id, destinationDirectory: destination)
    let temporaryURL = destination.appendingPathComponent(
      ".opm-launcher-\(UUID().uuidString).app",
      isDirectory: true
    )
    let contents = temporaryURL.appendingPathComponent("Contents", isDirectory: true)
    let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
    let launcherExecutable = macOS.appendingPathComponent("launch", isDirectory: false)
    let plistURL = contents.appendingPathComponent("Info.plist", isDirectory: false)

    do {
      try FileManager.default.createDirectory(
        at: macOS,
        withIntermediateDirectories: true
      )
      for directory in [temporaryURL, contents, macOS] {
        guard chmod(directory.path, S_IRWXU) == 0 else {
          throw ProfileCoreError.filesystem(operation: "secure the launcher bundle")
        }
      }
      try FileManager.default.copyItem(at: executable, to: launcherExecutable)
      guard chmod(launcherExecutable.path, S_IRWXU) == 0 else {
        throw ProfileCoreError.filesystem(operation: "make the launcher executable")
      }
      let plist: [String: Any] = [
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "Open Profile Manager - \(profile.displayName)",
        "CFBundleExecutable": "launch",
        "CFBundleIdentifier": "dev.openprofilemanager.launcher.\(bundleIdentifierPart(profile.id))",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "Open Profile Manager - \(profile.id.rawValue)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": OPMVersion.current,
        "LSMinimumSystemVersion": "15.0",
        "OPMManagedLauncher": true,
        "OPMProfileID": profile.id.rawValue,
      ]
      let plistData = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
      )
      try plistData.write(to: plistURL, options: .withoutOverwriting)
      guard chmod(plistURL.path, S_IRUSR | S_IWUSR) == 0 else {
        throw ProfileCoreError.filesystem(operation: "secure the launcher property list")
      }

      if shouldSign {
        try sign(temporaryURL)
      }

      if pathEntryExists(finalURL) {
        guard isManagedLauncher(finalURL, profileID: profile.id) else {
          throw ProfileCoreError.launcherNotManaged(finalURL.path)
        }
        _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: temporaryURL)
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
      }
      return finalURL
    } catch let error as ProfileCoreError {
      try? FileManager.default.removeItem(at: temporaryURL)
      throw error
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      throw ProfileCoreError.filesystem(operation: "install the Finder launcher")
    }
  }

  @discardableResult
  public func remove(
    profileID: ProfileID,
    destinationDirectory: URL = Self.defaultDestination()
  ) throws -> Bool {
    let destination = try validatedDestination(destinationDirectory)
    let url = launcherURL(for: profileID, destinationDirectory: destination)
    guard pathEntryExists(url) else { return false }
    guard isManagedLauncher(url, profileID: profileID) else {
      throw ProfileCoreError.launcherNotManaged(url.path)
    }
    do {
      try FileManager.default.removeItem(at: url)
      return true
    } catch {
      throw ProfileCoreError.filesystem(operation: "remove the Finder launcher")
    }
  }

  public func launcherURL(for id: ProfileID, destinationDirectory: URL) -> URL {
    destinationDirectory.appendingPathComponent(
      "Open Profile Manager - \(id.rawValue).app",
      isDirectory: true
    )
  }

  private func validatedDestination(_ url: URL) throws -> URL {
    let normalized: URL
    do {
      normalized = try Profile.normalizedAbsoluteURL(url, field: "Launcher destination")
      try PrivateDirectory.ensure(
        normalized,
        operation: "create a private launcher destination"
      )
    } catch {
      throw ProfileCoreError.invalidLauncherDestination(url.path)
    }
    return normalized
  }

  private func bundleIdentifierPart(_ id: ProfileID) -> String {
    "p" + id.rawValue.utf8.map { String(format: "%02x", $0) }.joined()
  }

  private func isManagedLauncher(_ url: URL, profileID: ProfileID) -> Bool {
    var bundleInformation = stat()
    guard lstat(url.path, &bundleInformation) == 0,
      bundleInformation.st_mode & S_IFMT == S_IFDIR
    else { return false }
    let plistURL = url.appendingPathComponent("Contents/Info.plist", isDirectory: false)
    guard
      let data = try? BoundedFile.readRegularFile(
        at: plistURL,
        maximumBytes: Self.maximumLauncherPlistBytes,
        operation: "read a managed launcher property list"
      ),
      let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any],
      let identifier = plist["CFBundleIdentifier"] as? String,
      let marker = plist["OPMManagedLauncher"] as? Bool,
      let storedProfileID = plist["OPMProfileID"] as? String
    else {
      return false
    }
    let currentIdentifier = "dev.openprofilemanager.launcher.\(bundleIdentifierPart(profileID))"
    return marker && storedProfileID == profileID.rawValue
      && identifier == currentIdentifier
  }

  private func pathEntryExists(_ url: URL) -> Bool {
    var information = stat()
    return lstat(url.path, &information) == 0 || errno != ENOENT
  }

  private func sign(_ bundleURL: URL) throws {
    let codesign = URL(fileURLWithPath: "/usr/bin/codesign")
    guard FileManager.default.isExecutableFile(atPath: codesign.path) else {
      throw ProfileCoreError.executableNotFound(codesign.path)
    }
    let process = Process()
    process.executableURL = codesign
    process.arguments = ["--force", "--sign", "-", bundleURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      throw ProfileCoreError.processLaunchFailed("codesign")
    }
    guard process.terminationStatus == 0 else {
      throw ProfileCoreError.processLaunchFailed("codesign")
    }
  }
}
