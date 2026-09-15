import Darwin
import Foundation

public struct ProfileRegistry: Sendable {
  private static let maximumRegistryBytes: off_t = 1_048_576
  private static let maximumProfileCount = 128
  private static let lockFilePrefix = ".opm-lock-"

  public let registryURL: URL
  public let applicationSupportDirectory: URL

  private var registryFileName: String { registryURL.lastPathComponent }
  private var lockFileName: String { "\(Self.lockFilePrefix)\(registryFileName)" }

  public init(
    registryURL: URL = ProfileRegistry.defaultRegistryURL(),
    applicationSupportDirectory: URL? = nil
  ) throws {
    let normalizedURL = try Profile.normalizedAbsoluteURL(registryURL, field: .registryPath)
    let fileName = normalizedURL.lastPathComponent
    let normalizedFileName = fileName.precomposedStringWithCanonicalMapping.lowercased()
    guard !normalizedFileName.hasPrefix(Self.lockFilePrefix),
      !fileName.isEmpty,
      fileName.utf8.count <= 100
    else {
      throw ProfileCoreError.invalidAbsolutePath(field: .registryPath, path: normalizedURL.path)
    }
    self.registryURL = normalizedURL
    self.applicationSupportDirectory = try Profile.normalizedAbsoluteURL(
      applicationSupportDirectory ?? normalizedURL.deletingLastPathComponent(),
      field: .applicationSupportDirectory
    )
  }

