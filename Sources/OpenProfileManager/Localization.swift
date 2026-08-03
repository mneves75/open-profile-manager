import Foundation
import ProfileCore

enum L10n {
  nonisolated static var locale: Locale {
    Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en-US")
  }

  nonisolated static func string(_ key: String.LocalizationValue, _ arguments: CVarArg...)
    -> String
  {
    let format = String(localized: key, bundle: .main)
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: locale, arguments: arguments)
  }

  nonisolated static func error(_ error: Error) -> String {
    guard let error = error as? ProfileCoreError else {
      return string("An unexpected error occurred. Please try again.")
    }

    switch error {
    case .invalidProfileID:
      return string(
        "Invalid profile ID. Use 1–32 lowercase letters, digits, underscores, or hyphens, starting with a letter or digit."
      )
    case .invalidDisplayName:
      return string("Display name must not be blank.")
    case .invalidAbsolutePath(let field, _):
      return string("%@ must be an absolute path.", fieldName(field))
    case .profileAlreadyExists(let id):
      return string(
        "Profile '%@' already exists. Choose another ID or update the existing profile.", id)
    case .profileDirectoryAlreadyUsed(let path, let profileID):
      return string(
        "Directory '%@' is already assigned to profile '%@'. Choose a separate directory.",
        path,
        profileID
      )
    case .profileNotFound(let id):
      return string(
        "Profile '%@' was not found. Run 'opm profile list' to see configured profiles.", id)
    case .malformedRegistry:
      return string("The profile registry is malformed. Repair or move it aside, then retry.")
    case .unsupportedRegistryVersion(let version):
      return string(
        "Registry schema version %lld is not supported by this version of opm.", version)
    case .filesystem(let operation):
      return string(
        "Could not %@. Check the path and its permissions, then retry.",
        operationName(operation)
      )
    case .executableNotFound(let name):
      return string(
        "Could not find executable '%@'. Install it and ensure it is available on PATH.", name)
    case .applicationNotFound:
      return string(
        "No supported official app was found. Install ChatGPT.app or Codex.app, or pass --app-path."
      )
    case .processLaunchFailed(let name):
      return string("Could not launch '%@'. Check that it is executable, then retry.", name)
    case .invalidLauncherDestination(let path):
      return string("Launcher destination must be an absolute directory: %@", path)
    case .launcherNotManaged(let path):
      return string(
        "Refusing to replace or remove an app not managed by Open Profile Manager: %@", path)
    case .registryTooLarge:
      return string("The profile registry exceeds the 1 MiB safety limit.")
    case .tooManyProfiles:
      return string("The profile registry cannot contain more than 128 profiles.")
    case .unsafeDirectoryPermissions(let path):
      return string(
        "Directory '%@' must be owned by you with permissions 0700. Update its permissions, then retry.",
        path
      )
    }
  }

  nonisolated private static func fieldName(_ field: String) -> String {
    return switch field {
    case "App path": string("App path")
    case "Application Support directory", "Application support directory":
      string("Application Support directory")
    case "Codex executable": string("Codex executable")
    case "Executable path": string("Executable path")
    case "GUI data directory": string("Desktop data directory")
    case "Launcher destination": string("Launcher destination")
    case "opm executable": string("opm executable")
    case "Registry path": string("Profile registry path")
    case "Path": string("Path")
    default: field
    }
  }

  nonisolated private static func operationName(_ operation: String) -> String {
    if operation.hasPrefix("open the profile registry lock (POSIX error ") {
      let code = operation.dropFirst("open the profile registry lock (POSIX error ".count)
        .dropLast()
      return string("open the profile registry lock (POSIX error %@)", String(code))
    }

    return switch operation {
    case "use CODEX_HOME": string("use CODEX_HOME")
    case "create CODEX_HOME": string("create CODEX_HOME")
    case "create GUI data directory": string("create the desktop data directory")
    case "create the GUI data directory": string("create the desktop data directory")
    case "read an application property list": string("read an application property list")
    case "secure the launcher bundle": string("secure the launcher bundle")
    case "make the launcher executable": string("make the launcher executable")
    case "secure the launcher property list": string("secure the launcher property list")
    case "install the Finder launcher": string("install the Finder launcher")
    case "remove the Finder launcher": string("remove the Finder launcher")
    case "create a private launcher destination": string("create a private launcher destination")
    case "read a managed launcher property list": string("read a managed launcher property list")
    case "set private directory permissions": string("set private directory permissions")
    case "inspect the profile registry directory": string("inspect the profile registry directory")
    case "validate the profile registry directory path":
      string("validate the profile registry directory path")
    case "read the profile registry directory": string("read the profile registry directory")
    case "open the profile registry": string("open the profile registry")
    case "read a regular profile registry file": string("read a regular profile registry file")
    case "read a private profile registry file": string("read a private profile registry file")
    case "read the profile registry": string("read the profile registry")
    case "encode the profile registry": string("encode the profile registry")
    case "create a private registry update": string("create a private registry update")
    case "remove inherited registry permissions": string("remove inherited registry permissions")
    case "set private registry permissions": string("set private registry permissions")
    case "write the profile registry": string("write the profile registry")
    case "secure the profile registry": string("secure the profile registry")
    case "close the profile registry update": string("close the profile registry update")
    case "atomically replace the profile registry":
      string("atomically replace the profile registry")
    case "secure the profile registry directory": string("secure the profile registry directory")
    case "create the registry directory": string("create the registry directory")
    case "open the profile registry directory": string("open the profile registry directory")
    case "secure the profile registry lock": string("secure the profile registry lock")
    case "compare profile storage paths": string("compare profile storage paths")
    case "inspect profile storage volume": string("inspect the profile storage volume")
    default: string("complete the requested operation")
    }
  }
}
