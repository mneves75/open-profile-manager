import Darwin
import Foundation
import Security

public struct ProcessPlan: Sendable, Equatable {
  public let executableURL: URL
  public let arguments: [String]
  public let environment: [String: String]

  public init(executableURL: URL, arguments: [String], environment: [String: String]) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.environment = environment
  }
}

public struct ProcessResult: Codable, Equatable, Sendable {
  public let exitCode: Int32

  public init(exitCode: Int32) {
    self.exitCode = exitCode
  }
}

public enum ExecutableLocator {
  public static func resolve(
    _ name: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> URL {
    if name.contains("/") {
      let url = URL(fileURLWithPath: name).standardizedFileURL
      guard url.path.hasPrefix("/"), let executable = regularExecutable(url) else {
        throw ProfileCoreError.executableNotFound(name)
      }
      return executable
    }

    let environmentDirectories = (environment["PATH"] ?? "")
      .split(separator: ":", omittingEmptySubsequences: true)
      .map(String.init)
    let fallbackDirectories = [
      homeDirectory.appendingPathComponent(".local/bin", isDirectory: true).path,
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
    ]
    var visited = Set<String>()
    for directory in environmentDirectories + fallbackDirectories
    where visited.insert(directory).inserted {
      guard directory.hasPrefix("/") else { continue }
      let candidate = URL(fileURLWithPath: directory, isDirectory: true)
        .appendingPathComponent(name, isDirectory: false)
        .standardizedFileURL
      if let executable = regularExecutable(candidate) {
        return executable
      }
    }
    throw ProfileCoreError.executableNotFound(name)
  }

  private static func regularExecutable(_ url: URL) -> URL? {
    let resolved = url.resolvingSymlinksInPath().standardizedFileURL
    var information = stat()
    guard lstat(resolved.path, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      FileManager.default.isExecutableFile(atPath: resolved.path)
    else { return nil }
    return resolved
  }
}

public enum ProcessExecutor {
  public static func execute(_ plan: ProcessPlan) throws -> ProcessResult {
    let process = Process()
    process.executableURL = plan.executableURL
    process.arguments = plan.arguments
    process.environment = plan.environment
    do {
      try process.run()
    } catch {
      throw ProfileCoreError.processLaunchFailed(plan.executableURL.lastPathComponent)
    }
    process.waitUntilExit()
    return ProcessResult(exitCode: process.terminationStatus)
  }

  public static func replaceCurrentProcess(with plan: ProcessPlan) throws -> Never {
    let executableName = plan.executableURL.lastPathComponent
    var arguments = try duplicateCStrings(
      [plan.executableURL.path] + plan.arguments,
      executableName: executableName
    )
    defer { freeCStrings(&arguments) }
    var environment = try duplicateCStrings(
      plan.environment.map { "\($0.key)=\($0.value)" },
      executableName: executableName
    )
    defer { freeCStrings(&environment) }

    _ = plan.executableURL.path.withCString { executable in
      arguments.withUnsafeMutableBufferPointer { argumentBuffer in
        environment.withUnsafeMutableBufferPointer { environmentBuffer in
          execve(executable, argumentBuffer.baseAddress, environmentBuffer.baseAddress)
        }
      }
    }
    throw ProfileCoreError.processLaunchFailed(executableName)
  }

  private static func duplicateCStrings(
    _ strings: [String],
    executableName: String
  ) throws -> [UnsafeMutablePointer<CChar>?] {
    guard strings.allSatisfy({ !$0.utf8.contains(0) }) else {
      throw ProfileCoreError.processLaunchFailed(executableName)
    }
    var result: [UnsafeMutablePointer<CChar>?] = strings.map {
      $0.withCString(strdup)
    }
    guard result.allSatisfy({ $0 != nil }) else {
      freeCStrings(&result)
      throw ProfileCoreError.processLaunchFailed(executableName)
    }
    result.append(nil)
    return result
  }

  private static func freeCStrings(_ strings: inout [UnsafeMutablePointer<CChar>?]) {
    for string in strings {
      free(string)
    }
    strings.removeAll(keepingCapacity: false)
  }
}

public struct LaunchPlanner: Sendable {
  private static let maximumApplicationPlistBytes = 262_144
  private static let allowedApplicationBundleIdentifiers: Set<String> = ["com.openai.codex"]
  private static let officialApplicationRequirement =
    "anchor apple generic and certificate leaf[subject.OU] = \"2DC432GLL2\" and identifier \"com.openai.codex\""

  public let applicationSupportDirectory: URL
  private let applicationSignatureValidator: @Sendable (URL) -> Bool

  public init(
    applicationSupportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/OpenProfileManager", isDirectory: true)
  ) throws {
    try self.init(
      applicationSupportDirectory: applicationSupportDirectory,
      applicationSignatureValidator: Self.hasOfficialApplicationSignature
    )
  }

  init(
    applicationSupportDirectory: URL,
    applicationSignatureValidator: @escaping @Sendable (URL) -> Bool
  ) throws {
    self.applicationSupportDirectory = try Profile.normalizedAbsoluteURL(
      applicationSupportDirectory,
      field: "Application Support directory"
    )
    self.applicationSignatureValidator = applicationSignatureValidator
  }

  public func codexPlan(
    for profile: Profile,
    arguments: [String],
    codexExecutable: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ProcessPlan {
    try PrivateDirectory.validate(profile.codexHome, operation: "use CODEX_HOME")
    let executable =
      try codexExecutable.map(validateExecutable)
      ?? ExecutableLocator.resolve(
        "codex",
        environment: environment
      )
    let childEnvironment = ProfileEnvironment.isolated(
      from: environment,
      codexHome: profile.codexHome
    )
    return ProcessPlan(
      executableURL: executable,
      arguments: arguments,
      environment: childEnvironment
    )
  }

  public func loginPlan(
    for profile: Profile,
    codexExecutable: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ProcessPlan {
    try codexPlan(
      for: profile,
      arguments: ["login"],
      codexExecutable: codexExecutable,
      environment: environment
    )
  }

  public func logoutPlan(
    for profile: Profile,
    codexExecutable: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ProcessPlan {
    try codexPlan(
      for: profile,
      arguments: ["logout"],
      codexExecutable: codexExecutable,
      environment: environment
    )
  }

  public func appPlan(for profile: Profile, explicitAppURL: URL? = nil) throws -> ProcessPlan {
    try PrivateDirectory.validate(profile.codexHome, operation: "use CODEX_HOME")
    let appURL = try discoverApplication(explicitAppURL: explicitAppURL)
    let normalizedDataDirectory = try appDataDirectory(for: profile)
    let childEnvironment = ProfileEnvironment.isolated(
      from: ProcessInfo.processInfo.environment,
      codexHome: profile.codexHome
    )
    return ProcessPlan(
      executableURL: URL(fileURLWithPath: "/usr/bin/open"),
      arguments: [
        "-n",
        "--env",
        "CODEX_HOME=\(profile.codexHome.path)",
        "-a",
        appURL.path,
        "--args",
        "--user-data-dir=\(normalizedDataDirectory.path)",
      ],
      environment: childEnvironment
    )
  }

  public func prepareAppDataDirectory(for profile: Profile) throws {
    try PrivateDirectory.ensure(
      appDataDirectory(for: profile),
      operation: "create the GUI data directory"
    )
  }

  public func appDataDirectory(for profile: Profile) throws -> URL {
    try profile.effectiveGUIDataDirectory(
      applicationSupportDirectory: applicationSupportDirectory
    )
  }

  public func discoverApplication(explicitAppURL: URL? = nil) throws -> URL {
    try discoverApplication(
      explicitAppURL: explicitAppURL,
      homeDirectory: FileManager.default.homeDirectoryForCurrentUser
    )
  }

  func discoverApplication(explicitAppURL: URL?, homeDirectory: URL) throws -> URL {
    try discoverApplication(
      explicitAppURL: explicitAppURL,
      candidateURLs: [
        homeDirectory.appendingPathComponent("Applications/ChatGPT.app", isDirectory: true),
        homeDirectory.appendingPathComponent("Applications/Codex.app", isDirectory: true),
        URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
        URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
      ]
    )
  }

  func discoverApplication(explicitAppURL: URL?, candidateURLs: [URL]) throws -> URL {
    if let explicitAppURL {
      guard let application = validatedApplication(explicitAppURL) else {
        throw ProfileCoreError.applicationNotFound
      }
      return application
    }

    for candidate in candidateURLs {
      if let application = validatedApplication(candidate) {
        return application
      }
    }
    throw ProfileCoreError.applicationNotFound
  }

  private func validateExecutable(_ url: URL) throws -> URL {
    let normalized = try Profile.normalizedAbsoluteURL(url, field: "Executable path")
    let resolved = normalized.resolvingSymlinksInPath().standardizedFileURL
    var information = stat()
    guard lstat(resolved.path, &information) == 0,
      information.st_mode & S_IFMT == S_IFREG,
      FileManager.default.isExecutableFile(atPath: resolved.path)
    else {
      throw ProfileCoreError.executableNotFound(normalized.path)
    }
    return resolved
  }

  private func validatedApplication(_ url: URL) -> URL? {
    guard let normalized = try? Profile.normalizedAbsoluteURL(url, field: "App path"),
      normalized.pathExtension == "app"
    else { return nil }
    var bundleInformation = stat()
    guard lstat(normalized.path, &bundleInformation) == 0,
      bundleInformation.st_mode & S_IFMT == S_IFDIR
    else { return nil }
    let plistURL = normalized.appendingPathComponent("Contents/Info.plist", isDirectory: false)
    guard
      let data = try? BoundedFile.readRegularFile(
        at: plistURL,
        maximumBytes: Self.maximumApplicationPlistBytes,
        operation: "read an application property list"
      ),
      let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any],
      let executableName = plist["CFBundleExecutable"] as? String,
      let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
      !executableName.isEmpty,
      !executableName.contains("/"),
      Self.allowedApplicationBundleIdentifiers.contains(bundleIdentifier)
    else { return nil }
    let executable =
      normalized
      .appendingPathComponent("Contents/MacOS", isDirectory: true)
      .appendingPathComponent(executableName, isDirectory: false)
    var executableInformation = stat()
    guard lstat(executable.path, &executableInformation) == 0,
      executableInformation.st_mode & S_IFMT == S_IFREG,
      FileManager.default.isExecutableFile(atPath: executable.path),
      applicationSignatureValidator(normalized)
    else { return nil }
    return normalized
  }

  private static func hasOfficialApplicationSignature(_ url: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
      let staticCode
    else { return false }

    var requirement: SecRequirement?
    guard
      SecRequirementCreateWithString(
        officialApplicationRequirement as CFString,
        SecCSFlags(),
        &requirement
      ) == errSecSuccess,
      let requirement
    else { return false }

    return SecStaticCodeCheckValidity(
      staticCode,
      SecCSFlags(
        rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode),
      requirement
    ) == errSecSuccess
  }
}
