import ProfileCore
import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationSplitView {
      ProfileSidebar(
        profiles: model.profiles,
        statuses: model.statuses,
        selection: $model.selectedProfileID
      )
      .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 360)
    } detail: {
      if let profile = model.selectedProfile {
        ProfileDetailView(
          profile: profile,
          status: model.statuses[profile.id],
          isRefreshing: model.isRefreshing,
          onLaunch: { model.launchApp(for: profile) },
          onInstallLauncher: { model.installLauncher(for: profile) },
          onCopyCLI: { model.copyCLICommand(for: profile) },
          onEdit: { model.presentEditor(for: profile) },
          onRemove: { model.requestRemoval(of: profile) }
        )
      } else {
        EmptyProfilesView(onAdd: model.presentNewProfile)
      }
    }
    .toolbar {
      ToolbarItemGroup {
        Button("Add Profile", systemImage: "plus", action: model.presentNewProfile)
          .help("Add a Codex profile")
        Button("Refresh", systemImage: "arrow.clockwise") {
          Task { await model.reload() }
        }
        .disabled(model.isRefreshing)
        .help("Refresh account and quota status")
      }
    }
    .sheet(item: $model.editor) { configuration in
      ProfileEditorView(
        configuration: configuration,
        errorMessage: model.editorErrorMessage
      ) { id, name, home, guiDirectory in
        model.saveProfile(
          configuration: configuration,
          profileID: id,
          displayName: name,
          codexHome: home,
          guiDataDirectory: guiDirectory
        )
      }
    }
    .alert(model.alertTitle, isPresented: $model.isShowingAlert) {
      Button("OK", action: model.dismissAlert)
    } message: {
      Text(model.alertMessage)
    }
    .confirmationDialog(
      "Remove this profile?",
      isPresented: $model.isShowingRemoveConfirmation,
      titleVisibility: .visible
    ) {
      Button("Remove Profile", role: .destructive, action: model.confirmRemoval)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The profile entry is removed. Its Codex home and authentication data stay on disk.")
    }
    .task { model.start() }
  }
}

private struct EmptyProfilesView: View {
  let onAdd: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("No Profiles", systemImage: "person.crop.rectangle.stack")
    } description: {
      Text("Add a Codex home to launch the CLI or desktop app with an explicit account.")
    } actions: {
      Button("Add Profile", action: onAdd)
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Add Profile")
    }
  }
}
