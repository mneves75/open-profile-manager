import AppKit
import ProfileCore
import SwiftUI

struct ProfileEditorView: View {
  let configuration: EditorConfiguration
  let errorMessage: String?
  let isSaving: Bool
  let onSave: (ProfileDraft) -> Void

  @Environment(\.dismiss) private var dismiss
  // Seeded once per presentation: each `sheet(item:)` configuration carries a fresh identity.
  @State private var draft: ProfileDraft
  @FocusState private var focusedField: EditorField?

  init(
    configuration: EditorConfiguration,
    errorMessage: String?,
    isSaving: Bool,
    onSave: @escaping (ProfileDraft) -> Void
  ) {
    self.configuration = configuration
    self.errorMessage = errorMessage
    self.isSaving = isSaving
    self.onSave = onSave
    _draft = State(initialValue: configuration.draft)
  }

  var body: some View {
    VStack(spacing: 0) {
      EditorHeader(isEditing: configuration.mode == .edit)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)

      Form {
        Section {
          // The label closure keeps the row label in the body font; only the typed ID is monospaced.
          TextField(
            text: $draft.profileID,
            prompt: Text(verbatim: L10n.string("work"))
          ) {
            Text(verbatim: L10n.string("Profile ID"))
              .font(.body)
          }
          .font(.body.monospaced())
          .disabled(configuration.mode == .edit)
          .focused($focusedField, equals: .profileID)
          .onSubmit { focusedField = .displayName }
          TextField(
            L10n.string("Display name"),
            text: $draft.displayName,
            prompt: Text(verbatim: L10n.string("Work"))
          )
          .focused($focusedField, equals: .displayName)
          .onSubmit { focusedField = .codexHome }
        }

        Section {
          DirectoryField(
            title: "CODEX_HOME",
            text: $draft.codexHome,
            prompt: "~/.codex",
            focus: $focusedField,
            field: .codexHome,
            onSubmit: { focusedField = .guiDataDirectory }
          )
          DirectoryField(
            title: L10n.string("Desktop data directory (optional)"),
            text: $draft.guiDataDirectory,
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
      EditorFooter(
        isEditing: configuration.mode == .edit,
        canSave: canSave && !isSaving,
        onCancel: { dismiss() },
        onSave: { onSave(draft) }
      )
    }
    .frame(
      minWidth: 520,
      idealWidth: 620,
      maxWidth: 760,
      minHeight: 520,
      idealHeight: 650
    )
    .background(AppVisualStyle.canvas)
    .onAppear {
      focusedField = configuration.mode == .edit ? .displayName : .profileID
    }
  }

  private var canSave: Bool {
    ProfileID.isValid(draft.profileID)
      && !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && isValidPath(draft.codexHome, field: .codexHome)
      && isValidPath(draft.guiDataDirectory, field: .guiDataDirectory, allowingEmpty: true)
  }

  private func isValidPath(_ value: String, field: PathField, allowingEmpty: Bool = false) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return allowingEmpty }
    return (try? Profile.fileURL(fromUserPath: trimmed, field: field)) != nil
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
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct EditorFooter: View {
  let isEditing: Bool
  let canSave: Bool
  let onCancel: () -> Void
  let onSave: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        Spacer()
        buttons
      }
      VStack(alignment: .trailing, spacing: 10) {
        buttons
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(18)
    .background(AppVisualStyle.sidebar)
  }

  @ViewBuilder
  private var buttons: some View {
    Button(L10n.string("Cancel"), role: .cancel, action: onCancel)
      .keyboardShortcut(.cancelAction)
    Button(saveTitle, action: onSave)
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.borderedProminent)
      .disabled(!canSave)
  }

  private var saveTitle: String {
    isEditing ? L10n.string("Save Changes") : L10n.string("Add Profile")
  }
}

private struct DirectoryField: View {
  let title: String
  @Binding var text: String
  let prompt: String
  let focus: FocusState<EditorField?>.Binding
  let field: EditorField
  let onSubmit: () -> Void

  init(
    title: String,
    text: Binding<String>,
    prompt: String,
    focus: FocusState<EditorField?>.Binding,
    field: EditorField,
    onSubmit: @escaping () -> Void = {}
  ) {
    self.title = title
    _text = text
    self.prompt = prompt
    self.focus = focus
    self.field = field
    self.onSubmit = onSubmit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(verbatim: title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        // The caption above names the field; a grouped Form would otherwise repeat the title as a row label.
        TextField(title, text: $text, prompt: Text(verbatim: prompt))
          .labelsHidden()
          .font(.body.monospaced())
          .textFieldStyle(.roundedBorder)
          .focused(focus, equals: field)
          .onSubmit(onSubmit)
          .layoutPriority(1)
        Button(L10n.string("Choose…")) { chooseDirectory() }
          .accessibilityLabel(L10n.string("Choose directory for %@", title))
          .fixedSize()
      }
    }
  }

  private func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    // Panel-created folders inherit the umask (0755) and would fail the 0700 profile-directory check.
    panel.canCreateDirectories = false
    panel.allowsMultipleSelection = false
    Task {
      let response =
        if let window = NSApplication.shared.keyWindow {
          await panel.beginSheetModal(for: window)
        } else {
          panel.runModal()
        }
      if response == .OK, let url = panel.url {
        text = url.path
      }
    }
  }
}
