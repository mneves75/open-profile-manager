import ProfileCore
import SwiftUI

enum ProfileStatusPresentation {
  static func color(for state: ProfileStatusState?) -> Color {
    switch state {
    case .available: .green
    case .notAuthenticated: .orange
    case .unavailable: .red
    case nil: .secondary
    }
  }

  static func formattedPlanType(for status: ProfileStatus?) -> String? {
    guard let plan = status?.account?.planType, !plan.isEmpty else { return nil }
    return plan.prefix(1).uppercased() + plan.dropFirst()
  }
}

enum QuotaTone {
  static func color(for usedPercent: Int) -> Color {
    switch usedPercent {
    case 90...: .red
    case 70..<90: .orange
    default: .accentColor
    }
  }
}

struct GlassActionGroup<Content: View>: View {
  let spacing: CGFloat
  let content: Content

  init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    if #available(macOS 26, *) {
      GlassEffectContainer(spacing: spacing) {
        HStack(spacing: spacing) {
          content
        }
      }
    } else {
      HStack(spacing: spacing) {
        content
      }
    }
  }
}

extension View {
  @ViewBuilder
  func opmProminentButtonStyle() -> some View {
    if #available(macOS 26, *) {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.borderedProminent)
    }
  }

  @ViewBuilder
  func opmSecondaryButtonStyle() -> some View {
    if #available(macOS 26, *) {
      self.buttonStyle(.glass)
    } else {
      self.buttonStyle(.bordered)
    }
  }

  func opmSubtleSurface(cornerRadius: CGFloat = 16) -> some View {
    self.background(
      .quaternary.opacity(0.45),
      in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
    }
  }
}
