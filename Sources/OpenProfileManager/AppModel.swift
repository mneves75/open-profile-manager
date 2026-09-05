import AppKit
import Foundation
import Observation
import ProfileCore

struct EditorConfiguration: Identifiable, Sendable {
  enum Mode: Sendable {
    case add
    case edit
  }

  let id = UUID()
  let mode: Mode
  let profileID: String
  let displayName: String
  let codexHome: String
  let guiDataDirectory: String
}

@MainActor
@Observable
final class AppModel {
  private let manager: ProfileManager?
  private var didStart = false

  var profiles: [Profile] = []
  var selectedProfileID: ProfileID?
  var statuses: [ProfileID: ProfileStatus] = [:]
  var isRefreshing = false
  var editor: EditorConfiguration?
  var editorErrorMessage: String?
  var pendingRemoval: Profile?
  var isShowingRemoveConfirmation = false
  var isShowingAlert = false
  var alertTitle = L10n.string("Error")
  var alertMessage = ""

  init() {
    do {
      manager = try ProfileManager()
    } catch {
      manager = nil
      showError(error)
    }
  }

  var selectedProfile: Profile? {
    guard let selectedProfileID else { return nil }
    return profiles.first { $0.id == selectedProfileID }
  }

  func start() {
    guard !didStart else { return }
    didStart = true
    Task { await reload() }
  }

  func reload() async {
    guard let manager else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    switch await Task.detached(
      priority: .userInitiated,
      operation: {
        Self.perform { try manager.listProfiles() }
      }
    ).value {
    case .success(let loadedProfiles):
      profiles = loadedProfiles
      if selectedProfileID.map({ selected in loadedProfiles.contains { $0.id == selected } })
        != true
      {
        selectedProfileID = loadedProfiles.first?.id
      }
      await refreshStatuses(for: loadedProfiles, using: manager)
    case .failure(let message):
      showError(message)
    }
  }

  func presentNewProfile() {
    editorErrorMessage = nil
    editor = EditorConfiguration(
      mode: .add,
      profileID: "",
      displayName: "",
      codexHome: "",
      guiDataDirectory: ""
    )
  }

  func presentEditor(for profile: Profile) {
    editorErrorMessage = nil
    editor = EditorConfiguration(
      mode: .edit,
      profileID: profile.id.rawValue,
      displayName: profile.displayName,
      codexHome: profile.codexHome.path,
      guiDataDirectory: profile.guiDataDirectory?.path ?? ""
    )
  }

  func saveProfile(
    configuration: EditorConfiguration,
    profileID: String,
    displayName: String,
    codexHome: String,
    guiDataDirectory: String
  ) {
    guard let manager else { return }
    let trimmedGUIPath = guiDataDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    let codexURL: URL
    let guiURL: URL?
    do {
      codexURL = try Profile.fileURL(fromUserPath: codexHome, field: "CODEX_HOME")
      guiURL =
        try trimmedGUIPath.isEmpty
        ? nil
        : Profile.fileURL(fromUserPath: trimmedGUIPath, field: "GUI data directory")
    } catch {
      editorErrorMessage = L10n.error(error)
      return
    }
    editorErrorMessage = nil

    Task {
      let outcome = await Task.detached(priority: .userInitiated) {
        Self.save(
          using: manager,
          configuration: configuration,
          profileID: profileID,
          displayName: displayName,
          codexHome: codexURL,
          guiDataDirectory: guiURL
        )
      }.value
      switch outcome {
      case .success(let profile):
        editor = nil
        selectedProfileID = profile.id
        await reload()
      case .failure(let message):
        editorErrorMessage = message
      }
    }
  }

  func launchApp(for profile: Profile) {
    guard let manager else { return }
    Task {
      let outcome = await Task.detached(priority: .userInitiated) {
        Self.perform { try manager.launchApp(profileID: profile.id.rawValue) }
      }.value
      switch outcome {
      case .success(let result) where result.exitCode != 0:
        showError(L10n.string("The desktop app could not be opened."))
      case .success:
        break
      case .failure(let message):
        showError(message)
      }
    }
  }

