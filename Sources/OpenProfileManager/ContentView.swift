import ProfileCore
import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationSplitView {
      ProfileSidebar(
        profiles: model.profiles,
        statuses: model.statuses,
        selection: $model.selectedProfileID,
        onLaunch: { model.launchApp(for: $0) },
        onCopyCLI: { model.copyCLICommand(for: $0) },
        onEdit: { model.presentEditor(for: $0) },
        onInstallLauncher: { model.installLauncher(for: $0) },
        onRemove: { model.requestRemoval(of: $0) }
      )
      .navigationSplitViewColumnWidth(min: 220, ideal: 256, max: 320)
    } detail: {
      Group {
        if let profile = model.selectedProfile {
          ProfileDetailView(
            profile: profile,
            status: model.statuses[profile.id],
            isRefreshing: model.isRefreshing,
            copiedCommand: model.copiedCommand,
            onLaunch: { model.launchApp(for: profile) },
            onCopyCLI: { model.copyCLICommand(for: profile) },
            onCopyLogin: { model.copyLoginCommand(for: profile) },
            onCopyDoctor: { model.copyDoctorCommand(for: profile) },
            onRefresh: { Task { await model.reload() } },
            onEdit: { model.presentEditor(for: profile) },
            onInstallLauncher: { model.installLauncher(for: profile) },
            onShowDetails: { model.isInspectorPresented = true },
            onRemove: { model.requestRemoval(of: profile) }
          )
          .inspector(isPresented: $model.isInspectorPresented) {
            ProfileInspectorView(
              profile: profile,
              onRevealCodexHome: { model.revealInFinder(profile.codexHome) },
              onInstallLauncher: { model.installLauncher(for: profile) },
              onEdit: { model.presentEditor(for: profile) },
              onRemove: { model.requestRemoval(of: profile) }
            )
            .inspectorColumnWidth(min: 240, ideal: 276, max: 340)
          }
        } else {
          EmptyProfilesView(onAdd: model.presentNewProfile)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button(L10n.string("Add Profile"), systemImage: "plus", action: model.presentNewProfile)
          .help(L10n.string("Add a Codex profile"))
        Button(L10n.string("Refresh"), systemImage: "arrow.clockwise") {
          Task { await model.reload() }
        }
        .disabled(model.isRefreshing)
        .help(L10n.string("Refresh account and quota status"))
        if model.selectedProfile != nil {
          Button(
            L10n.string("Show Inspector"),
            systemImage: "sidebar.right",
            action: model.toggleInspector
          )
          .help(L10n.string("Show profile paths and details"))
        }
      }
    }
    .sheet(item: $model.editor) { configuration in
      ProfileEditorView(
        configuration: configuration,
        errorMessage: model.editorErrorMessage,
        isSaving: model.isSaving
      ) { draft in
        model.saveProfile(configuration: configuration, draft: draft)
      }
    }
    .alert(model.alertTitle, isPresented: $model.isShowingAlert) {
      Button(L10n.string("OK"), action: model.dismissAlert)
    } message: {
      Text(verbatim: model.alertMessage)
    }
    .confirmationDialog(
      L10n.string("Remove this profile?"),
      isPresented: $model.isShowingRemoveConfirmation,
      titleVisibility: .visible
    ) {
      Button(L10n.string("Remove Profile"), role: .destructive, action: model.confirmRemoval)
      Button(L10n.string("Cancel"), role: .cancel) {}
    } message: {
      Text(
        verbatim: L10n.string(
          "The profile entry is removed. Its Codex home and authentication data stay on disk."
        )
      )
    }
    .task { model.start() }
  }
}

private struct EmptyProfilesView: View {
  let onAdd: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(L10n.string("No Profiles"), systemImage: "person.crop.rectangle.stack")
    } description: {
      Text(verbatim: L10n.string("Add a Codex profile to get started."))
    } actions: {
      Button(L10n.string("Add Profile"), action: onAdd)
        .opmProminentButtonStyle()
        .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
