import AppKit
import ProfileCore
import SwiftUI

struct ProfileEditorView: View {
  let configuration: EditorConfiguration
  let errorMessage: String?
  let onSave: (String, String, String, String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var profileID: String
  @State private var displayName: String
  @State private var codexHome: String
  @State private var guiDataDirectory: String

  init(
    configuration: EditorConfiguration,
    errorMessage: String?,
    onSave: @escaping (String, String, String, String) -> Void
  ) {
    self.configuration = configuration
    self.errorMessage = errorMessage
    self.onSave = onSave
    _profileID = State(initialValue: configuration.profileID)
    _displayName = State(initialValue: configuration.displayName)
    _codexHome = State(initialValue: configuration.codexHome)
    _guiDataDirectory = State(initialValue: configuration.guiDataDirectory)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      EditorHeader(isEditing: configuration.mode == .edit)
      Form {
        TextField(
          L10n.string("Profile ID"),
          text: $profileID,
          prompt: Text(verbatim: L10n.string("work"))
        )
        .disabled(configuration.mode == .edit)
        .textContentType(.username)
        TextField(
          L10n.string("Display name"),
          text: $displayName,
          prompt: Text(verbatim: L10n.string("Work"))
        )
        DirectoryField(
          title: "CODEX_HOME",
          text: $codexHome,
          prompt: "~/.codex"
        )
        DirectoryField(
          title: L10n.string("Desktop data directory (optional)"),
          text: $guiDataDirectory,
          prompt: L10n.string("Managed automatically")
        )
      }
      Text(
        verbatim: L10n.string(
          "Authentication remains managed by the official Codex CLI inside this home."
        )
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.callout)
          .foregroundStyle(.red)
          .accessibilityLabel(L10n.string("Profile error: %@", errorMessage))
      }
      HStack {
        Spacer()
        Button(L10n.string("Cancel"), role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
          .accessibilityLabel(L10n.string("Cancel"))
        Button(
          configuration.mode == .edit
            ? L10n.string("Save Changes") : L10n.string("Add Profile")
        ) {
          onSave(profileID, displayName, codexHome, guiDataDirectory)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
        .accessibilityLabel(
          configuration.mode == .edit
            ? L10n.string("Save Changes") : L10n.string("Add Profile")
        )
      }
    }
    .padding(24)
    .frame(width: 560)
  }

  private var canSave: Bool {
    ProfileID.isValid(profileID)
      && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && isValidPath(codexHome)
      && isValidPath(guiDataDirectory, allowingEmpty: true)
  }

  private func isValidPath(_ value: String, allowingEmpty: Bool = false) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return allowingEmpty }
    return (try? Profile.fileURL(fromUserPath: trimmed, field: "Path")) != nil
  }
}

private struct EditorHeader: View {
  let isEditing: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(
        verbatim: isEditing ? L10n.string("Edit Profile") : L10n.string("Add Profile")
      )
      .font(.title2.bold())
      Text(
        verbatim: L10n.string("Use a separate Codex home for each account or workspace.")
      )
      .foregroundStyle(.secondary)
    }
  }
}

private struct DirectoryField: View {
  let title: String
  @Binding var text: String
  let prompt: String

  var body: some View {
    HStack {
      TextField(title, text: $text, prompt: Text(prompt))
        .font(.body.monospaced())
      Button(L10n.string("Choose…")) { chooseDirectory() }
        .accessibilityLabel(L10n.string("Choose directory for %@", title))
    }
  }

  private func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = false
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      text = url.path
    }
  }
}
