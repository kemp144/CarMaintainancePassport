import SwiftUI

// MARK: - Reusable Premium Components

struct PremiumTeaserCard: View {
    let title: String
    let message: String
    let icon: String
    var accent: Color = AppTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard(tier: .secondary, padding: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 32, height: 32)
                        .background(accent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PreviewRevealCard<Content: View>: View {
    let title: String
    let message: String
    var footnote: String?
    @ViewBuilder let content: Content
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        SurfaceCard(tier: .primary, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                content
                    .blur(radius: 0) // Could be blurred if not revealed

                if let footnote {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Text(footnote)
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }
        }
    }
}

struct RefinedLockedInsightCard: View {
    let title: String
    let message: String
    let highlights: [String]
    let ctaTitle: String
    var accent: Color = AppTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard(tier: .primary, padding: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(12)
                            .background(Circle().fill(accent.opacity(0.14)))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(highlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(accent.opacity(0.8))

                                Text(highlight)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Text(ctaTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(accent)

                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(accent)
                    }
                    .padding(.top, 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accent.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct UpgradePillRow: View {
    let message: String
    let cta: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(cta)
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surfaceSecondary.opacity(0.6))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.separator, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paywall Trigger Helper

struct ContextualPaywallTrigger {
    @MainActor
    static func trackAndPresent(
        reason: PaywallReason,
        coordinator: PaywallCoordinator,
        vehicle: Vehicle? = nil,
        contextExtra: (inout PaywallPresentationContext) -> Void = { _ in }
    ) {
        var context = PaywallPresentationContext()
        
        if let vehicle = vehicle {
            context.totalOwnershipSpend = vehicle.totalSpent
            context.currencyCode = vehicle.currencyCode
            context.maintenanceHistoryCount = vehicle.serviceEntries.count
            context.validFuelCycleCount = FuelAnalyticsService.analysis(for: vehicle.fuelEntries).insights.validCycleCount
            // context.buyerReadyScore = vehicle.resaleReadinessScore // Assuming this exists or calculated
        }
        
        contextExtra(&context)
        
        AnalyticsService.shared.track(event: .paywall_viewed, properties: [
            "reason": reason.rawValue,
            "totalSpend": context.totalOwnershipSpend as Any,
            "historyCount": context.maintenanceHistoryCount as Any,
            "fuelCycles": context.validFuelCycleCount as Any,
            "resaleScore": context.buyerReadyScore as Any
        ])
        
        coordinator.present(reason, context: context)
    }
}
