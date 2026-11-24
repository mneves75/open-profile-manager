import ProfileCore
import SwiftUI

struct ProfileSidebar: View {
  let profiles: [Profile]
  let statuses: [ProfileID: ProfileStatus]
  @Binding var selection: ProfileID?
  let onLaunch: (Profile) -> Void
  let onCopyCLI: (Profile) -> Void
  let onEdit: (Profile) -> Void
  let onInstallLauncher: (Profile) -> Void
  let onRemove: (Profile) -> Void

  var body: some View {
    List(profiles, id: \.id, selection: $selection) { profile in
      ProfileRow(
        displayName: profile.displayName,
        profileID: profile.id.rawValue,
        status: statuses[profile.id]
      )
      .tag(profile.id)
      .contextMenu {
        Button(L10n.string("Launch Desktop App"), systemImage: "arrow.up.forward.app") {
          onLaunch(profile)
        }
        Button(L10n.string("Copy CLI Command"), systemImage: "terminal") {
          onCopyCLI(profile)
        }
        Divider()
        Button(L10n.string("Edit Profile"), systemImage: "pencil") {
          onEdit(profile)
        }
        Button(L10n.string("Install Finder Launcher"), systemImage: "macwindow.badge.plus") {
          onInstallLauncher(profile)
        }
        Divider()
        Button(L10n.string("Remove Profile"), systemImage: "trash", role: .destructive) {
          onRemove(profile)
        }
      }
    }
    .listStyle(.sidebar)
    .accessibilityLabel(L10n.string("Codex profiles"))
    .navigationTitle(L10n.string("Profiles"))
  }
}

private struct ProfileRow: View {
  let displayName: String
  let profileID: String
  let status: ProfileStatus?

  var body: some View {
    HStack(spacing: 10) {
      StatusDot(state: status?.state)

      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: displayName)
          .font(.body.weight(.medium))
          .lineLimit(1)
        HStack(spacing: 4) {
          Text(verbatim: profileID)
          if let planType = formattedPlanType {
            Text(verbatim: "·")
            Text(verbatim: planType)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer(minLength: 6)

      if let usedPercent = status?.rateLimits?.primary?.usedPercent {
        Text(verbatim: "\(usedPercent)%")
          .font(.caption.monospacedDigit().weight(.medium))
          .foregroundStyle(QuotaTone.sidebarColor(for: usedPercent))
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }

  private var formattedPlanType: String? {
    guard let plan = status?.account?.planType, !plan.isEmpty else { return nil }
    return plan.prefix(1).uppercased() + plan.dropFirst()
  }
}

private struct StatusDot: View {
  let state: ProfileStatusState?

  var body: some View {
    color
      .frame(width: 8, height: 8)
      .clipShape(Circle())
      .accessibilityLabel(label)
  }

  private var color: Color {
    switch state {
    case .available: .green
    case .notAuthenticated: .orange
    case .unavailable: .red
    case nil: .secondary.opacity(0.5)
    }
  }

  private var label: String {
    switch state {
    case .available: L10n.string("Available")
    case .notAuthenticated: L10n.string("Not authenticated")
    case .unavailable: L10n.string("Unavailable")
    case nil: L10n.string("Status unknown")
    }
  }
}
