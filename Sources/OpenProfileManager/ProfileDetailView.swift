import ProfileCore
import SwiftUI

struct ProfileDetailView: View {
  let profile: Profile
  let status: ProfileStatus?
  let isRefreshing: Bool
  let copiedCommand: CopiedCommand?
  let onLaunch: () -> Void
  let onCopyCLI: () -> Void
  let onCopyLogin: () -> Void
  let onCopyDoctor: () -> Void
  let onRefresh: () -> Void
  let onEdit: () -> Void
  let onInstallLauncher: () -> Void
  let onShowDetails: () -> Void
  let onRemove: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        ProfileHero(
          displayName: profile.displayName,
          profileID: profile.id.rawValue,
          status: status
        )

        ProfileActionBar(
          isCLICopied: copiedCommand == .cli(profile.id),
          onLaunch: onLaunch,
          onCopyCLI: onCopyCLI,
          onEdit: onEdit,
          onInstallLauncher: onInstallLauncher,
          onShowDetails: onShowDetails,
          onRemove: onRemove
        )

        QuotaSection(
          profileID: profile.id,
          status: status,
          isRefreshing: isRefreshing,
          copiedCommand: copiedCommand,
          onCopyLogin: onCopyLogin,
          onCopyDoctor: onCopyDoctor,
          onRefresh: onRefresh
        )
      }
      .padding(.horizontal, 40)
      .padding(.vertical, 36)
      .frame(maxWidth: 680, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .navigationTitle(profile.displayName)
  }
}

