import ProfileCore
import SwiftUI

struct ProfileSidebar: View {
  let profiles: [Profile]
  let statuses: [ProfileID: ProfileStatus]
  @Binding var selection: ProfileID?

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [AppVisualStyle.sidebar.opacity(0.98), AppVisualStyle.canvas],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      List(profiles, id: \.id, selection: $selection) { profile in
        ProfileRow(
          displayName: profile.displayName,
          profileID: profile.id.rawValue,
          status: statuses[profile.id]
        )
        .tag(profile.id)
        .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .listRowSeparator(.hidden)
      }
      .scrollContentBackground(.hidden)
      .listStyle(.plain)
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
    HStack(spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(.white.opacity(0.07))
          .frame(width: 38, height: 38)
          .overlay {
            Image(systemName: "terminal")
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(.primary.opacity(0.82))
          }
        StatusIndicator(state: status?.state)
          .offset(x: 2, y: 2)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: displayName)
          .font(.system(.body, design: .rounded, weight: .semibold))
          .lineLimit(1)
        HStack(spacing: 5) {
          Text(verbatim: profileID)
          if let planType = status?.account?.planType {
            Text(verbatim: "·")
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
          .font(.caption2.monospacedDigit().weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background(.white.opacity(0.055), in: Capsule())
      }
    }
    .padding(.vertical, 5)
    .contentShape(Rectangle())
  }
}

private struct StatusIndicator: View {
  let state: ProfileStatusState?

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 10, height: 10)
      .overlay { Circle().stroke(AppVisualStyle.sidebar, lineWidth: 2) }
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
