import ArgumentParser
import CoreFoundation
import Darwin
import Foundation
import ProfileCore

@main
enum OPMEntryPoint {
  static func main() async {
    if LauncherBundleMode.runIfNeeded() {
      return
    }
    await OPMCommand.main()
  }
}

struct OPMCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "opm",
    abstract: "Manage explicit, isolated local Codex profiles.",
    version: OPMVersion.current,
    subcommands: [
      ProfileCommand.self,
      RunCommand.self,
      LoginCommand.self,
      LogoutCommand.self,
      StatusCommand.self,
      AppCommand.self,
      LauncherCommand.self,
      DoctorCommand.self,
      VersionCommand.self,
    ]
  )
}

struct ProfileCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile",
    abstract: "Manage the local profile registry.",
    subcommands: [
      ProfileAddCommand.self,
      ProfileEditCommand.self,
      ProfileListCommand.self,
      ProfileShowCommand.self,
      ProfileRemoveCommand.self,
    ]
  )
}

struct ProfileAddCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Register a new Codex profile."
  )

  @Argument(help: "Stable lowercase profile ID.")
  var id: String

  @Option(name: .long, help: "Human-readable profile name.")
  var name: String

  @Option(
    name: [.customLong("home"), .customLong("codex-home")],
    help: "Absolute CODEX_HOME path."
  )
  var codexHome: String

  @Option(name: .customLong("gui-data-dir"), help: "Optional absolute desktop-app data path.")
  var guiDataDirectory: String?

  @Flag(name: .long, help: "Emit stable JSON.")
  var json = false

  func run() throws {
    let profile = try ProfileManager().addProfile(
      id: id,
      displayName: name,
      codexHome: try absoluteURL(codexHome, field: .codexHome),
      guiDataDirectory: try guiDataDirectory.map {
        try absoluteURL($0, field: .guiDataDirectory)
      }
    )
    if json {
      try printJSON(profile)
    } else {
      print("Added \(profile.id.rawValue) (\(profile.displayName)).")
    }
  }
}

struct ProfileEditCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "edit",
    abstract: "Update an existing Codex profile."
  )

  @Argument(help: "Profile ID to update.")
  var id: String

  @Option(name: .long, help: "New human-readable profile name.")
  var name: String?

  @Option(
    name: [.customLong("home"), .customLong("codex-home")],
    help: "New absolute CODEX_HOME path."
  )
  var codexHome: String?

  @Option(name: .customLong("gui-data-dir"), help: "New absolute desktop-app data path.")
  var guiDataDirectory: String?

  @Flag(name: .customLong("clear-gui-data-dir"), help: "Reset desktop-app data path to automatic.")
  var clearGUIDataDirectory = false

  @Flag(name: .long, help: "Emit stable JSON.")
  var json = false

  func validate() throws {
    if guiDataDirectory != nil, clearGUIDataDirectory {
      throw ValidationError("Choose --gui-data-dir or --clear-gui-data-dir, not both.")
    }
    if name == nil, codexHome == nil, guiDataDirectory == nil, !clearGUIDataDirectory {
      throw ValidationError(
        "Provide at least one change (--name, --home, --gui-data-dir, or --clear-gui-data-dir)."
      )
    }
  }

  func run() throws {
    let update = ProfileUpdate(
      displayName: name,
      codexHome: try codexHome.map { try absoluteURL($0, field: .codexHome) },
      guiDataDirectory: try guiDataDirectory.map { try absoluteURL($0, field: .guiDataDirectory) },
      clearGUIDataDirectory: clearGUIDataDirectory
    )
    let profile = try ProfileManager().updateProfile(id: id, with: update)
    if json {
      try printJSON(profile)
    } else {
      print("Updated \(profile.id.rawValue) (\(profile.displayName)).")
    }
  }
}

struct ProfileListCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List configured profiles."
  )

  @Flag(name: .long, help: "Emit stable JSON.")
  var json = false

  func run() throws {
    let profiles = try ProfileManager().listProfiles()
    if json {
      try printJSON(profiles)
    } else if profiles.isEmpty {
      print("No profiles configured. Add one with 'opm profile add'.")
    } else {
      for profile in profiles {
        print("\(profile.id.rawValue)\t\(profile.displayName)\t\(profile.codexHome.path)")
      }
    }
  }
}

