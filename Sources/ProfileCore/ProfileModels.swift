import Foundation

public enum ProfileCoreError: Error, Equatable, LocalizedError, Sendable {
  case invalidProfileID(String)
  case invalidDisplayName
  case invalidAbsolutePath(field: String, path: String)
  case profileAlreadyExists(String)
  case profileDirectoryAlreadyUsed(path: String, profileID: String)
  case profileNotFound(String)
  case malformedRegistry
  case unsupportedRegistryVersion(Int)
  case filesystem(operation: String)
  case executableNotFound(String)
  case applicationNotFound
  case processLaunchFailed(String)
  case invalidLauncherDestination(String)
  case launcherNotManaged(String)
  case registryTooLarge
  case tooManyProfiles
  case unsafeDirectoryPermissions(String)

  public var errorDescription: String? {
    switch self {
    case .invalidProfileID:
      "Invalid profile ID. Use 1–32 lowercase letters, digits, underscores, or hyphens, starting with a letter or digit."
    case .invalidDisplayName:
      "Display name must not be blank."
    case .invalidAbsolutePath(let field, _):
      "\(field) must be an absolute path."
    case .profileAlreadyExists(let id):
      "Profile '\(id)' already exists. Choose another ID or update the existing profile."
    case .profileDirectoryAlreadyUsed(let path, let profileID):
      "Directory '\(path)' is already assigned to profile '\(profileID)'. Choose a separate directory."
    case .profileNotFound(let id):
      "Profile '\(id)' was not found. Run 'opm profile list' to see configured profiles."
    case .malformedRegistry:
      "The profile registry is malformed. Repair or move it aside, then retry."
    case .unsupportedRegistryVersion(let version):
      "Registry schema version \(version) is not supported by this version of opm."
    case .filesystem(let operation):
      "Could not \(operation). Check the path and its permissions, then retry."
    case .executableNotFound(let name):
      "Could not find executable '\(name)'. Install it and ensure it is available on PATH."
    case .processLaunchFailed(let name):
      "Could not launch '\(name)'. Check that it is executable, then retry."
    case .applicationNotFound:
      "No supported official app was found. Install ChatGPT.app or Codex.app, or pass --app-path."
    case .invalidLauncherDestination(let path):
      "Launcher destination must be an absolute directory: \(path)"
    case .launcherNotManaged(let path):
      "Refusing to replace or remove an app not managed by Open Profile Manager: \(path)"
    case .registryTooLarge:
      "The profile registry exceeds the 1 MiB safety limit."
    case .tooManyProfiles:
      "The profile registry cannot contain more than 128 profiles."
    case .unsafeDirectoryPermissions(let path):
      "Directory '\(path)' must be owned by you with permissions 0700. Update its permissions, then retry."
    }
  }
}

public struct ProfileID: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
  public let rawValue: String

  public init(rawValue: String) throws {
    guard Self.isValid(rawValue) else {
      throw ProfileCoreError.invalidProfileID(rawValue)
    }
    self.rawValue = rawValue
  }

  public init(_ value: String) throws {
    try self.init(rawValue: value)
  }

  public var description: String { rawValue }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public static func isValid(_ value: String) -> Bool {
    guard (1...32).contains(value.utf8.count),
      let first = value.utf8.first,
      isLowercaseLetterOrDigit(first)
    else {
      return false
    }
    return value.utf8.dropFirst().allSatisfy {
      isLowercaseLetterOrDigit($0) || $0 == 45 || $0 == 95
    }
  }

  private static func isLowercaseLetterOrDigit(_ byte: UInt8) -> Bool {
    (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    do {
      try self.init(value)
    } catch {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid profile ID"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct Profile: Codable, Equatable, Sendable {
  public static let maximumDisplayNameBytes = 128
  public static let maximumPathBytes = 4_096

  public let id: ProfileID
  public var displayName: String
  public var codexHome: URL
  public var guiDataDirectory: URL?

  public init(
    id: ProfileID,
    displayName: String,
    codexHome: URL,
    guiDataDirectory: URL? = nil
  ) throws {
    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
      name.utf8.count <= Self.maximumDisplayNameBytes,
      !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    else {
      throw ProfileCoreError.invalidDisplayName
    }
    self.id = id
    self.displayName = name
    self.codexHome = try Self.normalizedAbsoluteURL(codexHome, field: "CODEX_HOME")
    if let guiDataDirectory {
      self.guiDataDirectory = try Self.normalizedAbsoluteURL(
        guiDataDirectory,
        field: "GUI data directory"
      )
    } else {
      self.guiDataDirectory = nil
    }
  }

  public static func normalizedAbsoluteURL(_ url: URL, field: String) throws -> URL {
    let standardized = url.standardizedFileURL
    let path = standardized.path
    guard standardized.isFileURL,
      path.hasPrefix("/"),
      path != "/",
      path.utf8.count <= maximumPathBytes,
      !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    else {
      throw ProfileCoreError.invalidAbsolutePath(field: field, path: url.path)
    }
    return standardized
  }

  public static func fileURL(fromUserPath value: String, field: String) throws -> URL {
    let path = (value.trimmingCharacters(in: .whitespacesAndNewlines) as NSString)
      .expandingTildeInPath
    guard path.hasPrefix("/") else {
      throw ProfileCoreError.invalidAbsolutePath(field: field, path: path)
    }
    return try normalizedAbsoluteURL(URL(fileURLWithPath: path, isDirectory: true), field: field)
  }

  public func effectiveGUIDataDirectory(applicationSupportDirectory: URL) throws -> URL {
    let directory =
      guiDataDirectory
      ?? applicationSupportDirectory
      .appendingPathComponent("gui", isDirectory: true)
      .appendingPathComponent(id.rawValue, isDirectory: true)
    return try Self.normalizedAbsoluteURL(directory, field: "GUI data directory")
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case displayName
    case codexHome
    case guiDataDirectory
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(ProfileID.self, forKey: .id)
    let displayName = try container.decode(String.self, forKey: .displayName)
    let codexHomePath = try container.decode(String.self, forKey: .codexHome)
    let guiPath = try container.decodeIfPresent(String.self, forKey: .guiDataDirectory)
    guard codexHomePath.hasPrefix("/"),
      !codexHomePath.utf8.contains(0),
      guiPath.map({ $0.hasPrefix("/") && !$0.utf8.contains(0) }) ?? true
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .codexHome,
        in: container,
        debugDescription: "Profile paths must be absolute"
      )
    }
    do {
      try self.init(
        id: id,
        displayName: displayName,
        codexHome: URL(fileURLWithPath: codexHomePath),
        guiDataDirectory: guiPath.map { URL(fileURLWithPath: $0) }
      )
    } catch {
      throw DecodingError.dataCorruptedError(
        forKey: .codexHome,
        in: container,
        debugDescription: "Invalid profile"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(codexHome.path, forKey: .codexHome)
    try container.encodeIfPresent(guiDataDirectory?.path, forKey: .guiDataDirectory)
  }
}

public struct ProfileUpdate: Sendable {
  public var displayName: String?
  public var codexHome: URL?
  public var guiDataDirectory: URL?
  public var clearGUIDataDirectory: Bool

  public init(
    displayName: String? = nil,
    codexHome: URL? = nil,
    guiDataDirectory: URL? = nil,
    clearGUIDataDirectory: Bool = false
  ) {
    self.displayName = displayName
    self.codexHome = codexHome
    self.guiDataDirectory = guiDataDirectory
    self.clearGUIDataDirectory = clearGUIDataDirectory
  }
}

public enum OPMVersion {
  public static let current = "0.1.2"
}
