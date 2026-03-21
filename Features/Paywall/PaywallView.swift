import StoreKit
import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator

    @State private var selectedPlan: EntitlementStore.ProPlan = .yearly
    @State private var scrollOffset: CGFloat = 0
    @State private var showingPrivacySheet = false

    private var paywallCopy: PaywallCopy {
        PaywallCopyBuilder.build(for: reason, context: paywallCoordinator.context)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
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
            .sheet(isPresented: $showingPrivacySheet) {
                PrivacyPolicyView()
            }
            .task {
                selectFirstAvailablePlanIfNeeded()
            }
            .onChange(of: entitlementStore.products.count) { _, _ in
                selectFirstAvailablePlanIfNeeded()
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    )

                Text("Pro")
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

            VStack(alignment: .leading, spacing: 8) {
                Text(paywallCopy.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(paywallCopy.message)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Text("No ads. No clutter. Choose monthly, yearly, or lifetime when it fits.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PremiumBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var pricingSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                PremiumSectionHeader(
                    title: "Choose your plan",
                    subtitle: "Yearly is the best balance of value and flexibility."
                )

                VStack(spacing: 10) {
                    if entitlementStore.isLoadingProducts && entitlementStore.products.isEmpty {
                        pricingStatusRow(
                            icon: "hourglass",
                            title: "Loading pricing",
                            message: "Fetching App Store product details."
                        )
                    } else if let message = entitlementStore.productLoadErrorMessage {
                        pricingStatusRow(
                            icon: "exclamationmark.triangle.fill",
                            title: message == "Some plans are temporarily unavailable." ? "Some plans unavailable" : "Pricing unavailable right now",
                            message: message,
                            actionTitle: "Try Again"
                        ) {
                            Task { await entitlementStore.loadProducts() }
                        }
                    }

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
                .disabled(entitlementStore.isBusy || entitlementStore.product(for: selectedPlan) == nil || entitlementStore.isLoadingProducts)

                if let message = entitlementStore.purchaseErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                }

                Text(subscriptionDisclosureText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var benefitsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What You Unlock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(spacing: 10) {
                    ForEach(paywallBenefits) { benefit in
                        benefitRow(
                            icon: benefit.icon,
                            title: benefit.title,
                            message: benefit.message
                        )
                    }
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
        .padding(.vertical, 10)
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
                    openURL(AppLegalLinks.termsOfUse)
                } label: {
                    Text("Terms of Use")
                }

                Button {
                    showingPrivacySheet = true
                } label: {
                    Text("Privacy Policy")
                }

                Button {
                    openURL(AppLegalLinks.support)
                } label: {
                    Text("Support")
                }
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
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
                    .disabled(entitlementStore.isBusy || entitlementStore.product(for: selectedPlan) == nil || entitlementStore.isLoadingProducts)

                    if selectedPlan == .yearly {
                        Text(yearlySavingsText)
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

                Text(subscriptionDisclosureText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
                    Text(entitlementStore.displayName(for: plan))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let badge = plan.badge {
                        badgeView(badge, highlighted: isYearly)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlementStore.displayDescription(for: plan) ?? plan.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        if isYearly {
                            Text(yearlySavingsText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(planPriceText(for: plan))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(plan.billingNote)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
        entitlementStore.displayPrice(for: plan) ?? plan.priceUnavailableText
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
            ComparisonFeature(title: "Fuel insights", free: "Basic averages", pro: "Long-term trends", highlightPro: true),
            ComparisonFeature(title: "Documents", free: "Up to 10 saved", pro: "Unlimited", highlightPro: true),
            ComparisonFeature(title: "Backup protection", free: "Local backup", pro: "Automatic iCloud Backup", highlightPro: true),
            ComparisonFeature(title: "Reports", free: "Not included", pro: "PDF + CSV + resale", highlightPro: true),
            ComparisonFeature(title: "Ownership insights", free: "Core summary", pro: "Deep breakdowns", highlightPro: true)
        ]
    }

    private var yearlySavingsText: String {
        PaywallPriceFormatter.localizedSavingsText(
            monthly: entitlementStore.product(for: .monthly),
            yearly: entitlementStore.product(for: .yearly)
        ) ?? "Save with yearly billing"
    }

    private var subscriptionDisclosureText: String {
        "Monthly and Yearly renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings. Lifetime is a one-time purchase."
    }

    @ViewBuilder
    private func pricingStatusRow(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accentSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
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

    private var paywallBenefits: [PaywallBenefit] {
        switch reason {
        case .financeBreakdown:
            return [
                PaywallBenefit(icon: "chart.pie.fill", title: "Category breakdowns", message: "See which costs actually drive ownership."),
                PaywallBenefit(icon: "chart.bar.xaxis", title: "Trend context", message: "Track how categories shift over time."),
                PaywallBenefit(icon: "magnifyingglass", title: "Smarter cost insight", message: "Spot the categories that quietly become expensive."),
                PaywallBenefit(icon: "doc.richtext.fill", title: "Cleaner ownership story", message: "Turn raw totals into useful financial context.")
            ]
        case .servicePrediction:
            return [
                PaywallBenefit(icon: "wrench.and.screwdriver.fill", title: "Likely due next", message: "See what may need attention before costs creep up."),
                PaywallBenefit(icon: "clock.badge.exclamationmark.fill", title: "Smarter prioritization", message: "Focus on the service items that deserve attention first."),
                PaywallBenefit(icon: "chart.line.uptrend.xyaxis", title: "Maintenance trends", message: "Understand timing patterns across your service history."),
                PaywallBenefit(icon: "list.bullet.rectangle.portrait", title: "Calmer planning", message: "Keep service planning useful, not overwhelming.")
            ]
        case .fuelTrend:
            return [
                PaywallBenefit(icon: "gauge.with.dots.needle.33percent", title: "Long-term averages", message: "See how your car performs beyond the latest fill-up."),
                PaywallBenefit(icon: "chart.xyaxis.line", title: "Trend charts", message: "Track fuel history visually without guesswork."),
                PaywallBenefit(icon: "line.3.horizontal.decrease.circle.fill", title: "Flexible filtering", message: "Focus on the periods that matter most."),
                PaywallBenefit(icon: "fuelpump.fill", title: "Deeper fuel insights", message: "Spot patterns in spend, price, and consumption over time.")
            ]
        case .resaleReport:
            return [
                PaywallBenefit(icon: "checkmark.seal.fill", title: "Buyer-ready report", message: "Turn your records into a cleaner story for buyers."),
                PaywallBenefit(icon: "text.book.closed.fill", title: "Confidence strengths", message: "See what already supports resale confidence."),
                PaywallBenefit(icon: "exclamationmark.triangle.fill", title: "Weakness signals", message: "Spot what still reduces buyer trust."),
                PaywallBenefit(icon: "doc.richtext.fill", title: "Shareable exports", message: "Keep resale prep polished when you need it.")
            ]
        case .analytics:
            return [
                PaywallBenefit(icon: "chart.pie.fill", title: "Full cost breakdown", message: "See where your money really goes."),
                PaywallBenefit(icon: "fuelpump.fill", title: "Fuel efficiency tracking", message: "Spot long-term consumption trends, not just single fill-ups."),
                PaywallBenefit(icon: "wrench.and.screwdriver.fill", title: "Smarter maintenance insights", message: "Catch patterns before service costs creep up."),
                PaywallBenefit(icon: "doc.richtext.fill", title: "Resale and export tools", message: "Share a cleaner, buyer-ready ownership story.")
            ]
        case .fuelTracking:
            return [
                PaywallBenefit(icon: "gauge.with.dots.needle.33percent", title: "Real fuel efficiency", message: "Track the averages that matter over time."),
                PaywallBenefit(icon: "chart.xyaxis.line", title: "Trend charts", message: "See spend, prices, and consumption visually."),
                PaywallBenefit(icon: "line.3.horizontal.decrease.circle.fill", title: "Flexible filtering", message: "Focus on recent periods or your full history."),
                PaywallBenefit(icon: "fuelpump.fill", title: "Deeper fuel insights", message: "Spot patterns in spend, price, and consumption over time.")
            ]
        case .secondVehicle:
            return [
                PaywallBenefit(icon: "car.2.fill", title: "Unlimited vehicles", message: "Track your whole garage in one place."),
                PaywallBenefit(icon: "rectangle.split.3x1.fill", title: "Garage comparisons", message: "See which vehicle costs the most to own."),
                PaywallBenefit(icon: "chart.bar.fill", title: "Garage-wide insights", message: "Compare spend and running costs side by side."),
                PaywallBenefit(icon: "doc.plaintext.fill", title: "Cleaner records", message: "Keep every history ready when you need it.")
            ]
        default:
            return [
                PaywallBenefit(icon: "car.2.fill", title: "Unlimited vehicles", message: "Track your whole garage, not just one car."),
                PaywallBenefit(icon: "bell.badge.fill", title: "Smart reminders", message: "Get reminders by date, mileage, or both."),
                PaywallBenefit(icon: "icloud.and.arrow.up.fill", title: "Automatic iCloud Backup", message: "Keep a protected backup copy of your records in iCloud when you leave the app."),
                PaywallBenefit(icon: "fuelpump.fill", title: "Fuel efficiency insights", message: "Unlock consumption, charts, filters, and deeper fuel trends."),
                PaywallBenefit(icon: "doc.richtext.fill", title: "Reports and resale tools", message: "Keep receipts organized and export buyer-ready history.")
            ]
        }
    }

    private func selectFirstAvailablePlanIfNeeded() {
        guard entitlementStore.product(for: selectedPlan) == nil else { return }
        guard let availablePlan = EntitlementStore.ProPlan.allCases.first(where: { entitlementStore.product(for: $0) != nil }) else { return }
        selectedPlan = availablePlan
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

private struct PaywallBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
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
            return "Best value for long-term use"
        case .lifetime:
            return "Pay once, unlock Pro forever"
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

    var priceUnavailableText: String {
        "Pricing unavailable right now"
    }

    func ctaTitle(priceText: String) -> String {
        switch self {
        case .monthly:
            return priceText == priceUnavailableText ? "Choose Monthly" : "Start Pro for \(priceText)"
        case .yearly:
            return priceText == priceUnavailableText ? "Choose Yearly" : "Start Pro for \(priceText)"
        case .lifetime:
            return priceText == priceUnavailableText ? "Unlock Lifetime Pro" : "Unlock Pro forever for \(priceText)"
        }
    }
}

private enum PaywallPriceFormatter {
    static func localizedSavingsText(monthly: Product?, yearly: Product?) -> String? {
        guard let monthly, let yearly else { return nil }

        let annualMonthlyCost = NSDecimalNumber(decimal: monthly.price)
            .multiplying(by: NSDecimalNumber(value: 12))
            .decimalValue
        let savings = NSDecimalNumber(decimal: annualMonthlyCost)
            .subtracting(NSDecimalNumber(decimal: yearly.price))
            .decimalValue

        guard NSDecimalNumber(decimal: savings).compare(NSDecimalNumber.zero) == .orderedDescending else {
            return nil
        }

        let formattedSavings = yearly.priceFormatStyle.format(savings)
        return "Save \(formattedSavings) over monthly billing"
    }
}