  public static func defaultRegistryURL(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL {
    homeDirectory
      .appendingPathComponent("Library/Application Support/OpenProfileManager", isDirectory: true)
      .appendingPathComponent("profiles.json", isDirectory: false)
  }

  public func list() throws -> [Profile] {
    try load().profiles.sorted { $0.id < $1.id }
  }

  public func get(_ id: ProfileID) throws -> Profile {
    guard let profile = try load().profiles.first(where: { $0.id == id }) else {
      throw ProfileCoreError.profileNotFound(id.rawValue)
    }
    return profile
  }

  @discardableResult
  public func add(_ profile: Profile) throws -> Profile {
    try withExclusiveLock { directoryDescriptor in
      var registry = try load(directoryDescriptor: directoryDescriptor)
      guard !registry.profiles.contains(where: { $0.id == profile.id }) else {
        throw ProfileCoreError.profileAlreadyExists(profile.id.rawValue)
      }
      guard registry.profiles.count < Self.maximumProfileCount else {
        throw ProfileCoreError.tooManyProfiles
      }
      try validateDirectoryIsolation(profile, against: registry.profiles)
      try PrivateDirectory.ensure(profile.codexHome, operation: .createCodexHome)
      if let guiDataDirectory = profile.guiDataDirectory {
        try PrivateDirectory.ensure(guiDataDirectory, operation: .createGUIDataDirectory)
      }
      registry.profiles.append(profile)
      registry.profiles.sort { $0.id < $1.id }
      try save(registry, directoryDescriptor: directoryDescriptor)
      return profile
    }
  }

  @discardableResult
  public func update(_ id: ProfileID, with update: ProfileUpdate) throws -> Profile {
    try withExclusiveLock { directoryDescriptor in
      var registry = try load(directoryDescriptor: directoryDescriptor)
      guard let index = registry.profiles.firstIndex(where: { $0.id == id }) else {
        throw ProfileCoreError.profileNotFound(id.rawValue)
      }
      let current = registry.profiles[index]
      let updated = try Profile(
        id: current.id,
        displayName: update.displayName ?? current.displayName,
        codexHome: update.codexHome ?? current.codexHome,
        guiDataDirectory: update.clearGUIDataDirectory
          ? nil
          : (update.guiDataDirectory ?? current.guiDataDirectory)
      )
      try validateDirectoryIsolation(
        updated,
        against: registry.profiles.filter { $0.id != id }
      )
      try PrivateDirectory.ensure(updated.codexHome, operation: .createCodexHome)
      if let guiDataDirectory = updated.guiDataDirectory {
        try PrivateDirectory.ensure(guiDataDirectory, operation: .createGUIDataDirectory)
      }
      registry.profiles[index] = updated
      try save(registry, directoryDescriptor: directoryDescriptor)
      return updated
    }
  }

  @discardableResult
  public func remove(_ id: ProfileID) throws -> Profile {
    try withExclusiveLock { directoryDescriptor in
      var registry = try load(directoryDescriptor: directoryDescriptor)
      guard let index = registry.profiles.firstIndex(where: { $0.id == id }) else {
        throw ProfileCoreError.profileNotFound(id.rawValue)
      }
      let removed = registry.profiles.remove(at: index)
      try save(registry, directoryDescriptor: directoryDescriptor)
      return removed
    }
  }

  private func load() throws -> RegistryFile {
    let directory = registryURL.deletingLastPathComponent()
    var directoryInformation = stat()
    if lstat(directory.path, &directoryInformation) != 0 {
      guard errno == ENOENT else {
        throw ProfileCoreError.filesystem(operation: .inspectRegistryDirectory)
      }
      try PrivateDirectory.validateCreationPath(
        directory,
        operation: .validateRegistryDirectoryPath
      )
      return RegistryFile(schemaVersion: 1, profiles: [])
    }
    let directoryDescriptor = try PrivateDirectory.openValidatedDirectory(
      directory,
      operation: .readRegistryDirectory
    )
    defer { _ = close(directoryDescriptor) }
    return try load(directoryDescriptor: directoryDescriptor)
  }

  private func load(directoryDescriptor: Int32) throws -> RegistryFile {
    let descriptor = openat(
      directoryDescriptor,
      registryFileName,
      O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
    )
    if descriptor < 0 {
      guard errno == ENOENT else {
        throw ProfileCoreError.filesystem(operation: .openRegistry)
      }
      return RegistryFile(schemaVersion: 1, profiles: [])
    }
    defer { _ = close(descriptor) }

    var information = stat()
    guard fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      information.st_uid == geteuid(),
      (information.st_mode & 0o777) == (S_IRUSR | S_IWUSR),
      information.st_size >= 0
    else {
      throw ProfileCoreError.filesystem(operation: .readRegularRegistryFile)
    }
    try PrivateDirectory.validateNoExtendedACL(
      descriptor: descriptor,
      operation: .readPrivateRegistryFile
    )
    try Self.validateRegistrySize(Int(information.st_size))

    let data = try BoundedFile.read(
      descriptor: descriptor,
      maximumBytes: Int(Self.maximumRegistryBytes),
      readError: .filesystem(operation: .readRegistry),
      limitError: .registryTooLarge
    )

    let registry: RegistryFile
    do {
      registry = try JSONDecoder().decode(RegistryFile.self, from: data)
    } catch {
      throw ProfileCoreError.malformedRegistry
    }
    guard registry.schemaVersion == 1 else {
      throw ProfileCoreError.unsupportedRegistryVersion(registry.schemaVersion)
    }
    guard Set(registry.profiles.map(\.id)).count == registry.profiles.count else {
      throw ProfileCoreError.malformedRegistry
    }
    guard registry.profiles.count <= Self.maximumProfileCount else {
      throw ProfileCoreError.tooManyProfiles
    }
    try validateDirectoryIsolation(registry.profiles)
    return registry
  }

  private func save(_ registry: RegistryFile, directoryDescriptor: Int32) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data: Data
    var descriptorIsOpen = true
    do {
      data = try encoder.encode(registry)
    } catch {
      throw ProfileCoreError.filesystem(operation: .encodeRegistry)
    }
    try Self.validateRegistrySize(data.count)

    let temporaryName = ".\(registryFileName).\(UUID().uuidString).tmp"
    let descriptor = openat(
      directoryDescriptor,
      temporaryName,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
      S_IRUSR | S_IWUSR
    )
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(operation: .createPrivateRegistryUpdate)
    }

    do {
      try PrivateDirectory.removeExtendedACL(
        descriptor: descriptor,
        operation: .removeInheritedRegistryPermissions
      )
    } catch {
      _ = close(descriptor)
      _ = unlinkat(directoryDescriptor, temporaryName, 0)
      throw error
    }

    var shouldRemoveTemporary = true
    defer {
      if shouldRemoveTemporary {
        _ = unlinkat(directoryDescriptor, temporaryName, 0)
      }
    }

