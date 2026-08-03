import Foundation

public struct ProfileManager: Sendable {
  public let registry: ProfileRegistry
  public let launchPlanner: LaunchPlanner

  public init(
    registryURL: URL = ProfileRegistry.defaultRegistryURL(),
    applicationSupportDirectory: URL? = nil
  ) throws {
    registry = try ProfileRegistry(
      registryURL: registryURL,
      applicationSupportDirectory: applicationSupportDirectory
    )
    launchPlanner = try LaunchPlanner(
      applicationSupportDirectory: registry.applicationSupportDirectory
    )
  }

  public func addProfile(
    id: String,
    displayName: String,
    codexHome: URL,
    guiDataDirectory: URL? = nil
  ) throws -> Profile {
    let profile = try Profile(
      id: ProfileID(id),
      displayName: displayName,
      codexHome: codexHome,
      guiDataDirectory: guiDataDirectory
    )
    return try registry.add(profile)
  }

  public func listProfiles() throws -> [Profile] {
    try registry.list()
  }

  public func profile(id: String) throws -> Profile {
    try registry.get(ProfileID(id))
  }

  public func updateProfile(id: String, with update: ProfileUpdate) throws -> Profile {
    try registry.update(ProfileID(id), with: update)
  }

  public func removeProfile(id: String) throws -> Profile {
    try registry.remove(ProfileID(id))
  }

  public func codexPlan(
    profileID: String,
    arguments: [String],
    codexExecutable: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ProcessPlan {
    try launchPlanner.codexPlan(
      for: profile(id: profileID),
      arguments: arguments,
      codexExecutable: codexExecutable,
      environment: environment
    )
  }

  public func executeCodex(
    profileID: String,
    arguments: [String],
    codexExecutable: URL? = nil
  ) throws -> ProcessResult {
    try ProcessExecutor.execute(
      codexPlan(
        profileID: profileID,
        arguments: arguments,
        codexExecutable: codexExecutable
      )
    )
  }

  public func appPlan(profileID: String, explicitAppURL: URL? = nil) throws -> ProcessPlan {
    try launchPlanner.appPlan(for: profile(id: profileID), explicitAppURL: explicitAppURL)
  }

  public func launchApp(profileID: String, explicitAppURL: URL? = nil) throws -> ProcessResult {
    let selectedProfile = try profile(id: profileID)
    try launchPlanner.prepareAppDataDirectory(for: selectedProfile)
    return try ProcessExecutor.execute(
      launchPlanner.appPlan(for: selectedProfile, explicitAppURL: explicitAppURL)
    )
  }

  public func status(
    profileID: String,
    service: CodexStatusService = CodexStatusService(),
    codexExecutable: URL? = nil
  ) throws -> ProfileStatus {
    service.readStatus(for: try profile(id: profileID), codexExecutable: codexExecutable)
  }

  public func doctor(profileID: String? = nil) throws -> DoctorReport {
    let selectedProfile = try profileID.map { try profile(id: $0) }
    return DoctorService().run(
      registry: registry,
      profile: selectedProfile
    )
  }

  public func installLauncher(
    profileID: String,
    opmExecutable: URL,
    destinationDirectory: URL = LauncherInstaller.defaultDestination(),
    shouldSign: Bool = true
  ) throws -> URL {
    try LauncherInstaller(shouldSign: shouldSign).install(
      profile: profile(id: profileID),
      opmExecutable: opmExecutable,
      destinationDirectory: destinationDirectory
    )
  }

  public func removeLauncher(
    profileID: String,
    destinationDirectory: URL = LauncherInstaller.defaultDestination()
  ) throws -> Bool {
    try LauncherInstaller().remove(
      profileID: ProfileID(profileID),
      destinationDirectory: destinationDirectory
    )
  }
}