struct ProfileShowCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show details for a profile."
  )

  @Argument var id: String
  @Flag(name: .long, help: "Emit stable JSON.") var json = false

  func run() throws {
    let profile = try ProfileManager().profile(id: id)
    if json {
      try printJSON(profile)
    } else {
      print("ID: \(profile.id.rawValue)")
      print("Name: \(profile.displayName)")
      print("CODEX_HOME: \(profile.codexHome.path)")
      print("GUI data: \(profile.guiDataDirectory?.path ?? "automatic")")
    }
  }
}

struct ProfileRemoveCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove",
    abstract: "Remove a profile entry without deleting files on disk."
  )

  @Argument var id: String
  @Flag(name: .long, help: "Emit stable JSON.") var json = false

  func run() throws {
    let removed = try ProfileManager().removeProfile(id: id)
    if json {
      try printJSON(removed)
    } else {
      print("Removed \(removed.id.rawValue). Authentication files were left untouched.")
    }
  }
}

struct RunCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run Codex directly with the selected profile."
  )

  @Argument var profile: String
  @Argument(parsing: .captureForPassthrough, help: "Arguments passed unchanged to codex.")
  var codexArguments: [String] = []

  func run() throws {
    try ProfileManager().replaceCurrentProcessWithCodex(
      profileID: profile,
      arguments: codexArguments
    )
  }
}

struct LoginCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "login",
    abstract: "Authenticate a profile using the official Codex login flow."
  )
  @Argument var profile: String

  func run() throws {
    try ProfileManager().replaceCurrentProcessWithCodex(profileID: profile, arguments: ["login"])
  }
}

struct LogoutCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "logout",
    abstract: "Sign out of a profile using the official Codex logout flow."
  )
  @Argument var profile: String

  func run() throws {
    try ProfileManager().replaceCurrentProcessWithCodex(profileID: profile, arguments: ["logout"])
  }
}

struct StatusCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Inspect read-only account and rate-limit status."
  )

  @Argument(help: "Profile ID. Omit with --all to inspect every profile.")
  var profile: String?
  @Flag(name: .long, help: "Inspect every configured profile.") var all = false
  @Flag(name: .long, help: "Emit stable JSON.") var json = false

  func validate() throws {
    if profile != nil, all {
      throw ValidationError("Choose a profile or --all, not both.")
    }
    if profile == nil, !all {
      throw ValidationError("Provide a profile ID or pass --all.")
    }
  }

  func run() async throws {
    let profileManager = try ProfileManager()
    let profiles: [Profile]
    if let profile {
      profiles = [try profileManager.profile(id: profile)]
    } else {
      profiles = try profileManager.listProfiles()
    }
    let statuses = await profileManager.statuses(profiles: profiles)
    if json {
      try printJSON(statuses)
    } else if statuses.isEmpty {
      print("No profiles configured. Add one with 'opm profile add'.")
    } else {
      for status in statuses {
        printStatus(status)
      }
    }
  }
}

struct AppCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "app",
    abstract: "Launch the official ChatGPT or Codex desktop app for a profile.",
    subcommands: [AppLaunchCommand.self]
  )
}

struct AppLaunchCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "launch",
    abstract: "Open an isolated official desktop app instance for a profile."
  )
  @Argument var profile: String
  @Option(name: .customLong("app-path"), help: "Absolute path to an installed official app.")
  var appPath: String?

  func run() throws {
    let result = try ProfileManager().launchApp(
      profileID: profile,
      explicitAppURL: try appPath.map { try absoluteURL($0, field: .appPath) }
    )
    guard result.exitCode == 0 else { throw ExitCode(result.exitCode) }
  }
}

struct LauncherCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "launcher",
    abstract: "Manage per-profile Finder launchers.",
    subcommands: [LauncherInstallCommand.self, LauncherRemoveCommand.self]
  )
}

