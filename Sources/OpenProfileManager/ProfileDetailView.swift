import ProfileCore
import SwiftUI

struct ProfileDetailView: View {
  let profile: Profile
  let status: ProfileStatus?
  let isRefreshing: Bool
  let onLaunch: () -> Void
  let onInstallLauncher: () -> Void
  let onCopyCLI: () -> Void
  let onEdit: () -> Void
  let onRemove: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ProfileHeader(
          displayName: profile.displayName,
          profileID: profile.id.rawValue,
          status: status
        )
        ProfileActions(
          onLaunch: onLaunch,
          onInstallLauncher: onInstallLauncher,
          onCopyCLI: onCopyCLI
        )
        QuotaCard(status: status, isRefreshing: isRefreshing)
        ProfilePaths(
          codexHome: profile.codexHome.path,
          guiDataDirectory: profile.guiDataDirectory?.path
        )
        ProfileManagement(onEdit: onEdit, onRemove: onRemove)
      }
      .padding(28)
      .frame(maxWidth: 760, alignment: .leading)
    }
    .navigationTitle(profile.displayName)
  }
}

private struct ProfileHeader: View {
  let displayName: String
  let profileID: String
  let status: ProfileStatus?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(displayName)
        .font(.largeTitle.bold())
      HStack(spacing: 8) {
        Text(profileID)
          .font(.body.monospaced())
          .foregroundStyle(.secondary)
        StatusBadge(state: status?.state)
      }
      if let email = status?.account?.email {
        Label(email, systemImage: "at")
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }
}

private struct ProfileActions: View {
  let onLaunch: () -> Void
  let onInstallLauncher: () -> Void
  let onCopyCLI: () -> Void

  var body: some View {
    ViewThatFits {
      HStack(spacing: 10) { buttons }
      VStack(alignment: .leading, spacing: 10) { buttons }
    }
  }

  @ViewBuilder
  private var buttons: some View {
    Button("Launch Desktop App", systemImage: "arrow.up.forward.app", action: onLaunch)
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .accessibilityLabel("Launch Desktop App")
    Button(
      "Install Finder Launcher", systemImage: "macwindow.badge.plus", action: onInstallLauncher
    )
    .controlSize(.large)
    .accessibilityLabel("Install Finder Launcher")
    Button("Copy CLI Command", systemImage: "terminal", action: onCopyCLI)
      .controlSize(.large)
      .accessibilityLabel("Copy CLI Command")
  }
}

private struct QuotaCard: View {
  let status: ProfileStatus?
  let isRefreshing: Bool

  var body: some View {
    GroupBox("Account Status") {
      VStack(alignment: .leading, spacing: 14) {
        if isRefreshing, status == nil {
          ProgressView("Reading Codex status…")
        } else if let status {
          if let primary = status.rateLimits?.primary {
            QuotaWindowView(title: "Primary Window", window: primary)
          }
          if let secondary = status.rateLimits?.secondary {
            Divider()
            QuotaWindowView(title: "Secondary Window", window: secondary)
          }
          if status.rateLimits == nil {
            StatusMessage(state: status.state)
              .foregroundStyle(.secondary)
          }
        } else {
          Text("Status has not been read yet.")
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
    }
  }
}

private struct StatusMessage: View {
  let state: ProfileStatusState

  var body: some View {
    switch state {
    case .available:
      Text("No quota data is available for this profile.")
    case .notAuthenticated:
      Text("Sign in to this profile with the Codex CLI, then refresh.")
    case .unavailable:
      Text("Codex status is unavailable. Run opm doctor for details.")
    }
  }
}

private struct QuotaWindowView: View {
  let title: LocalizedStringResource
  let window: RateLimitWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        Text("\(window.usedPercent)% used")
          .font(.body.monospacedDigit())
      }
      ProgressView(value: Double(window.usedPercent), total: 100)
        .accessibilityLabel(title)
        .accessibilityValue("\(window.usedPercent) percent used")
      if let resetsAt = window.resetsAt {
        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        Text("Resets \(resetDate, style: .relative)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ProfilePaths: View {
  let codexHome: String
  let guiDataDirectory: String?

  var body: some View {
    GroupBox("Local Isolation") {
      VStack(alignment: .leading, spacing: 14) {
        PathRow(label: "CODEX_HOME", path: codexHome)
        PathRow(
          label: "Desktop data",
          path: guiDataDirectory ?? "Managed automatically for this profile"
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
    }
  }
}

private struct PathRow: View {
  let label: LocalizedStringResource
  let path: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(path)
        .font(.body.monospaced())
        .textSelection(.enabled)
    }
  }
}

private struct ProfileManagement: View {
  let onEdit: () -> Void
  let onRemove: () -> Void

  var body: some View {
    HStack {
      Button("Edit Profile", systemImage: "pencil", action: onEdit)
        .accessibilityLabel("Edit Profile")
      Spacer()
      Button("Remove Profile", systemImage: "trash", role: .destructive, action: onRemove)
        .accessibilityLabel("Remove Profile")
    }
  }
}

private struct StatusBadge: View {
  let state: ProfileStatusState?

  var body: some View {
    Text(label)
      .font(.caption.weight(.medium))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.14), in: Capsule())
      .foregroundStyle(color)
  }

  private var label: LocalizedStringResource {
    switch state {
    case .available: "Available"
    case .notAuthenticated: "Sign-in required"
    case .unavailable: "Unavailable"
    case nil: "Checking…"
    }
  }

  private var color: Color {
    switch state {
    case .available: .green
    case .notAuthenticated: .orange
    case .unavailable: .red
    case nil: .secondary
    }
  }
}
