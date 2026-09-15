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

  nonisolated private static func fieldName(_ field: PathField) -> String {
    return switch field {
    case .appPath: string("App path")
    case .applicationSupportDirectory: string("Application Support directory")
    case .codexExecutable: string("Codex executable")
    case .codexHome: "CODEX_HOME"
    case .executablePath: string("Executable path")
    case .guiDataDirectory: string("Desktop data directory")
    case .launcherDestination: string("Launcher destination")
    case .opmExecutable: string("opm executable")
    case .registryPath: string("Profile registry path")
    }
  }

  nonisolated private static func operationName(_ operation: FilesystemOperation) -> String {
    return switch operation {
    case .useCodexHome: string("use CODEX_HOME")
    case .createCodexHome: string("create CODEX_HOME")
    case .createGUIDataDirectory: string("create the desktop data directory")
    case .readApplicationPropertyList: string("read an application property list")
    case .secureLauncherBundle: string("secure the launcher bundle")
    case .makeLauncherExecutable: string("make the launcher executable")
    case .secureLauncherPropertyList: string("secure the launcher property list")
    case .installFinderLauncher: string("install the Finder launcher")
    case .removeFinderLauncher: string("remove the Finder launcher")
    case .createPrivateLauncherDestination: string("create a private launcher destination")
    case .readManagedLauncherPropertyList: string("read a managed launcher property list")
    case .setPrivateDirectoryPermissions: string("set private directory permissions")
    case .inspectRegistryDirectory: string("inspect the profile registry directory")
    case .validateRegistryDirectoryPath: string("validate the profile registry directory path")
    case .readRegistryDirectory: string("read the profile registry directory")
    case .openRegistry: string("open the profile registry")
    case .readRegularRegistryFile: string("read a regular profile registry file")
    case .readPrivateRegistryFile: string("read a private profile registry file")
    case .readRegistry: string("read the profile registry")
    case .encodeRegistry: string("encode the profile registry")
    case .createPrivateRegistryUpdate: string("create a private registry update")
    case .removeInheritedRegistryPermissions: string("remove inherited registry permissions")
    case .setPrivateRegistryPermissions: string("set private registry permissions")
    case .writeRegistry: string("write the profile registry")
    case .secureRegistry: string("secure the profile registry")
    case .closeRegistryUpdate: string("close the profile registry update")
    case .replaceRegistry: string("atomically replace the profile registry")
    case .secureRegistryDirectory: string("secure the profile registry directory")
    case .createRegistryDirectory: string("create the registry directory")
    case .openRegistryDirectory: string("open the profile registry directory")
    case .openRegistryLock(let posixError):
      string("open the profile registry lock (POSIX error %@)", String(posixError))
    case .secureRegistryLock: string("secure the profile registry lock")
    case .compareProfileStoragePaths: string("compare profile storage paths")
    case .inspectProfileStorageVolume: string("inspect the profile storage volume")
    // Doctor checks and CLI JSON rendering handle these internally; they never reach the native app.
    case .validateManagedDirectoryPath, .validateManagedDirectory, .renderJSONOutput:
      string("complete the requested operation")
    }
  }
}
