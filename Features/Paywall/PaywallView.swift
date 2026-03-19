import StoreKit
import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore

    @State private var selectedPlan: EntitlementStore.ProPlan = .yearly
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: PaywallScrollOffsetKey.self,
                                    value: proxy.frame(in: .named("paywallScroll")).minY
                                )
                        }
                        .frame(height: 0)

                        heroSection
                        pricingSection
                        benefitsSection
                        comparisonSection
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "paywallScroll")
                .onPreferenceChange(PaywallScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsStickyCTA {
                        stickyCTA
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.018))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(AppTheme.separator.opacity(0.6), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var heroSection: some View {
        PremiumBackdrop()
            .frame(height: 224)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )

                        Text("Pro Upgrade")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )

                        Spacer()
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Unlock Pro")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("Keep every car organized with smarter reminders, detailed fuel tracking, documents, and export tools.")
                            .font(.body)
                            .foregroundStyle(Color.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("No ads. Choose monthly, yearly, or lifetime when it fits.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
    }

    private var pricingSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                PremiumSectionHeader(
                    title: "Choose your plan",
                    subtitle: "Yearly is the best balance of value and flexibility."
                )

                VStack(spacing: 10) {
                    ForEach(EntitlementStore.ProPlan.allCases, id: \.rawValue) { plan in
                        pricingPlanRow(for: plan)
                    }
                }

                Button {
                    Task {
                        await entitlementStore.purchase(plan: selectedPlan)
                        if entitlementStore.hasProAccess {
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if entitlementStore.isBusy {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(selectedPlan.ctaTitle(priceText: planPriceText(for: selectedPlan)))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(entitlementStore.isBusy)

                if let message = entitlementStore.purchaseErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                }
            }
        }
    }

    private var benefitsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Why Pro")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(spacing: 10) {
                    benefitRow(
                        icon: "car.2.fill",
                        title: "Unlimited vehicles",
                        message: "Track your whole garage, not just one car."
                    )

                    benefitRow(
                        icon: "bell.badge.fill",
                        title: "Smart reminders",
                        message: "Get reminders by date, mileage, or both."
                    )

                    benefitRow(
                        icon: "fuelpump.fill",
                        title: "Detailed fuel tracking",
                        message: "Unlock consumption, charts, filters, and deeper fuel insights."
                    )

                    benefitRow(
                        icon: "doc.richtext.fill",
                        title: "Documents and resale exports",
                        message: "Keep receipts organized and export buyer-ready history when it matters."
                    )
                }
            }
        }
    }

    private var comparisonSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free vs Pro")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Choose the plan that fits your garage.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                // Column headers
                HStack(spacing: 0) {
                    Spacer()
                    Text("Free")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: comparisonColWidth, alignment: .center)
                    Spacer().frame(width: comparisonColGap)
                    Text("Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: comparisonColWidth, alignment: .center)
                }

                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(Array(comparisonFeatures.enumerated()), id: \.element.id) { index, feature in
                        comparisonTableRow(feature, isLast: index == comparisonFeatures.count - 1)
                    }
                }
            }
        }
    }

    private func comparisonTableRow(_ feature: ComparisonFeature, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            Text(feature.title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            comparisonCell(text: feature.free, isFree: true)
                .frame(width: comparisonColWidth)

            Spacer().frame(width: comparisonColGap)

            comparisonCell(text: feature.pro, isFree: false)
                .frame(width: comparisonColWidth)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppTheme.separator.opacity(0.6))
                    .frame(height: 0.5)
            }
        }
    }

    private func comparisonCell(text: String, isFree: Bool) -> some View {
        let absent = text == "Not included"
        let displayText = absent ? "Not included" : text
        let textColor: Color = absent
            ? Color(hex: "475569")
            : (isFree ? Color(hex: "94A3B8") : AppTheme.accent)

        return Text(displayText)
            .font(.caption.weight(.medium))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(absent ? 0.02 : 0.04))
            )
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await entitlementStore.restorePurchases()
                    if entitlementStore.hasProAccess {
                        dismiss()
                    }
                }
            } label: {
                Text("Restore Purchases")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 16) {
                Button {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                } label: {
                    Text("Terms")
                }

                Button {
                    if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                        openURL(url)
                    }
                } label: {
                    Text("Privacy Policy")
                }
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Task {
                        await entitlementStore.purchase(plan: selectedPlan)
                        if entitlementStore.hasProAccess {
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if entitlementStore.isBusy {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(selectedPlan.ctaTitle(priceText: planPriceText(for: selectedPlan)))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(entitlementStore.isBusy)

                if selectedPlan == .yearly {
                    Text("Save €11.89/year")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.accent.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .background(
                AppTheme.background.opacity(0.98)
                    .overlay(
                        Rectangle()
                            .strokeBorder(AppTheme.separator.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func pricingPlanRow(for plan: EntitlementStore.ProPlan) -> some View {
        let isSelected = selectedPlan == plan
        let isYearly = plan == .yearly

        return Button {
            withAnimation(.smooth(duration: 0.22)) {
                selectedPlan = plan
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let badge = plan.badge {
                        badgeView(badge, highlighted: isYearly || plan == .lifetime)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if isYearly {
                            Text(plan.savingsText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(planPriceText(for: plan))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(plan.billingNote)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 104, alignment: .trailing)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.045) : Color.white.opacity(0.02))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? AppTheme.accent.opacity(0.85) : AppTheme.separator, lineWidth: isSelected ? 1.5 : 1)
                    }
            )
        }
        .buttonStyle(.plain)
    }

    private func benefitRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accentSecondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }
        )
    }

    private func badgeView(_ title: String, highlighted: Bool) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(highlighted ? AppTheme.accentSecondary : AppTheme.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(highlighted ? AppTheme.accent.opacity(0.12) : Color.white.opacity(0.03))
            )
    }

    private func planPriceText(for plan: EntitlementStore.ProPlan) -> String {
        entitlementStore.product(for: plan)?.displayPrice ?? plan.fallbackPrice
    }

    private var showsStickyCTA: Bool {
        scrollOffset < -340
    }

    private var comparisonColWidth: CGFloat { 96 }
    private var comparisonColGap: CGFloat { 10 }

    private var comparisonFeatures: [ComparisonFeature] {
        [
            ComparisonFeature(title: "Vehicles", free: "1 vehicle", pro: "Unlimited", highlightPro: true),
            ComparisonFeature(title: "Service logging", free: "Included", pro: "Included", highlightPro: false),
            ComparisonFeature(title: "Reminders", free: "By date", pro: "Date + mileage", highlightPro: true),
            ComparisonFeature(title: "Fuel history", free: "Logs + totals", pro: "Logs + totals", highlightPro: false),
            ComparisonFeature(title: "Fuel analytics", free: "Not included", pro: "Detailed tracking", highlightPro: true),
            ComparisonFeature(title: "OCR receipts", free: "Not included", pro: "Included", highlightPro: true),
            ComparisonFeature(title: "Documents", free: "Up to 10 saved", pro: "Unlimited", highlightPro: true),
            ComparisonFeature(title: "Backup & restore", free: "Included", pro: "Included", highlightPro: false),
            ComparisonFeature(title: "Premium reports", free: "Not included", pro: "PDF + CSV + resale", highlightPro: true),
            ComparisonFeature(title: "Insights", free: "Basic totals", pro: "Cost insights", highlightPro: true)
        ]
    }
}

