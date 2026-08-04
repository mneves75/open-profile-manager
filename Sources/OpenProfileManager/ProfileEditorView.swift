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
  @FocusState private var focusedField: EditorField?

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
    VStack(spacing: 0) {
      EditorHeader(isEditing: configuration.mode == .edit)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)

      Form {
        Section {
          TextField(
            L10n.string("Profile ID"),
            text: $profileID,
            prompt: Text(verbatim: L10n.string("work"))
          )
          .font(.body.monospaced())
          .disabled(configuration.mode == .edit)
          .textContentType(.username)
          .focused($focusedField, equals: .profileID)
          TextField(
            L10n.string("Display name"),
            text: $displayName,
            prompt: Text(verbatim: L10n.string("Work"))
          )
          .focused($focusedField, equals: .displayName)
        }

        Section {
          DirectoryField(
            title: "CODEX_HOME",
            text: $codexHome,
            prompt: "~/.codex",
            focus: $focusedField,
            field: .codexHome
          )
          DirectoryField(
            title: L10n.string("Desktop data directory (optional)"),
            text: $guiDataDirectory,
            prompt: L10n.string("Managed automatically"),
            focus: $focusedField,
            field: .guiDataDirectory
          )
        } footer: {
          Label {
            Text(
              verbatim: L10n.string(
                "Authentication remains managed by the official Codex CLI inside this home."
              )
            )
          } icon: {
            Image(systemName: "lock.shield")
          }
          .font(.caption)
        }

        if let errorMessage {
          Section {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
              .font(.callout)
              .foregroundStyle(.red)
              .accessibilityLabel(L10n.string("Profile error: %@", errorMessage))
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)

      Divider()
      HStack(spacing: 10) {
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
      .padding(18)
      .background(AppVisualStyle.sidebar)
    }
    .frame(width: 620, height: 650)
    .background(AppVisualStyle.canvas)
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

private enum EditorField: Hashable {
  case profileID
  case displayName
  case codexHome
  case guiDataDirectory
}

private struct EditorHeader: View {
  let isEditing: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: isEditing ? "pencil" : "plus")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: isEditing ? L10n.string("Edit Profile") : L10n.string("Add Profile"))
          .font(.title2.bold())
        Text(verbatim: L10n.string("Use a separate Codex home for each account or workspace."))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct DirectoryField: View {
  let title: String
  @Binding var text: String
  let prompt: String
  let focus: FocusState<EditorField?>.Binding
  let field: EditorField

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(verbatim: title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      HStack(spacing: 10) {
        TextField(title, text: $text, prompt: Text(verbatim: prompt))
          .font(.body.monospaced())
          .textFieldStyle(.roundedBorder)
          .focused(focus, equals: field)
        Button(L10n.string("Choose…")) { chooseDirectory() }
          .accessibilityLabel(L10n.string("Choose directory for %@", title))
      }
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
