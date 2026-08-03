import Darwin
import Foundation

public enum DoctorCheckState: String, Codable, Sendable {
  case pass
  case warning
  case failure
}

public struct DoctorCheck: Codable, Equatable, Sendable {
  public let name: String
  public let state: DoctorCheckState
  public let detail: String
  public let remediation: String?

  public init(
    name: String,
    state: DoctorCheckState,
    detail: String,
    remediation: String? = nil
  ) {
    self.name = name
    self.state = state
    self.detail = detail
    self.remediation = remediation
  }
}

public struct DoctorReport: Codable, Equatable, Sendable {
  public let checks: [DoctorCheck]

  public init(checks: [DoctorCheck]) {
    self.checks = checks
  }

  public var hasFailures: Bool {
    checks.contains { $0.state == .failure }
  }
}

public struct DoctorService: Sendable {
  public init() {}

  public func run(
    registry: ProfileRegistry,
    profile: Profile? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> DoctorReport {
    var checks: [DoctorCheck] = []
    checks.append(registryCheck(registry))
    checks.append(executableCheck(environment: environment))
    checks.append(applicationCheck())
    if let profile {
      checks.append(
        directoryCheck(
          name: "CODEX_HOME (\(profile.id.rawValue))",
          url: profile.codexHome
        ))
      if let planner = try? LaunchPlanner(
        applicationSupportDirectory: registry.applicationSupportDirectory
      ),
        let guiDataDirectory = try? planner.appDataDirectory(for: profile)
      {
        checks.append(
          directoryCheck(
            name: "GUI data directory (\(profile.id.rawValue))",
            url: guiDataDirectory,
            allowingMissing: true
          ))
      } else {
        checks.append(
          DoctorCheck(
            name: "GUI data directory (\(profile.id.rawValue))",
            state: .failure,
            detail: "The effective GUI data directory path is invalid.",
            remediation: "Choose an absolute, non-root GUI data directory."
          ))
      }
    }
    return DoctorReport(checks: checks)
  }

  private func registryCheck(_ registry: ProfileRegistry) -> DoctorCheck {
    let url = registry.registryURL
    var information = stat()
    let registryExists = lstat(url.path, &information) == 0
    if registryExists, information.st_mode & 0o777 != 0o600 {
      return DoctorCheck(
        name: "Profile registry",
        state: .failure,
        detail: "Registry permissions are not owner-only.",
        remediation: "Set the registry file mode to 0600."
      )
    }
    do {
      _ = try registry.list()
    } catch {
      return DoctorCheck(
        name: "Profile registry",
        state: .failure,
        detail: "Registry privacy, ownership, contents, or schema validation failed.",
        remediation:
          "Require current-user ownership, mode 0600, no extended ACLs, and valid registry JSON."
      )
    }
    if !registryExists {
      return DoctorCheck(
        name: "Profile registry",
        state: .warning,
        detail: "No registry exists yet; its destination path is safe.",
        remediation: "Create a profile with 'opm profile add'."
      )
    }
    return DoctorCheck(
      name: "Profile registry",
      state: .pass,
      detail: "Registry is readable with owner-only permissions."
    )
  }

  private func executableCheck(environment: [String: String]) -> DoctorCheck {
    do {
      let executable = try ExecutableLocator.resolve("codex", environment: environment)
      return DoctorCheck(
        name: "Codex CLI",
        state: .pass,
        detail: "Found codex at \(executable.path)."
      )
    } catch {
      return DoctorCheck(
        name: "Codex CLI",
        state: .failure,
        detail: "Codex CLI was not found.",
        remediation: "Install the official Codex CLI and add it to PATH."
      )
    }
  }

  private func applicationCheck() -> DoctorCheck {
    do {
      let application = try LaunchPlanner().discoverApplication()
      return DoctorCheck(
        name: "Official macOS app",
        state: .pass,
        detail: "Found \(application.path)."
      )
    } catch {
      return DoctorCheck(
        name: "Official macOS app",
        state: .warning,
        detail: "No launchable supported official macOS app was found.",
        remediation: "Install ChatGPT.app or Codex.app, or use --app-path."
      )
    }
  }

  private func directoryCheck(
    name: String,
    url: URL,
    allowingMissing: Bool = false
  ) -> DoctorCheck {
    var information = stat()
    if lstat(url.path, &information) != 0, errno == ENOENT, allowingMissing {
      do {
        try PrivateDirectory.validateCreationPath(
          url,
          operation: "validate the managed directory path"
        )
        return DoctorCheck(
          name: name,
          state: .pass,
          detail: "Directory does not exist yet and will be created privately on launch."
        )
      } catch {
        return DoctorCheck(
          name: name,
          state: .failure,
          detail: "Directory creation path contains a symlink or invalid ancestor.",
          remediation: "Choose a path whose existing ancestors are real directories."
        )
      }
    }
    do {
      try PrivateDirectory.validate(url, operation: "validate the managed directory")
    } catch {
      return DoctorCheck(
        name: name,
        state: .failure,
        detail:
          "Directory is missing, symlinked, ACL-accessible, not owned by this user, or not mode 0700.",
        remediation:
          "Use a current-user-owned directory without symlinks or extended ACLs and with mode 0700."
      )
    }
    return DoctorCheck(name: name, state: .pass, detail: "Directory is private.")
  }

}
