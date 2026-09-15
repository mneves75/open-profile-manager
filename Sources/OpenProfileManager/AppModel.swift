import AppKit
import Foundation
import Observation
import ProfileCore

struct ProfileDraft: Equatable, Sendable {
  var profileID: String
  var displayName: String
  var codexHome: String
  var guiDataDirectory: String
}

struct EditorConfiguration: Identifiable, Sendable {
  enum Mode: Sendable {
    case add
    case edit
  }

  let id = UUID()
  let mode: Mode
  let draft: ProfileDraft
}

@MainActor
@Observable
final class AppModel {
  typealias StatusReader = @Sendable (ProfileManager, [Profile]) async -> [ProfileStatus]

  private let manager: ProfileManager?
  private let readStatuses: StatusReader
  @ObservationIgnored private var didStart = false
  @ObservationIgnored private var reloadGeneration = 0
  @ObservationIgnored private var statusReadTask: Task<[ProfileStatus], Never>?

  var profiles: [Profile] = []
  var selectedProfileID: ProfileID?
  var statuses: [ProfileID: ProfileStatus] = [:]
  var isRefreshing = false
  var isSaving = false
  var editor: EditorConfiguration?
  var editorErrorMessage: String?
  var pendingRemoval: Profile?
  var isShowingRemoveConfirmation = false
  var isShowingAlert = false
  var alertTitle = L10n.string("Error")
  var alertMessage = ""

  convenience init() {
    do {
      self.init(manager: try ProfileManager())
    } catch {
      self.init(manager: nil)
      showError(error)
    }
  }

  init(
    manager: ProfileManager?,
    readStatuses: @escaping StatusReader = { manager, profiles in
      await manager.statuses(profiles: profiles)
    }
  ) {
    self.manager = manager
    self.readStatuses = readStatuses
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

  /// Reloads can overlap (toolbar refresh, save, removal); only the newest one may publish results.
  func reload() async {
    guard let manager else { return }
    reloadGeneration += 1
    let generation = reloadGeneration
    // A superseded refresh's app-server reads are stopped rather than left to reach their timeout.
    statusReadTask?.cancel()
    isRefreshing = true
    defer {
      if generation == reloadGeneration {
        isRefreshing = false
      }
    }

    let outcome = await Self.perform { try manager.listProfiles() }
    guard generation == reloadGeneration else { return }
    switch outcome {
    case .success(let loadedProfiles):
      profiles = loadedProfiles
      if selectedProfileID.map({ selected in loadedProfiles.contains { $0.id == selected } })
        != true
      {
        selectedProfileID = loadedProfiles.first?.id
      }
      let readStatuses = readStatuses
      let statusRead = Task { await readStatuses(manager, loadedProfiles) }
      statusReadTask = statusRead
      let refreshed = await statusRead.value
      guard generation == reloadGeneration else { return }
      statusReadTask = nil
      statuses = Dictionary(
        refreshed.map { ($0.profileID, $0) },
        uniquingKeysWith: { _, latest in latest }
      )
    case .failure(let message):
      showError(message)
    }
  }

  func presentNewProfile() {
    editorErrorMessage = nil
    editor = EditorConfiguration(
      mode: .add,
      draft: ProfileDraft(profileID: "", displayName: "", codexHome: "", guiDataDirectory: "")
    )
  }

  func presentEditor(for profile: Profile) {
    editorErrorMessage = nil
    editor = EditorConfiguration(
      mode: .edit,
      draft: ProfileDraft(
        profileID: profile.id.rawValue,
        displayName: profile.displayName,
        codexHome: profile.codexHome.path,
        guiDataDirectory: profile.guiDataDirectory?.path ?? ""
      )
    )
  }

  func saveProfile(configuration: EditorConfiguration, draft: ProfileDraft) {
    guard let manager, !isSaving else { return }
    let trimmedGUIPath = draft.guiDataDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    let codexURL: URL
    let guiURL: URL?
    do {
      codexURL = try Profile.fileURL(fromUserPath: draft.codexHome, field: .codexHome)
      guiURL =
        try trimmedGUIPath.isEmpty
        ? nil
        : Profile.fileURL(fromUserPath: trimmedGUIPath, field: .guiDataDirectory)
    } catch {
      editorErrorMessage = L10n.error(error)
      return
    }
    editorErrorMessage = nil
    isSaving = true

    Task {
      let outcome = await Self.perform {
        switch configuration.mode {
        case .add:
          return try manager.addProfile(
            id: draft.profileID,
            displayName: draft.displayName,
            codexHome: codexURL,
            guiDataDirectory: guiURL
          )
        case .edit:
          return try manager.updateProfile(
            id: configuration.draft.profileID,
            with: ProfileUpdate(
              displayName: draft.displayName,
              codexHome: codexURL,
              guiDataDirectory: guiURL,
              clearGUIDataDirectory: guiURL == nil
            )
          )
        }
      }
      isSaving = false
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
      switch await Self.perform({ try manager.launchApp(profileID: profile.id.rawValue) }) {
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
      let outcome = await Self.perform {
        try manager.installLauncher(profileID: profile.id.rawValue, opmExecutable: executable)
      }
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
      switch await Self.perform({ try manager.removeProfile(id: pendingRemoval.id.rawValue) }) {
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

  private func showError(_ error: Error) {
    showError(L10n.error(error))
  }

  private func showError(_ message: String) {
    alertTitle = L10n.string("Error")
    alertMessage = message
    isShowingAlert = true
  }

  /// Registry, launcher, and process work blocks on file and process I/O, so it never runs on the main actor.
  @concurrent
  nonisolated private static func perform<Value: Sendable>(
    _ operation: @Sendable () throws -> Value
  ) async -> OperationOutcome<Value> {
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