struct ProfileInspectorView: View {
  let profile: Profile
  let onRevealCodexHome: () -> Void
  let onInstallLauncher: () -> Void
  let onEdit: () -> Void
  let onRemove: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 14) {
          Text(verbatim: L10n.string("Storage"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(verbatim: "CODEX_HOME")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
              Spacer()
              Button(
                L10n.string("Reveal in Finder"),
                systemImage: "folder",
                action: onRevealCodexHome
              )
              .labelStyle(.iconOnly)
              .buttonStyle(.borderless)
              .help(L10n.string("Reveal in Finder"))
            }
            Text(verbatim: profile.codexHome.path)
              .font(.callout.monospaced())
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          }

          Divider()

          VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: L10n.string("Desktop data"))
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
            Text(verbatim: profile.guiDataDirectory?.path ?? L10n.string("Automatic"))
              .font(profile.guiDataDirectory == nil ? .callout : .callout.monospaced())
              .foregroundStyle(profile.guiDataDirectory == nil ? .secondary : .primary)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Divider()

        VStack(alignment: .leading, spacing: 10) {
          Text(verbatim: L10n.string("Manage"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

          Button(action: onInstallLauncher) {
            Label(L10n.string("Install Finder Launcher"), systemImage: "macwindow.badge.plus")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.primary)

          Button(action: onEdit) {
            Label(L10n.string("Edit Profile"), systemImage: "pencil")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.primary)

          Button(role: .destructive, action: onRemove) {
            Label(L10n.string("Remove Profile"), systemImage: "trash")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.red)
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .navigationTitle(L10n.string("Details"))
  }
}

private struct ProfileHero: View {
  let displayName: String
  let profileID: String
  let status: ProfileStatus?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(verbatim: displayName)
        .font(.system(size: 32, weight: .bold))
        .lineLimit(2)

      HStack(spacing: 10) {
        Text(verbatim: profileID)
          .font(.callout.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)

        Text(verbatim: "·")
          .foregroundStyle(.tertiary)

        StatusPill(state: status?.state)

        if let plan = ProfileStatusPresentation.formattedPlanType(for: status) {
          Text(verbatim: "·")
            .foregroundStyle(.tertiary)
          Text(verbatim: plan)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct ProfileActionBar: View {
  let isCLICopied: Bool
  let onLaunch: () -> Void
  let onCopyCLI: () -> Void
  let onEdit: () -> Void
  let onInstallLauncher: () -> Void
  let onShowDetails: () -> Void
  let onRemove: () -> Void

  var body: some View {
    GlassActionGroup(spacing: 12) {
      Button(L10n.string("Launch"), systemImage: "arrow.up.forward.app.fill", action: onLaunch)
        .opmProminentButtonStyle()
        .controlSize(.large)

      Button(action: onCopyCLI) {
        Label(
          isCLICopied ? L10n.string("Copied") : L10n.string("Copy CLI"),
          systemImage: isCLICopied ? "checkmark" : "terminal"
        )
        .contentTransition(.symbolEffect(.replace))
      }
      .opmSecondaryButtonStyle()
      .controlSize(.large)

      Menu {
        Button(L10n.string("Edit Profile"), systemImage: "pencil", action: onEdit)
        Button(
          L10n.string("Install Finder Launcher"),
          systemImage: "macwindow.badge.plus",
          action: onInstallLauncher
        )
        Button(L10n.string("Show Details"), systemImage: "sidebar.right", action: onShowDetails)
        Divider()
        Button(
          L10n.string("Remove Profile"),
          systemImage: "trash",
          role: .destructive,
          action: onRemove
        )
      } label: {
        Image(systemName: "ellipsis")
          .frame(minWidth: 16, minHeight: 16)
      }
      .opmSecondaryButtonStyle()
      .controlSize(.large)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel(L10n.string("More actions"))
    }
  }
}

private struct QuotaSection: View {
  let profileID: ProfileID
  let status: ProfileStatus?
  let isRefreshing: Bool
  let copiedCommand: CopiedCommand?
  let onCopyLogin: () -> Void
  let onCopyDoctor: () -> Void
  let onRefresh: () -> Void

  var body: some View {
    if isRefreshing, status == nil {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)
        Text(verbatim: L10n.string("Checking…"))
          .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .opmSubtleSurface()
    } else if let status {
      let primary = status.rateLimits?.primary
      let secondary = status.rateLimits?.secondary
      if primary != nil || secondary != nil {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 16) {
            quotaCards(primary: primary, secondary: secondary)
          }
          VStack(spacing: 16) {
            quotaCards(primary: primary, secondary: secondary)
          }
        }
      } else {
        StatusNotice(
          profileID: profileID,
          state: status.state,
          copiedCommand: copiedCommand,
          onCopyLogin: onCopyLogin,
          onCopyDoctor: onCopyDoctor
        )
      }
    } else {
      HStack {
        Text(verbatim: L10n.string("Not checked yet"))
          .foregroundStyle(.secondary)
        Spacer()
        Button(L10n.string("Refresh"), action: onRefresh)
          .opmSecondaryButtonStyle()
      }
      .padding(20)
      .opmSubtleSurface()
    }
  }

  @ViewBuilder
  private func quotaCards(primary: RateLimitWindow?, secondary: RateLimitWindow?) -> some View {
    if let primary {
      QuotaMetricCard(
        title: windowTitle(for: primary, fallback: L10n.string("Primary Window")),
        window: primary
      )
    }
    if let secondary {
      QuotaMetricCard(
        title: windowTitle(for: secondary, fallback: L10n.string("Secondary Window")),
        window: secondary
      )
    }
  }

  private static let fiveHourWindowMinutes: Int64 = 300
  private static let weeklyWindowMinutes: Int64 = 10_080

  private func windowTitle(for window: RateLimitWindow, fallback: String) -> String {
    switch window.windowDurationMinutes {
    case Self.fiveHourWindowMinutes: L10n.string("5-Hour Window")
    case Self.weeklyWindowMinutes: L10n.string("Weekly Window")
    default: fallback
    }
  }
}

private struct QuotaMetricCard: View {
  let title: String
  let window: RateLimitWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(verbatim: title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(verbatim: "\(window.usedPercent)%")
          .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
        Text(verbatim: L10n.string("used"))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      QuotaBar(usedPercent: window.usedPercent)
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
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .opmSubtleSurface()
  }
}

private struct StatusNotice: View {
  let profileID: ProfileID
  let state: ProfileStatusState
  let copiedCommand: CopiedCommand?
  let onCopyLogin: () -> Void
  let onCopyDoctor: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      switch state {
      case .available:
        Label(L10n.string("Ready"), systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.callout.weight(.medium))
      case .notAuthenticated:
        Label(
          L10n.string("Authenticate with Codex CLI"),
          systemImage: "person.crop.circle.badge.exclamationmark"
        )
        .foregroundStyle(.orange)
        .font(.callout.weight(.medium))
        Spacer()
        Button(action: onCopyLogin) {
          Label(
            copiedCommand == .login(profileID)
              ? L10n.string("Copied")
              : L10n.string("Copy Login Command"),
            systemImage: copiedCommand == .login(profileID) ? "checkmark" : "terminal"
          )
        }
        .opmSecondaryButtonStyle()
      case .unavailable:
        Label(L10n.string("Status unavailable"), systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
          .font(.callout.weight(.medium))
        Spacer()
        Button(action: onCopyDoctor) {
          Label(
            copiedCommand == .doctor(profileID)
              ? L10n.string("Copied")
              : L10n.string("Copy Doctor Command"),
            systemImage: copiedCommand == .doctor(profileID) ? "checkmark" : "stethoscope"
          )
        }
        .opmSecondaryButtonStyle()
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .opmSubtleSurface()
  }
}

private struct StatusPill: View {
  let state: ProfileStatusState?

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(verbatim: label)
        .font(.callout)
        .foregroundStyle(color)
    }
  }

  private var label: String {
    switch state {
    case .available: L10n.string("Available")
    case .notAuthenticated: L10n.string("Sign-in required")
    case .unavailable: L10n.string("Unavailable")
    case nil: L10n.string("Checking…")
    }
  }

  private var color: Color {
    ProfileStatusPresentation.color(for: state)
  }
}

private struct QuotaBar: View {
  let usedPercent: Int

  var body: some View {
    GeometryReader { proxy in
      let fraction = min(max(Double(usedPercent) / 100.0, 0), 1)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.quaternary)
        Capsule()
          .fill(QuotaTone.color(for: usedPercent))
          .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * fraction))
      }
    }
    .frame(height: 6)
    .accessibilityElement(children: .ignore)
  }
}
