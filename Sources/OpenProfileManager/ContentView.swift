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
      .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
    } detail: {
      ZStack {
        AppVisualStyle.canvas.ignoresSafeArea()
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
    }
    .toolbar {
      ToolbarItemGroup {
        Button(L10n.string("Add Profile"), systemImage: "plus", action: model.presentNewProfile)
          .help(L10n.string("Add a Codex profile"))
        Button(L10n.string("Refresh"), systemImage: "arrow.clockwise") {
          Task { await model.reload() }
        }
        .disabled(model.isRefreshing)
        .help(L10n.string("Refresh account and quota status"))
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
    .preferredColorScheme(.dark)
  }
}

private struct EmptyProfilesView: View {
  let onAdd: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(L10n.string("No Profiles"), systemImage: "person.crop.rectangle.stack")
    } description: {
      Text(
        verbatim: L10n.string(
          "Add a Codex home to launch the CLI or desktop app with an explicit account."
        )
      )
    } actions: {
      Button(L10n.string("Add Profile"), action: onAdd)
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(L10n.string("Add Profile"))
    }
  }
}
