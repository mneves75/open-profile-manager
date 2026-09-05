import Foundation

public struct ProfileManager: Sendable {
  private let registry: ProfileRegistry
  private let launchPlanner: LaunchPlanner

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

  private func codexPlan(
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

  public func replaceCurrentProcessWithCodex(
    profileID: String,
    arguments: [String],
    codexExecutable: URL? = nil
  ) throws -> Never {
    try ProcessExecutor.replaceCurrentProcess(
      with: codexPlan(
        profileID: profileID,
        arguments: arguments,
        codexExecutable: codexExecutable
      )
    )
  }

  public func launchApp(profileID: String, explicitAppURL: URL? = nil) throws -> ProcessResult {
    let selectedProfile = try profile(id: profileID)
    try launchPlanner.prepareAppDataDirectory(for: selectedProfile)
    return try ProcessExecutor.execute(
      launchPlanner.appPlan(for: selectedProfile, explicitAppURL: explicitAppURL)
    )
  }

  public func statuses(
    profiles: [Profile],
    service: CodexStatusService = CodexStatusService(),
    codexExecutable: URL? = nil
  ) async -> [ProfileStatus] {
    guard !profiles.isEmpty else { return [] }

    return await withTaskGroup(
      of: (Int, ProfileStatus).self,
      returning: [ProfileStatus].self
    ) { group in
      var remaining = profiles.enumerated().makeIterator()
      for _ in 0..<min(4, profiles.count) {
        guard let (index, profile) = remaining.next() else { break }
        group.addTask {
          (index, service.readStatus(for: profile, codexExecutable: codexExecutable))
        }
      }

      var results = [ProfileStatus?](repeating: nil, count: profiles.count)
      while let (index, status) = await group.next() {
        results[index] = status
        if let (nextIndex, nextProfile) = remaining.next() {
          group.addTask {
            (
              nextIndex,
              service.readStatus(for: nextProfile, codexExecutable: codexExecutable)
            )
          }
        }
      }
      return results.compactMap { $0 }
    }
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
