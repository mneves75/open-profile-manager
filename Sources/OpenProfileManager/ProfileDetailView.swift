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
      VStack(alignment: .leading, spacing: 18) {
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
      .frame(maxWidth: 820, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(AppVisualStyle.canvas)
    .navigationTitle(profile.displayName)
  }
}

private struct ProfileHeader: View {
  let displayName: String
  let profileID: String
  let status: ProfileStatus?

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      Image(systemName: "person.crop.rectangle.stack.fill")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(.tint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 7) {
        Text(verbatim: displayName)
          .font(.largeTitle.weight(.bold))
          .lineLimit(2)
        Text(verbatim: profileID)
          .font(.callout.monospaced().weight(.medium))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      Spacer(minLength: 12)
      StatusBadge(state: status?.state)
    }
    .padding(22)
    .editorialCard()
  }
}

private struct ProfileActions: View {
  let onLaunch: () -> Void
  let onInstallLauncher: () -> Void
  let onCopyCLI: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) { buttons }
      VStack(spacing: 10) { buttons }
    }
  }

  @ViewBuilder
  private var buttons: some View {
    Button(
      L10n.string("Launch Desktop App"),
      systemImage: "arrow.up.forward.app.fill",
      action: onLaunch
    )
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .accessibilityLabel(L10n.string("Launch Desktop App"))
    Button(
      L10n.string("Install Finder Launcher"),
      systemImage: "macwindow.badge.plus",
      action: onInstallLauncher
    )
    .buttonStyle(.bordered)
    .controlSize(.large)
    .accessibilityLabel(L10n.string("Install Finder Launcher"))
    Button(L10n.string("Copy CLI Command"), systemImage: "terminal", action: onCopyCLI)
      .buttonStyle(.bordered)
      .controlSize(.large)
      .accessibilityLabel(L10n.string("Copy CLI Command"))
  }
}

private struct QuotaCard: View {
  let status: ProfileStatus?
  let isRefreshing: Bool

  var body: some View {
    DetailCard(
      title: L10n.string("Account Status"),
      systemImage: "gauge.with.dots.needle.67percent"
    ) {
      VStack(alignment: .leading, spacing: 18) {
        if isRefreshing, status == nil {
          ProgressView(L10n.string("Reading Codex status…"))
            .controlSize(.small)
        } else if let status {
          if let primary = status.rateLimits?.primary {
            QuotaWindowView(title: L10n.string("Primary Window"), window: primary)
          }
          if let secondary = status.rateLimits?.secondary {
            Divider()
            QuotaWindowView(title: L10n.string("Secondary Window"), window: secondary)
          }
          if status.rateLimits == nil {
            StatusMessage(state: status.state)
              .foregroundStyle(.secondary)
          }
        } else {
          Text(verbatim: L10n.string("Status has not been read yet."))
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct StatusMessage: View {
  let state: ProfileStatusState

  var body: some View {
    switch state {
    case .available:
      Text(verbatim: L10n.string("No quota data is available for this profile."))
    case .notAuthenticated:
      Text(verbatim: L10n.string("Sign in to this profile with the Codex CLI, then refresh."))
    case .unavailable:
      Text(verbatim: L10n.string("Codex status is unavailable. Run opm doctor for details."))
    }
  }
}

private struct QuotaWindowView: View {
  let title: String
  let window: RateLimitWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(verbatim: title)
          .font(.headline)
        Spacer()
        Text(verbatim: L10n.string("%lld%% used", window.usedPercent))
          .font(.title3.monospacedDigit().weight(.semibold))
      }
      ProgressView(value: Double(window.usedPercent), total: 100)
        .progressViewStyle(.linear)
        .accessibilityLabel(title)
        .accessibilityValue(L10n.string("%lld percent used", window.usedPercent))
      if let resetsAt = window.resetsAt {
        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        TimelineView(.periodic(from: .now, by: 60)) { _ in
          Text(
            verbatim: L10n.string(
              "Resets %@",
              resetDate.formatted(.relative(presentation: .named).locale(L10n.locale))
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct ProfilePaths: View {
  let codexHome: String
  let guiDataDirectory: String?

  var body: some View {
    DetailCard(title: L10n.string("Local Isolation"), systemImage: "lock.shield.fill") {
      VStack(alignment: .leading, spacing: 16) {
        PathRow(label: "CODEX_HOME", path: codexHome)
        Divider()
        PathRow(
          label: L10n.string("Desktop data"),
          path: guiDataDirectory ?? L10n.string("Managed automatically for this profile")
        )
      }
    }
  }
}

private struct PathRow: View {
  let label: String
  let path: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(verbatim: label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(verbatim: path)
        .font(.callout.monospaced())
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct ProfileManagement: View {
  let onEdit: () -> Void
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(L10n.string("Edit Profile"), systemImage: "pencil", action: onEdit)
        .accessibilityLabel(L10n.string("Edit Profile"))
      Spacer()
      Button(
        L10n.string("Remove Profile"),
        systemImage: "trash",
        role: .destructive,
        action: onRemove
      )
      .accessibilityLabel(L10n.string("Remove Profile"))
    }
    .padding(.horizontal, 4)
  }
}

private struct DetailCard<Content: View>: View {
  let title: String
  let systemImage: String
  let content: Content

  init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .foregroundStyle(.secondary)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .editorialCard()
  }
}

private struct StatusBadge: View {
  let state: ProfileStatusState?

  var body: some View {
    Label(label, systemImage: symbol)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(color.opacity(0.14), in: Capsule())
      .foregroundStyle(color)
      .accessibilityLabel(label)
  }

  private var label: String {
    switch state {
    case .available: L10n.string("Available")
    case .notAuthenticated: L10n.string("Sign-in required")
    case .unavailable: L10n.string("Unavailable")
    case nil: L10n.string("Checking…")
    }
  }

  private var symbol: String {
    switch state {
    case .available: "checkmark.circle.fill"
    case .notAuthenticated: "person.crop.circle.badge.exclamationmark"
    case .unavailable: "exclamationmark.triangle.fill"
    case nil: "clock"
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

extension View {
  fileprivate func editorialCard() -> some View {
    self.background(
      AppVisualStyle.sidebar,
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(AppVisualStyle.hairline, lineWidth: 1)
    }
  }
}
