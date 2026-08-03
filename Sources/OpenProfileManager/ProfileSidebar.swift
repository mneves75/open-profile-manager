import ProfileCore
import SwiftUI

struct ProfileSidebar: View {
  let profiles: [Profile]
  let statuses: [ProfileID: ProfileStatus]
  @Binding var selection: ProfileID?

  var body: some View {
    List(profiles, id: \.id, selection: $selection) { profile in
      ProfileRow(
        displayName: profile.displayName,
        profileID: profile.id.rawValue,
        status: statuses[profile.id]
      )
      .tag(profile.id)
    }
    .navigationTitle(L10n.string("Profiles"))
    .accessibilityLabel(L10n.string("Codex profiles"))
  }
}

private struct ProfileRow: View {
  let displayName: String
  let profileID: String
  let status: ProfileStatus?

  var body: some View {
    HStack(spacing: 10) {
      StatusIndicator(state: status?.state)
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: displayName)
          .font(.headline)
          .lineLimit(1)
        HStack(spacing: 6) {
          Text(verbatim: profileID)
          if let planType = status?.account?.planType {
            Text(verbatim: "•")
            Text(verbatim: planType)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      Spacer(minLength: 4)
      if let usedPercent = status?.rateLimits?.primary?.usedPercent {
        Text(verbatim: "\(usedPercent)%")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct StatusIndicator: View {
  let state: ProfileStatusState?

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 9, height: 9)
      .accessibilityLabel(label)
  }

  private var color: Color {
    switch state {
    case .available: .green
    case .notAuthenticated: .orange
    case .unavailable: .red
    case nil: .secondary
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