    do {
      guard fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
        throw ProfileCoreError.filesystem(operation: .setPrivateRegistryPermissions)
      }
      try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        var offset = 0
        while offset < rawBuffer.count {
          let writtenCount = Darwin.write(
            descriptor,
            baseAddress.advanced(by: offset),
            rawBuffer.count - offset
          )
          if writtenCount < 0, errno == EINTR {
            continue
          }
          guard writtenCount > 0 else {
            throw ProfileCoreError.filesystem(operation: .writeRegistry)
          }
          offset += writtenCount
        }
      }
      if fcntl(descriptor, F_FULLFSYNC) != 0 {
        guard fsync(descriptor) == 0 else {
          throw ProfileCoreError.filesystem(operation: .secureRegistry)
        }
      }
      guard close(descriptor) == 0 else {
        descriptorIsOpen = false
        throw ProfileCoreError.filesystem(operation: .closeRegistryUpdate)
      }
      descriptorIsOpen = false
      guard
        renameat(
          directoryDescriptor,
          temporaryName,
          directoryDescriptor,
          registryFileName
        ) == 0
      else {
        throw ProfileCoreError.filesystem(operation: .replaceRegistry)
      }
      shouldRemoveTemporary = false
      var syncResult: Int32
      repeat {
        syncResult = fsync(directoryDescriptor)
      } while syncResult != 0 && errno == EINTR
      guard syncResult == 0 || errno == EINVAL || errno == EOPNOTSUPP else {
        throw ProfileCoreError.filesystem(operation: .secureRegistryDirectory)
      }
    } catch {
      if descriptorIsOpen {
        _ = close(descriptor)
      }
      throw error
    }
  }

  private func withExclusiveLock<T>(_ operation: (Int32) throws -> T) throws -> T {
    let directory = registryURL.deletingLastPathComponent()
    try PrivateDirectory.ensure(directory, operation: .createRegistryDirectory)
    let directoryDescriptor = try PrivateDirectory.openValidatedDirectory(
      directory,
      operation: .openRegistryDirectory
    )
    defer { _ = close(directoryDescriptor) }

    var descriptor = openat(
      directoryDescriptor,
      lockFileName,
      O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
      S_IRUSR | S_IWUSR
    )
    if descriptor < 0, errno == EEXIST {
      descriptor = openat(
        directoryDescriptor,
        lockFileName,
        O_RDWR | O_NOFOLLOW | O_CLOEXEC
      )
    }
    let lockOpenError = errno
    guard descriptor >= 0 else {
      throw ProfileCoreError.filesystem(
        operation: .openRegistryLock(posixError: lockOpenError)
      )
    }
    defer {
      _ = flock(descriptor, LOCK_UN)
      _ = close(descriptor)
    }

    var information = stat()
    guard fstat(descriptor, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      information.st_uid == geteuid(),
      fchmod(descriptor, S_IRUSR | S_IWUSR) == 0,
      flock(descriptor, LOCK_EX) == 0
    else {
      throw ProfileCoreError.filesystem(operation: .secureRegistryLock)
    }
    try PrivateDirectory.removeExtendedACL(
      descriptor: descriptor,
      operation: .secureRegistryLock
    )
    try PrivateDirectory.validateNoExtendedACL(
      descriptor: descriptor,
      operation: .secureRegistryLock
    )
    return try operation(directoryDescriptor)
  }

  private func validateDirectoryIsolation(_ candidate: Profile, against profiles: [Profile]) throws
  {
    let candidateDirectories = try comparableDirectories(for: candidate)
    let existingDirectories = try profiles.map(comparableDirectories)
    try validateDirectoryIsolation(
      candidateDirectories,
      against: existingDirectories,
      reserved: comparableReservedDirectories()
    )
  }

  private func validateDirectoryIsolation(_ profiles: [Profile]) throws {
    guard !profiles.isEmpty else { return }
    let reservedDirectories = try comparableReservedDirectories()
    var validatedDirectories: [ComparableProfileDirectories] = []
    validatedDirectories.reserveCapacity(profiles.count)
    for profile in profiles {
      let candidate = try comparableDirectories(for: profile)
      try validateDirectoryIsolation(
        candidate,
        against: validatedDirectories,
        reserved: reservedDirectories
      )
      validatedDirectories.append(candidate)
    }
  }

  private func validateDirectoryIsolation(
    _ candidate: ComparableProfileDirectories,
    against profiles: [ComparableProfileDirectories],
    reserved: ComparableReservedDirectories
  ) throws {
    let codexHomeUsesReservedStorage =
      Self.directoriesOverlap(candidate.codexHome.comparablePath, reserved.managedGUIRoot)
      || Self.directoriesOverlap(candidate.codexHome.comparablePath, reserved.registry)
    guard !codexHomeUsesReservedStorage else {
      throw ProfileCoreError.profileDirectoryAlreadyUsed(
        path: candidate.codexHome.url.path,
        profileID: candidate.profileID.rawValue
      )
    }
    let guiUsesReservedStorage =
      Self.directoriesOverlap(candidate.guiDataDirectory.comparablePath, reserved.registry)
      || (candidate.hasExplicitGUIDataDirectory
        && Self.directoriesOverlap(
          candidate.guiDataDirectory.comparablePath,
          reserved.managedGUIRoot
        ))
    guard !guiUsesReservedStorage else {
      throw ProfileCoreError.profileDirectoryAlreadyUsed(
        path: candidate.guiDataDirectory.url.path,
        profileID: candidate.profileID.rawValue
      )
    }
    guard
      !Self.directoriesOverlap(
        candidate.codexHome.comparablePath,
        candidate.guiDataDirectory.comparablePath
      )
    else {
      throw ProfileCoreError.profileDirectoryAlreadyUsed(
        path: candidate.codexHome.url.path,
        profileID: candidate.profileID.rawValue
      )
    }

    for profile in profiles {
      for directory in [candidate.codexHome, candidate.guiDataDirectory] {
        for existingDirectory in [profile.codexHome, profile.guiDataDirectory] {
          guard
            !Self.directoriesOverlap(
              directory.comparablePath,
              existingDirectory.comparablePath
            )
          else {
            throw ProfileCoreError.profileDirectoryAlreadyUsed(
              path: directory.url.path,
              profileID: profile.profileID.rawValue
            )
          }
        }
      }
    }
  }

  private func comparableDirectories(for profile: Profile) throws -> ComparableProfileDirectories {
    let guiDataDirectory = try profile.effectiveGUIDataDirectory(
      applicationSupportDirectory: applicationSupportDirectory
    )
    let codexHomePath = try Self.comparablePhysicalPath(profile.codexHome)
    let guiDataDirectoryPath = try Self.comparablePhysicalPath(guiDataDirectory)
    return ComparableProfileDirectories(
      profileID: profile.id,
      codexHome: ComparableDirectory(
        url: profile.codexHome,
        comparablePath: codexHomePath
      ),
      guiDataDirectory: ComparableDirectory(
        url: guiDataDirectory,
        comparablePath: guiDataDirectoryPath
      ),
      hasExplicitGUIDataDirectory: profile.guiDataDirectory != nil
    )
  }

  private func comparableReservedDirectories() throws -> ComparableReservedDirectories {
    ComparableReservedDirectories(
      managedGUIRoot: try Self.comparablePhysicalPath(
        applicationSupportDirectory.appendingPathComponent("gui", isDirectory: true)
      ),
      registry: try Self.comparablePhysicalPath(registryURL)
    )
  }

  static func directoriesOverlap(_ first: URL, _ second: URL) throws -> Bool {
    let firstPath = try comparablePhysicalPath(first)
    let secondPath = try comparablePhysicalPath(second)
    return directoriesOverlap(firstPath, secondPath)
  }

  private static func directoriesOverlap(_ firstPath: String, _ secondPath: String) -> Bool {
    return firstPath == secondPath
      || firstPath.hasPrefix("\(secondPath)/")
      || secondPath.hasPrefix("\(firstPath)/")
  }

  private static func comparablePhysicalPath(_ url: URL) throws -> String {
    let physicalURL = try PrivateDirectory.physicalIdentityURL(
      url,
      operation: .compareProfileStoragePaths
    )
    var existingAncestor = physicalURL
    while !FileManager.default.fileExists(atPath: existingAncestor.path) {
      let parent = existingAncestor.deletingLastPathComponent()
      guard parent.path != existingAncestor.path else {
        throw ProfileCoreError.filesystem(operation: .inspectProfileStorageVolume)
      }
      existingAncestor = parent
    }
    let values = try existingAncestor.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]
    )
    guard let isCaseSensitive = values.volumeSupportsCaseSensitiveNames else {
      throw ProfileCoreError.filesystem(operation: .inspectProfileStorageVolume)
    }
    let path = physicalURL.path.precomposedStringWithCanonicalMapping
    return isCaseSensitive ? path : path.lowercased()
  }

  static func validateRegistrySize(_ byteCount: Int) throws {
    guard byteCount >= 0, byteCount <= Int(maximumRegistryBytes) else {
      throw ProfileCoreError.registryTooLarge
    }
  }
}

private struct ComparableProfileDirectories {
  let profileID: ProfileID
  let codexHome: ComparableDirectory
  let guiDataDirectory: ComparableDirectory
  let hasExplicitGUIDataDirectory: Bool
}

private struct ComparableDirectory {
  let url: URL
  let comparablePath: String
}

private struct ComparableReservedDirectories {
  let managedGUIRoot: String
  let registry: String
}

private struct RegistryFile: Codable, Sendable {
  let schemaVersion: Int
  var profiles: [Profile]
}
