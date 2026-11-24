import AppKit
import ProfileCore
import SwiftUI

struct ProfileEditorView: View {
  let configuration: EditorConfiguration
  let errorMessage: String?
  let isSaving: Bool
  let onSave: (ProfileDraft) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: ProfileDraft
  @State private var didEditProfileID: Bool
  @State private var showAdvanced: Bool
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
    _didEditProfileID = State(initialValue: configuration.mode == .edit)
    _showAdvanced = State(initialValue: !configuration.draft.guiDataDirectory.isEmpty)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(
          verbatim: configuration.mode == .edit
            ? L10n.string("Edit Profile")
            : L10n.string("New Profile")
        )
        .font(.title3.weight(.semibold))
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 8)

      Form {
        Section {
          TextField(
            L10n.string("Display name"),
            text: $draft.displayName,
            prompt: Text(verbatim: L10n.string("Work"))
          )
          .focused($focusedField, equals: .displayName)
          .onChange(of: draft.displayName) { _, newValue in
            guard configuration.mode == .add, !didEditProfileID else { return }
            draft.profileID = ProfileID.suggested(from: newValue)
          }
          .onSubmit {
            focusedField = configuration.mode == .edit ? .codexHome : .profileID
          }

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
          .onChange(of: draft.profileID) { _, newValue in
            if configuration.mode == .add,
              newValue != ProfileID.suggested(from: draft.displayName)
            {
              didEditProfileID = true
            }
          }
          .onSubmit { focusedField = .codexHome }
        }

        Section {
          DirectoryField(
            title: "CODEX_HOME",
            text: $draft.codexHome,
            prompt: "~/.codex",
            focus: $focusedField,
            field: .codexHome,
            onSubmit: {
              if canSave, !isSaving {
                onSave(draft)
              }
            }
          )

          DisclosureGroup(L10n.string("Advanced"), isExpanded: $showAdvanced) {
            DirectoryField(
              title: L10n.string("Desktop data directory"),
              text: $draft.guiDataDirectory,
              prompt: L10n.string("Automatic"),
              focus: $focusedField,
              field: .guiDataDirectory
            )
            .padding(.top, 6)
          }
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

      Divider()

      HStack(spacing: 10) {
        Spacer()
        Button(L10n.string("Cancel"), role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button(
          configuration.mode == .edit
            ? L10n.string("Save Changes")
            : L10n.string("Add Profile")
        ) {
          onSave(draft)
        }
        .keyboardShortcut(.defaultAction)
        .opmProminentButtonStyle()
        .disabled(!canSave || isSaving)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
    }
    .frame(minWidth: 460, idealWidth: 520, maxWidth: 640, minHeight: 380, idealHeight: 430)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      focusedField = .displayName
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
  case displayName
  case profileID
  case codexHome
  case guiDataDirectory
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
    VStack(alignment: .leading, spacing: 6) {
      Text(verbatim: title)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      HStack(spacing: 8) {
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
