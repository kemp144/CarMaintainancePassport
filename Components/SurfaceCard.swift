import SwiftUI

enum CardTier {
    case primary
    case secondary
    case compact
}

struct SurfaceCard<Content: View>: View {
    var tier: CardTier = .secondary
    var padding: CGFloat? = nil
    @ViewBuilder var content: Content

    init(tier: CardTier = .secondary, padding: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.tier = tier
        self.padding = padding
        self.content = content()
    }

    /// Legacy convenience: `SurfaceCard(padding: 16) { ... }`
    init(padding: CGFloat, @ViewBuilder content: () -> Content) {
        self.tier = .secondary
        self.padding = padding
        self.content = content()
    }

    private var resolvedPadding: CGFloat {
        padding ?? {
            switch tier {
            case .primary: return AppTheme.Spacing.cardPaddingLarge
            case .secondary: return AppTheme.Spacing.cardPadding
            case .compact: return AppTheme.Spacing.cardPaddingCompact
            }
        }()
    }

    private var cornerRadius: CGFloat {
        tier == .compact ? AppTheme.Radius.cardCompact : AppTheme.Radius.card
    }

    private var bg: Color {
        tier == .compact ? AppTheme.surfaceSecondary : AppTheme.surface
    }

    private var showBorder: Bool {
        tier != .compact
    }

    private var internalSpacing: CGFloat {
        switch tier {
        case .primary: return 12
        case .secondary: return 10
        case .compact: return 6
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: internalSpacing) {
            content
        }
        .padding(resolvedPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(bg)
                .overlay {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppTheme.separator, lineWidth: 1)
                    }
                }
        )
    }
}

struct PremiumSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailingTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            if let trailingTitle, let action {
                Button(trailingTitle, action: action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var compact: Bool = false

    var body: some View {
        Text(title)
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.white : AppTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(minWidth: compact ? 52 : 0)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 7 : 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppTheme.surfaceSecondary : Color.clear)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(isSelected ? AppTheme.surfaceSecondary : AppTheme.separator, lineWidth: 1)
                    )
            )
    }
}

struct InlineSearchField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.tertiaryText)

            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(AppTheme.primaryText)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "020617")) // slate-950
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }
        )
    }
}

struct CompactHeaderCard: View {
    let title: String
    let message: String
    var accent: Color = AppTheme.accent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.heroGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(20)
        }
        .frame(height: 140)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.accent)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.separator, lineWidth: 1)
                    }
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

// MARK: - Floating Add Button

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.25), radius: 12, x: 0, y: 4)
                )
        }
        .padding(.trailing, AppTheme.Spacing.fabTrailing)
        .padding(.bottom, AppTheme.Spacing.fabBottom)
    }
}

// MARK: - Summary Stat Tile

struct SummaryStatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