private struct PaywallScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ComparisonFeature: Identifiable {
    let id = UUID()
    let title: String
    let free: String
    let pro: String
    let highlightPro: Bool
}


private extension EntitlementStore.ProPlan {
    var title: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly:
            return "Flexible monthly access"
        case .yearly:
            return "Best balance of value and flexibility"
        case .lifetime:
            return "One purchase, forever access"
        }
    }

    var badge: String? {
        switch self {
        case .monthly:
            return "Flexible"
        case .yearly:
            return "Best Value"
        case .lifetime:
            return "Pay once"
        }
    }

    var billingNote: String {
        switch self {
        case .monthly:
            return "Billed monthly"
        case .yearly:
            return "Billed yearly"
        case .lifetime:
            return "One-time purchase"
        }
    }

    var savingsText: String {
        "Save €11.89/year"
    }

    var fallbackPrice: String {
        switch self {
        case .monthly:
            return "€1.99"
        case .yearly:
            return "€11.99"
        case .lifetime:
            return "€29.99"
        }
    }

    func ctaTitle(priceText: String) -> String {
        switch self {
        case .monthly:
            return "Start Pro for \(priceText)/month"
        case .yearly:
            return "Start Pro for \(priceText)/year"
        case .lifetime:
            return "Unlock Pro forever for \(priceText)"
        }
    }
}