struct LauncherInstallCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "install",
    abstract: "Install a per-profile Finder launcher app."
  )
  @Argument var profile: String
  @Option(name: .long, help: "Absolute launcher destination directory.")
  var destination: String?

  func run() throws {
    guard let executable = Bundle.main.executableURL else {
      throw ProfileCoreError.executableNotFound("opm")
    }
    let installed = try ProfileManager().installLauncher(
      profileID: profile,
      opmExecutable: executable,
      destinationDirectory: try destination.map {
        try absoluteURL($0, field: .launcherDestination)
      }
        ?? LauncherInstaller.defaultDestination()
    )
    print("Installed \(installed.path).")
  }
}

struct LauncherRemoveCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove",
    abstract: "Remove a managed Finder launcher app."
  )
  @Argument var profile: String
  @Option(name: .long, help: "Absolute launcher destination directory.")
  var destination: String?

  func run() throws {
    let removed = try ProfileManager().removeLauncher(
      profileID: profile,
      destinationDirectory: try destination.map {
        try absoluteURL($0, field: .launcherDestination)
      }
        ?? LauncherInstaller.defaultDestination()
    )
    print(removed ? "Removed launcher for \(profile)." : "No launcher exists for \(profile).")
  }
}

struct DoctorCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "doctor",
    abstract: "Verify local profile permissions, executables, and desktop app support."
  )
  @Argument var profile: String?
  @Flag(name: .long, help: "Emit stable JSON.") var json = false

  func run() throws {
    let report = try ProfileManager().doctor(profileID: profile)
    if json {
      try printJSON(report)
    } else {
      for check in report.checks {
        print("[\(check.state.rawValue)] \(check.name): \(check.detail)")
        if let remediation = check.remediation {
          print("  \(remediation)")
        }
      }
    }
    if report.hasFailures {
      throw ExitCode.failure
    }
  }
}

struct VersionCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "version",
    abstract: "Print the opm version."
  )
  func run() {
    print(OPMVersion.current)
  }
}

private func absoluteURL(_ path: String, field: PathField) throws -> URL {
  guard path.hasPrefix("/"), !path.utf8.contains(0) else {
    throw ProfileCoreError.invalidAbsolutePath(field: field, path: path)
  }
  return URL(fileURLWithPath: path)
}

private func printJSON<T: Encodable>(_ value: T) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  let data = try encoder.encode(value)
  guard let output = String(data: data, encoding: .utf8) else {
    throw ProfileCoreError.filesystem(operation: .renderJSONOutput)
  }
  print(output)
}

private func printStatus(_ status: ProfileStatus) {
  var summary = "\(status.profileID.rawValue): \(status.state.rawValue)"
  if let account = status.account {
    summary += " (\(account.type))"
  }
  print(summary)
  if let primary = status.rateLimits?.primary {
    print("  Primary window used: \(primary.usedPercent)%")
  }
  if let secondary = status.rateLimits?.secondary {
    print("  Secondary window used: \(secondary.usedPercent)%")
  }
  if let message = status.message {
    print("  \(message)")
  }
}

private enum LauncherBundleMode {
  static func runIfNeeded(bundle: Bundle = .main) -> Bool {
    guard
      let marker = bundle.object(forInfoDictionaryKey: "OPMManagedLauncher") as? NSNumber,
      CFGetTypeID(marker) == CFBooleanGetTypeID(),
      marker.boolValue
    else {
      return false
    }
    guard let rawProfileID = bundle.object(forInfoDictionaryKey: "OPMProfileID") as? String else {
      fail("This launcher is missing its managed profile ID.")
    }
    do {
      let profileID = try ProfileID(rawProfileID)
      let result = try ProfileManager().launchApp(profileID: profileID.rawValue)
      exit(result.exitCode)
    } catch let error as LocalizedError {
      fail(error.errorDescription ?? "The managed profile could not be launched.")
    } catch {
      fail("The managed profile could not be launched.")
    }
  }

  private static func fail(_ message: String) -> Never {
    let data = Data("opm: \(message)\n".utf8)
    try? FileHandle.standardError.write(contentsOf: data)
    exit(EXIT_FAILURE)
  }
}