  func installLauncher(for profile: Profile) {
    guard let manager else { return }
    let executable: URL
    do {
      executable = try Self.resolveOPMExecutable()
    } catch {
      showError(error)
      return
    }

    Task {
      let outcome = await Task.detached(priority: .userInitiated) {
        Self.perform {
          try manager.installLauncher(
            profileID: profile.id.rawValue,
            opmExecutable: executable
          )
        }
      }.value
      switch outcome {
      case .success(let url):
        alertTitle = L10n.string("Launcher Installed")
        alertMessage = url.path
        isShowingAlert = true
      case .failure(let message):
        showError(message)
      }
    }
  }

  func copyCLICommand(for profile: Profile) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(
      "opm run \(profile.id.rawValue)",
      forType: .string
    )
  }

  func requestRemoval(of profile: Profile) {
    pendingRemoval = profile
    isShowingRemoveConfirmation = true
  }

  func confirmRemoval() {
    guard let manager, let pendingRemoval else { return }
    self.pendingRemoval = nil
    Task {
      let outcome = await Task.detached(priority: .userInitiated) {
        Self.perform { try manager.removeProfile(id: pendingRemoval.id.rawValue) }
      }.value
      switch outcome {
      case .success:
        selectedProfileID = nil
        await reload()
      case .failure(let message):
        showError(message)
      }
    }
  }

  func dismissAlert() {
    isShowingAlert = false
    alertMessage = ""
  }

  private func refreshStatuses(for profiles: [Profile], using manager: ProfileManager) async {
    let refreshed = await Task.detached(priority: .userInitiated) {
      await manager.statuses(profiles: profiles)
    }.value
    statuses = Dictionary(
      uniqueKeysWithValues: refreshed.map { ($0.profileID, $0) }
    )
  }

  private func showError(_ error: Error) {
    showError(L10n.error(error))
  }

  private func showError(_ message: String) {
    alertTitle = L10n.string("Error")
    alertMessage = message
    isShowingAlert = true
  }

  nonisolated private static func save(
    using manager: ProfileManager,
    configuration: EditorConfiguration,
    profileID: String,
    displayName: String,
    codexHome: URL,
    guiDataDirectory: URL?
  ) -> OperationOutcome<Profile> {
    perform {
      switch configuration.mode {
      case .add:
        return try manager.addProfile(
          id: profileID,
          displayName: displayName,
          codexHome: codexHome,
          guiDataDirectory: guiDataDirectory
        )
      case .edit:
        return try manager.updateProfile(
          id: configuration.profileID,
          with: ProfileUpdate(
            displayName: displayName,
            codexHome: codexHome,
            guiDataDirectory: guiDataDirectory,
            clearGUIDataDirectory: guiDataDirectory == nil
          )
        )
      }
    }
  }

  nonisolated private static func perform<Value: Sendable>(
    _ operation: () throws -> Value
  ) -> OperationOutcome<Value> {
    do {
      return .success(try operation())
    } catch {
      return .failure(L10n.error(error))
    }
  }

  nonisolated private static func resolveOPMExecutable() throws -> URL {
    if let appExecutable = Bundle.main.executableURL {
      let bundled =
        appExecutable
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/bin/opm", isDirectory: false)
      if FileManager.default.isExecutableFile(atPath: bundled.path) {
        return bundled
      }

      let sibling =
        appExecutable
        .deletingLastPathComponent()
        .appendingPathComponent("opm", isDirectory: false)
      if FileManager.default.isExecutableFile(atPath: sibling.path) {
        return sibling
      }
    }
    return try ExecutableLocator.resolve("opm")
  }
}

private enum OperationOutcome<Value: Sendable>: Sendable {
  case success(Value)
  case failure(String)
}
