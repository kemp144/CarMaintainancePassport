import Charts
import SwiftData
import SwiftUI

enum MetricState<T> {
    case ready(T)
    case notEnoughHistory(String)
    case neverRecorded
    case incompleteRecord
}

enum MaintenanceComponent: String, CaseIterable, Identifiable {
    case oilChange = "Oil Change"
    case brakes = "Brakes"
    case tires = "Tires"
    case battery = "Battery"
    case inspection = "Inspection"
    case fluids = "Fluids & Filters"
    case repair = "Repair"
    case cleaning = "Detailing & Wash"
    case admin = "Registration & Insurance"
    case other = "Other"
    
    var id: String { rawValue }
    
    static func from(serviceType: ServiceType) -> MaintenanceComponent {
        switch serviceType {
        case .oilChange: return .oilChange
        case .brakes: return .brakes
        case .tires: return .tires
        case .battery: return .battery
        case .inspection: return .inspection
        case .registration, .insurance: return .admin
        case .repair: return .repair
        case .washDetailing: return .cleaning
        case .filters, .airConditioning: return .fluids
        default: return .other
        }
    }
}

struct VehicleAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    let vehicle: Vehicle
    
    @Query private var allVehicles: [Vehicle]
    
    @StateObject private var viewModel: VehicleIntelligenceViewModel
    @State private var selectedTab: AnalyticsTab = .financials
    @State private var showingFinancePreview = false
    @State private var showingServicePreview = false
    @State private var showingFuelPreview = false
    @State private var showingResalePreview = false
    @State private var showingForecastDetail = false
    
    enum AnalyticsTab: String, CaseIterable, Identifiable {
        case financials = "Finance"
        case service = "Service"
        case fuel = "Fuel"
        case resale = "Resale"
        case garage = "Garage"
        var id: String { rawValue }
    }
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        self._viewModel = StateObject(wrappedValue: VehicleIntelligenceViewModel(vehicle: vehicle))
    }

    private var hasAdvancedInsights: Bool {
        entitlementStore.canViewAdvancedInsights()
    }

    private var canRevealFinancePreview: Bool {
        !hasAdvancedInsights &&
        entitlementStore.canShowPreview(for: .finance) &&
        !viewModel.financePreviewTopCategories.isEmpty
    }

    private var hasUsedFinancePreview: Bool {
        !hasAdvancedInsights && entitlementStore.hasUsedPreview(for: .finance)
    }

    private var canRevealServicePreview: Bool {
        !hasAdvancedInsights &&
        entitlementStore.canShowPreview(for: .service) &&
        viewModel.servicePreviewAvailable
    }

    private var hasUsedServicePreview: Bool {
        !hasAdvancedInsights && entitlementStore.hasUsedPreview(for: .service)
    }

    private var canRevealFuelPreview: Bool {
        !hasAdvancedInsights &&
        entitlementStore.canShowPreview(for: .fuel) &&
        viewModel.validFuelCycleCount >= 3
    }

    private var hasUsedFuelPreview: Bool {
        !hasAdvancedInsights && entitlementStore.hasUsedPreview(for: .fuel)
    }

    private var canRevealResalePreview: Bool {
        !hasAdvancedInsights &&
        entitlementStore.canShowPreview(for: .resale) &&
        viewModel.resalePreviewAvailable
    }

    private var hasUsedResalePreview: Bool {
        !hasAdvancedInsights && entitlementStore.hasUsedPreview(for: .resale)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(AnalyticsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.heroGradient)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .financials:
                            financialsTab
                        case .service:
                            maintenanceTab
                        case .fuel:
                            fuelTab
                        case .resale:
                            resaleTab
                        case .garage:
                            garageTab
                        }
                    }
                    .padding(AppTheme.Spacing.pageEdge)
                    .padding(.top, 2)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Ownership Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task(id: appState.dataRefreshToken) {
            await viewModel.calculateIntelligence(allVehicles: allVehicles)
            syncPreviewMilestones()
        }
        .sheet(isPresented: $showingForecastDetail) {
            ForecastDetailSheet(items: viewModel.forecastItems, vehicle: vehicle)
        }
    }
    
    // MARK: - Forecast Helpers

    private func forecastContextNote(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - Financials Tab
    private var financialsTab: some View {
        VStack(spacing: 18) {
            // 1. Genuinely useful free insight
            VStack(spacing: 16) {
                SurfaceCard(tier: .primary, padding: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TOTAL OWNERSHIP SPEND")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(AppFormatters.currency(viewModel.totalLifetimeSpend, code: vehicle.currencyCode))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 10) {
                    InsightTile(title: "This Year", state: .ready(AppFormatters.currency(viewModel.thisYearSpend, code: vehicle.currencyCode)), icon: "calendar", compact: true)
                    InsightTile(title: "Last 12 Months", state: .ready(AppFormatters.currency(viewModel.last12MonthsSpend, code: vehicle.currencyCode)), icon: "clock.arrow.circlepath", compact: true)
                }

                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ownership Forecast")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Cumulative · based on upcoming reminders")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                            Spacer()
                            if !viewModel.forecastItems.isEmpty {
                                Button {
                                    showingForecastDetail = true
                                } label: {
                                    Image(systemName: "list.bullet.circle")
                                        .font(.body)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }

                        if viewModel.forecastItems.isEmpty {
                            Text("No upcoming scheduled costs")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        } else if viewModel.upcomingPlannedCost == 0 {
                            Text("Scheduled items found, but cost estimates need more history.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("3 Months")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.currency(viewModel.upcomingPlannedCost3Months, code: vehicle.currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(viewModel.upcomingPlannedCost3Months == 0 ? AppTheme.tertiaryText : AppTheme.primaryText)
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("6 Months")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.currency(viewModel.upcomingPlannedCost6Months, code: vehicle.currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(viewModel.upcomingPlannedCost6Months == 0 ? AppTheme.tertiaryText : AppTheme.primaryText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("12 Months")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.currency(viewModel.upcomingPlannedCost, code: vehicle.currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                if viewModel.upcomingPlannedCost3Months == 0 {
                                    forecastContextNote("Nothing due in the next 3 months.")
                                }
                                if viewModel.upcomingPlannedCost6Months > 0,
                                   viewModel.upcomingPlannedCost6Months == viewModel.upcomingPlannedCost {
                                    forecastContextNote("No additional costs found after 6 months.")
                                }
                            }
                        }

                        if let forecastConfidenceText = viewModel.forecastConfidenceText {
                            DataConfidenceFootnote(message: forecastConfidenceText)
                        }
                    }
                }
            }

            if hasAdvancedInsights {
                // Pro Content
                VStack(spacing: 16) {
                    InsightMessageCard(icon: viewModel.spendTrend90Days > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis", iconColor: viewModel.spendTrend90Days > 0 ? Color.orange : AppTheme.accent, title: "90-Day Trend", message: viewModel.financialSpendTrendText)

                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spending by Year")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if viewModel.spendingByYear.isEmpty {
                                Text("Not enough history")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(height: 160)
                            } else {
                                Chart {
                                    ForEach(viewModel.spendingByYear, id: \.year) { item in
                                        BarMark(
                                            x: .value("Year", String(item.year)),
                                            y: .value("Amount", item.amount)
                                        )
                                        .foregroundStyle(AppTheme.accent.gradient)
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 160)
                            }
                        }
                    }

                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown by Category")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if viewModel.spendingByCategory.isEmpty {
                                Text("No data to display")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(height: 200)
                            } else {
                                Chart {
                                    ForEach(viewModel.spendingByCategory, id: \.category.id) { item in
                                        SectorMark(
                                            angle: .value("Amount", item.amount),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(by: .value("Category", item.category.title))
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 200)
                                .chartLegend(position: .bottom, spacing: 12)

                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.spendingByCategory.enumerated()), id: \.element.category.id) { index, item in
                                        HStack {
                                            Text(item.category.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.primaryText)
                                            Spacer()
                                            Text(AppFormatters.currency(item.amount, code: vehicle.currencyCode))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.primaryText)
                                        }
                                        .padding(.vertical, 6)

                                        if index < viewModel.spendingByCategory.count - 1 {
                                            Divider().overlay(AppTheme.separator)
                                        }
                                    }
                                }
                                .padding(.top, 8)

                                if let insight = viewModel.financialCategoryInsight {
                                    Text(insight)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.tertiaryText)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
            } else {
                // 2. One elegant teaser preview
                if showingFinancePreview {
                    financeBreakdownPreviewCard
                } else if canRevealFinancePreview {
                    PremiumTeaserCard(
                        title: "Where does your money go?",
                        message: viewModel.financePreviewInsightText ?? "Understand which categories drive your ownership costs.",
                        icon: "chart.pie.fill"
                    ) {
                        revealFinancePreview()
                    }
                }

                // 3. One premium locked outcome card
                RefinedLockedInsightCard(
                    title: "See where your money really goes",
                    message: "Understand which categories quietly drive ownership costs over time.",
                    highlights: [
                        "Cost breakdown by category",
                        "Spend trends over time",
                        "Ownership cost patterns"
                    ],
                    ctaTitle: "Unlock Pro"
                ) {
                    ContextualPaywallTrigger.trackAndPresent(
                        reason: .financeBreakdown,
                        coordinator: paywallCoordinator,
                        vehicle: vehicle
                    )
                }
            }
        }
    }
    
    // MARK: - Maintenance Tab
    private var maintenanceTab: some View {
        VStack(spacing: 18) {
            // 1. Genuinely useful free insight
            VStack(spacing: 16) {
                InsightMessageCard(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.accent,
                    title: "Service Health",
                    message: viewModel.maintenanceHealthText,
                    messageColor: viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.secondaryText
                )
                
                HStack(spacing: 10) {
                    InsightTile(title: "Due Soon", state: .ready("\(viewModel.upcomingMaintenanceCount)"), icon: "clock.badge.exclamationmark.fill", compact: true)
                    InsightTile(title: "Overdue", state: .ready("\(viewModel.overdueMaintenanceCount)"), icon: "exclamationmark.circle.fill", compact: true)
                }

                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Basic Tracking")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        VStack(spacing: 8) {
                            AnalyticsRow(title: "Oil Change", state: viewModel.daysSinceLastOilChange)
                            Divider().overlay(AppTheme.separator)
                            AnalyticsRow(title: "Brakes", state: viewModel.distanceSinceLastBrakes)
                            Divider().overlay(AppTheme.separator)
                            AnalyticsRow(title: "Tires", state: viewModel.distanceSinceLastTires)

                            if hasAdvancedInsights {
                                Divider().overlay(AppTheme.separator)
                                AnalyticsRow(title: "Battery", state: viewModel.distanceSinceLastBattery)
                            }
                        }
                    }
                }
            }

            if hasAdvancedInsights {
                // Pro Content
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        InsightTile(title: "Average Interval", state: viewModel.averageServiceIntervalDays, icon: "clock.arrow.2.circlepath", compact: true)
                        InsightTile(title: "Highest Cost Category", state: viewModel.mostExpensiveMaintenanceCategory, icon: "exclamationmark.triangle.fill", compact: true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        DataConfidenceFootnote(message: viewModel.maintenanceConfidenceText)
                        
                        Text(viewModel.maintenanceInsightText)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.tertiaryText.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(-1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            } else {
                // 2. One elegant teaser preview
                if showingServicePreview {
                    servicePredictionPreviewCard
                } else if canRevealServicePreview {
                    PremiumTeaserCard(
                        title: "Know what may need attention next",
                        message: viewModel.servicePredictionPreviewTitle ?? "See likely upcoming service needs based on your history.",
                        icon: "sparkles"
                    ) {
                        revealServicePreview()
                    }
                }

                // 3. One premium locked outcome card
                RefinedLockedInsightCard(
                    title: "Know what may need attention next",
                    message: "See likely upcoming service needs before routine maintenance turns into expensive surprises.",
                    highlights: [
                        "Replacement predictions",
                        "Smarter due-soon prioritization",
                        "Service patterns over time"
                    ],
                    ctaTitle: "Unlock Pro"
                ) {
                    ContextualPaywallTrigger.trackAndPresent(
                        reason: .servicePrediction,
                        coordinator: paywallCoordinator,
                        vehicle: vehicle
                    )
                }
            }
        }
    }
    
    // MARK: - Fuel Tab
    private var fuelTab: some View {
        VStack(spacing: 18) {
            // 1. Genuinely useful free insight
            VStack(spacing: 16) {
                InsightMessageCard(
                    icon: "fuelpump.fill",
                    iconColor: AppTheme.accent,
                    title: "Fuel Snapshot",
                    message: viewModel.fuelSpendTrendText
                )
                
                HStack(spacing: 10) {
                    InsightTile(title: "Avg Fuel Price", state: viewModel.averageFuelPrice, icon: "dollarsign.circle", compact: true)
                    InsightTile(title: "Recent Avg (3 cycles)", state: viewModel.recentAverageConsumption, icon: "gauge.medium", compact: true)
                }

                if let last = viewModel.lastValidTank {
                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last Full Fill-up")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Volume")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.fuelVolume(last.liters))
                                        .font(.subheadline.weight(.semibold))
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("Cost")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.currency(last.totalCost, code: vehicle.currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Date")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(AppFormatters.mediumDate.string(from: last.date))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                    }
                }

                DataConfidenceFootnote(message: viewModel.fuelDataConfidenceText)
            }

            if hasAdvancedInsights {
                // Pro Content
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        InsightTile(title: "All-Time Avg", state: viewModel.allTimeAverageConsumption, icon: "chart.line.uptrend.xyaxis", compact: true)
                        InsightTile(title: "Fuel Cost / 100 km", state: viewModel.costPer100Km, icon: "road.lanes", compact: true)
                    }
                }
            } else {
                // 2. One elegant teaser preview
                if showingFuelPreview {
                    fuelTrendPreviewCard
                } else if canRevealFuelPreview {
                    PremiumTeaserCard(
                        title: "Long-term trend ready",
                        message: "You already logged \(viewModel.validFuelCycleCount) valid fill-ups. Unlock your long-term fuel trend.",
                        icon: "chart.xyaxis.line"
                    ) {
                        revealFuelPreview()
                    }
                }

                // 3. One premium locked outcome card
                RefinedLockedInsightCard(
                    title: "See your real fuel efficiency",
                    message: "Your history is already useful. Pro adds the long-term view that makes fuel costs easier to understand.",
                    highlights: [
                        "Long-term average consumption",
                        "Trend charts and period filters",
                        "Efficiency insights"
                    ],
                    ctaTitle: "Unlock Pro"
                ) {
                    ContextualPaywallTrigger.trackAndPresent(
                        reason: .fuelTrend,
                        coordinator: paywallCoordinator,
                        vehicle: vehicle
                    )
                }
            }
        }
    }
    
    // MARK: - Resale Tab
    private var resaleTab: some View {
        VStack(spacing: 18) {
            // 1. Genuinely useful free insight
            VStack(spacing: 16) {
                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buyer-Ready Status")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(AppTheme.surfaceSecondary, lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(viewModel.resaleReadinessScore) / 100.0)
                                    .stroke(viewModel.resaleReadinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    
                                Text("\(viewModel.resaleReadinessScore)%")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.resaleReadinessTier)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                
                                Text(viewModel.resaleNextStepGuidance)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
                
                HStack(spacing: 10) {
                    InsightTile(title: "Service Records", state: .ready("\(viewModel.serviceRecordCount)"), icon: "doc.text.fill", compact: true)
                    InsightTile(title: "Receipt Coverage", state: .ready(String(format: "%.0f%%", viewModel.receiptCoveragePercentage)), icon: "paperclip", compact: true)
                }

                SurfaceCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Resale Checklist")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            
                        VStack(spacing: 8) {
                            ChecklistItem(title: "Detailed service history", isComplete: viewModel.serviceRecordCount > 3)
                            ChecklistItem(title: "Supporting receipt coverage", isComplete: viewModel.receiptCoveragePercentage > 70)
                            ChecklistItem(title: "Documents in Vault", isComplete: viewModel.vaultDocumentCount > 0)
                        }
                    }
                }

                DataConfidenceFootnote(message: viewModel.resaleConfidenceText)
            }

            if hasAdvancedInsights {
                // Pro Content
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        InsightTile(title: "Buyer Support Docs", state: .ready("\(viewModel.buyerSupportDocumentCount)"), icon: "text.book.closed.fill", compact: true)
                        InsightTile(title: "Documents in Vault", state: .ready("\(viewModel.vaultDocumentCount)"), icon: "doc.on.doc.fill", compact: true)
                    }
                }
            } else {
                // 2. One elegant teaser preview
                if showingResalePreview {
                    resalePreviewCard
                } else if viewModel.resalePreviewAvailable {
                    PremiumTeaserCard(
                        title: "Turn records into buyer confidence",
                        message: "Your vehicle is \(viewModel.resaleReadinessScore)% buyer-ready. See how your records support buyer confidence.",
                        icon: "shield.checkered"
                    ) {
                        revealResalePreview()
                    }
                }

                // 3. One premium locked outcome card
                RefinedLockedInsightCard(
                    title: "Turn your records into buyer confidence",
                    message: "See how your service history and document coverage strengthen resale readiness.",
                    highlights: [
                        "Buyer-ready report",
                        "Record coverage insight",
                        "Estimated resale support score"
                    ],
                    ctaTitle: "Unlock Pro"
                ) {
                    ContextualPaywallTrigger.trackAndPresent(
                        reason: .resaleReport,
                        coordinator: paywallCoordinator,
                        vehicle: vehicle
                    )
                }
            }
        }
    }
    
    // MARK: - Garage Tab
    private var garageTab: some View {
        VStack(spacing: 18) {
            // 1. Genuinely useful free insight
            VStack(spacing: 16) {
                InsightMessageCard(
                    icon: "car.2.fill",
                    iconColor: AppTheme.accent,
                    title: "Garage Intelligence",
                    message: viewModel.garageIntelligenceText
                )

                HStack(spacing: 10) {
                    InsightTile(title: "Vehicles in Garage", state: .ready("\(viewModel.garageVehicleCount)"), icon: "car.2.fill", compact: true)
                    InsightTile(title: "Garage Spend This Year", state: .ready(AppFormatters.currency(viewModel.garageTotalSpendThisYear, code: vehicle.currencyCode)), icon: "calendar", compact: true)
                }

                SurfaceCard(tier: .primary, padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Garage Snapshot")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        AnalyticsDetailRow(
                            title: "Top vehicle by total cost",
                            value: viewModel.garageTopVehicleSummary ?? "Not enough data yet"
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Highest fuel spend",
                            value: viewModel.garageHighestFuelSpendSummary ?? "Not enough data yet"
                        )
                        Divider().overlay(AppTheme.separator)
                        AnalyticsDetailRow(
                            title: "Latest serviced vehicle",
                            value: viewModel.garageLatestServiceSummary ?? "Not enough data yet"
                        )
                    }
                }
            }

            if hasAdvancedInsights {
                // Pro Content
                VStack(spacing: 16) {
                    if !viewModel.garageSpendByVehicle.isEmpty {
                        SurfaceCard(tier: .primary) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Total Spend by Vehicle")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Chart {
                                    ForEach(viewModel.garageSpendByVehicle, id: \.title) { item in
                                        BarMark(
                                            x: .value("Amount", item.amount),
                                            y: .value("Vehicle", item.title)
                                        )
                                        .foregroundStyle(AppTheme.accent.gradient)
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: max(100, CGFloat(viewModel.garageSpendByVehicle.count * 40)))
                            }
                        }
                    }

                    if !viewModel.costPerKmByVehicle.isEmpty {
                        SurfaceCard(tier: .primary) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Cost Per Distance")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.costPerKmByVehicle.enumerated()), id: \.element.title) { index, item in
                                        HStack {
                                            Text(item.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.primaryText)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            Spacer()
                                            Text(UnitFormatter.costPerDistanceCurrency(item.cost, currencyCode: vehicle.currencyCode))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(AppTheme.primaryText)
                                        }
                                        .padding(.vertical, 6)

                                        if index < viewModel.costPerKmByVehicle.count - 1 {
                                            Divider().overlay(AppTheme.separator)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // 2. One elegant teaser preview
                if allVehicles.count > 1 {
                    PremiumTeaserCard(
                        title: "Compare your garage side by side",
                        message: viewModel.costliestVehicleThisYear.map { "\($0) is your most expensive vehicle this year. See the full comparison." } ?? "See which vehicle costs the most to own, fuel, and maintain over time.",
                        icon: "car.2.fill"
                    ) {
                        ContextualPaywallTrigger.trackAndPresent(
                            reason: .secondVehicle,
                            coordinator: paywallCoordinator,
                            vehicle: vehicle
                        )
                    }
                } else {
                    DataConfidenceFootnote(message: "Add another vehicle to compare costs.")
                }

                // 3. One premium locked outcome card
                RefinedLockedInsightCard(
                    title: "Compare your garage side by side",
                    message: "See which vehicle costs the most to own, fuel, and maintain over time.",
                    highlights: [
                        "Spend by vehicle",
                        "Fuel and service comparison",
                        "Multi-car ownership insights"
                    ],
                    ctaTitle: "Unlock Pro"
                ) {
                    ContextualPaywallTrigger.trackAndPresent(
                        reason: .secondVehicle,
                        coordinator: paywallCoordinator,
                        vehicle: vehicle
                    )
                }
            }
        }
    }

    private var maintenancePreviewText: String? {
        if showingServicePreview {
            return "One-time service prediction preview unlocked."
        }

        if hasUsedServicePreview {
            return "Service prediction preview used."
        }

        if let likelyDueNextItem = viewModel.likelyDueNextItem {
            return "\(likelyDueNextItem) may need attention next."
        }

        if viewModel.overdueMaintenanceCount > 0 || viewModel.upcomingMaintenanceCount > 0 {
            return viewModel.maintenanceHealthText
        }

        return viewModel.maintenanceInsightText
    }

    private var resalePreviewText: String? {
        if showingResalePreview {
            return "Buyer report preview unlocked."
        }

        if hasUsedResalePreview {
            return "Buyer report preview used."
        }

        if viewModel.resaleReadinessScore > 0 {
            return "\(viewModel.resaleReadinessScore)% buyer-ready today."
        }

        return viewModel.resaleNextStepGuidance
    }

    private var garagePreviewText: String? {
        if allVehicles.count > 1, let costliestVehicleThisYear = viewModel.costliestVehicleThisYear {
            return "\(costliestVehicleThisYear) is your most expensive vehicle this year."
        }

        if allVehicles.count > 1 {
            return viewModel.garageIntelligenceText
        }

        return "Your first vehicle is ready. Add another to compare ownership costs side by side."
    }

    private var financePreviewPromptText: String? {
        if hasUsedFinancePreview {
            return "Preview already used. Pro keeps cost category insight available any time."
        }
        if viewModel.financePreviewTopCategories.isEmpty {
            return "Available once more ownership costs are logged."
        }
        return "One-time preview available once you tap in."
    }

    private var servicePreviewPromptText: String {
        viewModel.servicePreviewAvailable
            ? "See what may need attention next"
            : "Available once more service history is logged"
    }

    private var servicePreviewFootnote: String? {
        if hasUsedServicePreview {
            return "Preview already used. Pro keeps smarter predictions and longer-term planning available."
        }
        return viewModel.servicePreviewAvailable ? "One-time preview available." : viewModel.maintenanceConfidenceText
    }

    private var fuelPreviewPromptText: String? {
        if hasUsedFuelPreview {
            return "Preview already used. Pro keeps long-term fuel trends available."
        }
        return "One-time preview available once your fuel trend is ready."
    }

    private var resalePreviewPromptText: String? {
        if hasUsedResalePreview {
            return "Preview already used. Pro keeps buyer-facing resale tools available."
        }
        return "One-time preview available once buyer confidence starts to take shape."
    }

    private var financePreviewText: String? {
        if showingFinancePreview {
            return "One-time cost preview unlocked."
        }

        if hasUsedFinancePreview {
            return "One-time cost preview used."
        }

        if let insight = viewModel.financePreviewInsightText {
            return insight
        }

        guard viewModel.totalLifetimeSpend > 0 else { return nil }
        return "You've logged \(AppFormatters.currency(viewModel.totalLifetimeSpend, code: vehicle.currencyCode)) so far."
    }

    private var fuelPreviewText: String? {
        if showingFuelPreview {
            return "One-time fuel trend preview unlocked."
        }

        if hasUsedFuelPreview {
            return "One-time fuel trend preview used."
        }

        if let insight = viewModel.fuelPreviewInsightText {
            return insight
        }

        if let average = viewModel.recentAverageConsumption.readyValue {
            return "Recent average: \(average)"
        }

        if let note = viewModel.recentAverageConsumption.placeholderText {
            return note
        }

        return nil
    }

    private var financeBreakdownPreviewCard: some View {
        PartialRevealCard(
            title: "Category Breakdown Preview",
            message: "A small first look at what currently stands out in your ownership costs.",
            footnote: "One-time preview only. Pro unlocks the full breakdown, yearly trends, and deeper cost context."
        ) {
            Chart {
                ForEach(viewModel.financePreviewTopCategories, id: \.title) { item in
                    BarMark(
                        x: .value("Category", item.title),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 120)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.financePreviewTopCategories.enumerated()), id: \.element.title) { index, item in
                    AnalyticsDetailRow(
                        title: item.title,
                        value: AppFormatters.currency(item.amount, code: vehicle.currencyCode)
                    )

                    if index < viewModel.financePreviewTopCategories.count - 1 {
                        Divider().overlay(AppTheme.separator)
                    }
                }
            }

            if let financePreviewInsightText = viewModel.financePreviewInsightText {
                Text(financePreviewInsightText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -2)
            }
        }
    }

    private var servicePredictionPreviewCard: some View {
        PartialRevealCard(
            title: "Likely Due Next Preview",
            message: "A soft estimate based on your logged maintenance history.",
            footnote: "One-time preview only. Pro keeps this prediction layer and deeper service planning available."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.servicePredictionPreviewTitle ?? "Maintenance history is still taking shape")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(viewModel.servicePredictionPreviewText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let servicePredictionConfidenceText = viewModel.servicePredictionConfidenceText {
                    DataConfidenceFootnote(message: servicePredictionConfidenceText)
                }
            }
        }
    }

    private var fuelTrendPreviewCard: some View {
        PartialRevealCard(
            title: "Fuel Trend Preview",
            message: "A compact look at how your long-term fuel pattern compares with your recent average.",
            footnote: "One-time preview only. Pro unlocks full fuel trend history, filters, and deeper analysis."
        ) {
            HStack(spacing: 12) {
                InsightTile(title: "Recent Avg (3 cycles)", state: viewModel.recentAverageConsumption, icon: "gauge.medium")
                InsightTile(title: "All-Time Average", state: viewModel.allTimeAverageConsumption, icon: "gauge.with.dots.needle.67percent")
            }

            Chart {
                ForEach(viewModel.fuelConsumptionPreviewPoints) { point in
                    LineMark(
                        x: .value("Cycle", point.label),
                        y: .value("Consumption", point.value)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Cycle", point.label),
                        y: .value("Consumption", point.value)
                    )
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(height: 120)

            if let fuelPreviewInsightText = viewModel.fuelPreviewInsightText {
                Text(fuelPreviewInsightText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -2)
            }
        }
    }

    private var resalePreviewCard: some View {
        PartialRevealCard(
            title: "Buyer Report Preview",
            message: "A short look at how your records currently support buyer confidence.",
            footnote: "One-time preview only. Pro keeps buyer-ready reports, deeper risk context, and export tools available."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.resalePreviewSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.resalePreviewStrengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                                .font(.caption.weight(.semibold))
                                .padding(.top, 0)
                            Text(strength)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let resalePreviewWeakness = viewModel.resalePreviewWeakness {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.orange)
                            .font(.caption.weight(.semibold))
                            .padding(.top, 0)
                        Text(resalePreviewWeakness)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let resalePreviewConfidenceNote = viewModel.resalePreviewConfidenceNote {
                    DataConfidenceFootnote(message: resalePreviewConfidenceNote)
                }
            }
        }
    }

    private func revealFinancePreview() {
        guard hasUsedFinancePreview || canRevealFinancePreview else { return }

        if canRevealFinancePreview, entitlementStore.consumePreview(for: .finance) {
            showingFinancePreview = true
        } else {
            ContextualPaywallTrigger.trackAndPresent(
                reason: .financeBreakdown,
                coordinator: paywallCoordinator,
                vehicle: vehicle
            )
        }
    }

    private func revealServicePreview() {
        guard hasUsedServicePreview || canRevealServicePreview else { return }

        if canRevealServicePreview, entitlementStore.consumePreview(for: .service) {
            showingServicePreview = true
        } else {
            ContextualPaywallTrigger.trackAndPresent(
                reason: .servicePrediction,
                coordinator: paywallCoordinator,
                vehicle: vehicle
            )
        }
    }

    private func revealFuelPreview() {
        guard hasUsedFuelPreview || canRevealFuelPreview else { return }

        if canRevealFuelPreview, entitlementStore.consumePreview(for: .fuel) {
            showingFuelPreview = true
        } else {
            ContextualPaywallTrigger.trackAndPresent(
                reason: .fuelTrend,
                coordinator: paywallCoordinator,
                vehicle: vehicle
            )
        }
    }

    private func revealResalePreview() {
        guard hasUsedResalePreview || canRevealResalePreview else { return }

        if canRevealResalePreview, entitlementStore.consumePreview(for: .resale) {
            showingResalePreview = true
        } else {
            ContextualPaywallTrigger.trackAndPresent(
                reason: .resaleReport,
                coordinator: paywallCoordinator,
                vehicle: vehicle
            )
        }
    }

    private func syncPreviewMilestones() {
        if !viewModel.financePreviewTopCategories.isEmpty {
            entitlementStore.unlockPreviewMilestone(for: .finance)
        } else {
            entitlementStore.lockPreviewMilestone(for: .finance)
        }

        if viewModel.servicePreviewAvailable {
            entitlementStore.unlockPreviewMilestone(for: .service, milestoneValue: viewModel.maintenanceHistoryCount)
        } else {
            entitlementStore.lockPreviewMilestone(for: .service)
        }

        if viewModel.validFuelCycleCount >= 3 {
            entitlementStore.unlockPreviewMilestone(for: .fuel, milestoneValue: viewModel.validFuelCycleCount)
        } else {
            entitlementStore.lockPreviewMilestone(for: .fuel)
        }

        if viewModel.resalePreviewAvailable {
            entitlementStore.unlockPreviewMilestone(for: .resale, milestoneValue: viewModel.resaleReadinessScore)
        } else {
            entitlementStore.lockPreviewMilestone(for: .resale)
        }
    }
}

// MARK: - Reusable Components


struct InsightMessageCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    var messageColor: Color = AppTheme.secondaryText

    var body: some View {
        SurfaceCard(padding: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(messageColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    var compact: Bool = false
    
    var body: some View {
        SurfaceCard(padding: compact ? 10 : 16) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 11 : 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: compact ? 9.5 : 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch state {
                case .ready(let value):
                    Text(value)
                        .font(.system(size: compact ? 15 : 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                case .neverRecorded:
                    Text("Not recorded")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 52 : 72, alignment: compact ? .leading : .topLeading)
        }
    }
}

struct AnalyticsRow: View {
    let title: String
    let state: MetricState<String>

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer(minLength: 8)

            switch state {
            case .ready(let value):
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        value.contains("Overdue") ? Color.red :
                        value.contains("Due soon") ? Color.orange :
                        AppTheme.secondaryText
                    )
            case .notEnoughHistory(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            case .neverRecorded:
                Text("Not recorded")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            case .incompleteRecord:
                Text("Partial data")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }
}

struct ChecklistItem: View {
    let title: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? AppTheme.accent : AppTheme.tertiaryText)
                .font(.system(size: 18))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isComplete ? AppTheme.primaryText : AppTheme.secondaryText)
                
            Spacer()
        }
    }
}

struct AnalyticsDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct FuelConsumptionPreviewPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private extension MetricState where T == String {
    var readyValue: String? {
        guard case .ready(let value) = self else { return nil }
        return value
    }

    var placeholderText: String? {
        switch self {
        case .notEnoughHistory(let message):
            return message
        case .neverRecorded:
            return "Not recorded yet."
        case .incompleteRecord:
            return "Partial data — log more history."
        case .ready:
            return nil
        }
    }
}

@MainActor
final class VehicleIntelligenceViewModel: ObservableObject {
    let vehicle: Vehicle
    
    // Overview Metrics
    @Published var totalLifetimeSpend: Double = 0
    @Published var thisYearSpend: Double = 0
    @Published var last12MonthsSpend: Double = 0
    @Published var averageMonthlyCost: Double = 0
    @Published var upcomingPlannedCost: Double = 0
    @Published var upcomingPlannedCost3Months: Double = 0
    @Published var upcomingPlannedCost6Months: Double = 0
    @Published fileprivate var forecastItems: [ForecastItem] = []

    // Compare Metrics
    @Published var last90DaysSpend: Double = 0
    @Published var previous90DaysSpend: Double = 0
    @Published var spendTrend90Days: Double = 0
    @Published var financialSpendTrendText: String = "Not enough data"
    @Published var forecastConfidenceText: String? = nil
    
    // Breakdown
    @Published var spendingByYear: [(year: Int, amount: Double)] = []
    @Published var spendingByCategory: [(category: EntryCategory, amount: Double)] = []
    @Published var financialCategoryInsight: String? = nil
    @Published var financePreviewTopCategories: [(title: String, amount: Double)] = []
    @Published var financePreviewInsightText: String? = nil
    
    // Fuel Intelligence
    @Published var lastValidTank: FuelEntry?
    @Published var recentAverageConsumption: MetricState<String> = .notEnoughHistory("Need 3+ full fill-ups")
    @Published var allTimeAverageConsumption: MetricState<String> = .notEnoughHistory("Need more fill-ups")
    @Published var threeTankAverageConsumption: MetricState<String> = .notEnoughHistory("Need 3 fill-ups")
    @Published var sixTankAverageConsumption: MetricState<String> = .notEnoughHistory("Need 6 fill-ups")
    @Published var costPer100Km: MetricState<String> = .notEnoughHistory("Need more data")
    @Published var averageFuelPrice: MetricState<String> = .notEnoughHistory("Need more data")
    @Published var fuelSpendTrendText: String = "Log more full fill-ups to reveal patterns."
    @Published var fuelDataConfidenceText: String = "Useful now, smarter over time."
    @Published var validFuelCycleCount: Int = 0
    @Published var fuelConsumptionPreviewPoints: [FuelConsumptionPreviewPoint] = []
    @Published var fuelPreviewInsightText: String? = nil
    
    // Maintenance Intelligence
    @Published var mostExpensiveMaintenanceCategory: MetricState<String> = .neverRecorded
    @Published var averageServiceIntervalDays: MetricState<String> = .notEnoughHistory("More service history needed")
    @Published var daysSinceLastOilChange: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastBrakes: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastTires: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastBattery: MetricState<String> = .neverRecorded
    @Published var upcomingMaintenanceCount: Int = 0
    @Published var overdueMaintenanceCount: Int = 0
    @Published var maintenanceHealthText: String = "All maintenance is up to date."
    @Published var maintenanceInsightText: String = "Insights improve as you log more history."
    @Published var maintenanceConfidenceText: String = "Useful now, smarter over time."
    @Published var policyReminderSummaryText: String? = nil
    @Published var maintenanceHistoryCount: Int = 0
    @Published var servicePreviewAvailable: Bool = false
    @Published var likelyDueNextItem: String? = nil
    @Published var servicePredictionPreviewTitle: String? = nil
    @Published var servicePredictionPreviewText: String = "Available once more service history is logged."
    @Published var servicePredictionConfidenceText: String? = nil

    // Garage Intelligence
    @Published var garageSpendByVehicle: [(title: String, amount: Double)] = []
    @Published var garageFuelSpendByVehicle: [(title: String, amount: Double)] = []
    @Published var costliestVehicleThisYear: String?
    @Published var costPerKmByVehicle: [(title: String, cost: Double)] = []
    @Published var garageIntelligenceText: String = "Compare your multi-vehicle fleet."
    @Published var garageVehicleCount: Int = 0
    @Published var garageTotalSpendThisYear: Double = 0
    @Published var garageTopVehicleSummary: String? = nil
    @Published var garageHighestFuelSpendSummary: String? = nil
    @Published var garageLatestServiceSummary: String? = nil

    // Resale Readiness
    @Published var serviceRecordCount: Int = 0
    @Published var receiptCoveragePercentage: Double = 0
    @Published var resaleReadinessScore: Int = 0
    @Published var resaleReadinessTier: String = "Needs Work"
    @Published var resaleReadinessColor: Color = Color.orange
    @Published var resaleNextStepGuidance: String = "A complete history improves resale value."
    @Published var vaultDocumentCount: Int = 0
    @Published var buyerSupportDocumentCount: Int = 0
    @Published var resaleConfidenceText: String = "More supporting records improve buyer confidence."
    @Published var resalePreviewAvailable: Bool = false
    @Published var resalePreviewSummary: String = ""
    @Published var resalePreviewStrengths: [String] = []
    @Published var resalePreviewWeakness: String? = nil
    @Published var resalePreviewConfidenceNote: String? = nil

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
    }
    
    nonisolated private static func evaluateHealth(items: [ServiceEntry], vehicleMileage: Int, byDistance: Bool) -> MetricState<String> {
        guard !items.isEmpty else { return .neverRecorded }
        
        let validItems = items.filter { byDistance ? $0.mileage > 0 : true }
        
        if validItems.isEmpty {
            return .incompleteRecord
        }
        
        if validItems.count == 1 {
            return .notEnoughHistory("More service history needed")
        }
        
        let sorted = validItems.sorted { byDistance ? $0.mileage < $1.mileage : $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return .incompleteRecord }
        
        if byDistance {
            let totalDist = last.mileage - first.mileage
            if totalDist <= 0 { return .incompleteRecord }
            let avgInterval = totalDist / (sorted.count - 1)
            let elapsed = vehicleMileage - last.mileage
            
            if elapsed < 0 { return .incompleteRecord }
            
            if elapsed >= avgInterval {
                return .ready("Overdue · \(AppFormatters.mileage(elapsed)) ago")
            } else if elapsed >= Int(Double(avgInterval) * 0.85) {
                return .ready("Due soon · \(AppFormatters.mileage(elapsed)) ago")
            } else {
                return .ready("Healthy · \(AppFormatters.mileage(elapsed)) ago")
            }
        } else {
            let calendar = Calendar.current
            let totalDays = calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0
            if totalDays <= 0 { return .incompleteRecord }
            let avgInterval = totalDays / (sorted.count - 1)
            let elapsed = calendar.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            
            if elapsed < 0 { return .incompleteRecord }
            
            if elapsed >= avgInterval {
                return .ready("Overdue · \(elapsed) days ago")
            } else if elapsed >= Int(Double(avgInterval) * 0.85) {
                return .ready("Due soon · \(elapsed) days ago")
            } else {
                return .ready("Healthy · \(elapsed) days ago")
            }
        }
    }
    
    func calculateIntelligence(allVehicles: [Vehicle] = []) async {
        let sortedServices = vehicle.serviceEntries.sorted { $0.date > $1.date }
        let sortedFuel = vehicle.fuelEntries.sorted { $0.date > $1.date }
        let reminders = vehicle.reminders
        let docs = vehicle.documents
        let vehicleMileage = vehicle.currentMileage
        let currencyCode = vehicle.currencyCode
        
        let now = Date()
        let calendar = Calendar.current
        
        let vehiclesData = allVehicles.map { v in
            (title: v.title, currentMileage: v.currentMileage, services: v.serviceEntries, fuel: v.fuelEntries)
        }
        
        let result = await Task.detached { () -> IntelligenceResult in
            var res = IntelligenceResult()
            
            // Financials Engine
            let totalService = sortedServices.reduce(0) { $0 + $1.price }
            let totalFuel = sortedFuel.reduce(0) { $0 + $1.totalCost }
            res.totalLifetimeSpend = totalService + totalFuel
            
            let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? .distantPast
            res.thisYearSpend = sortedServices.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.price } +
                                sortedFuel.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.totalCost }
            
            let last12MonthsStart = calendar.date(byAdding: .month, value: -12, to: now) ?? .distantPast
            res.last12MonthsSpend = sortedServices.filter { $0.date >= last12MonthsStart }.reduce(0) { $0 + $1.price } +
                                    sortedFuel.filter { $0.date >= last12MonthsStart }.reduce(0) { $0 + $1.totalCost }
            
            let last90DaysStart = calendar.date(byAdding: .day, value: -90, to: now) ?? .distantPast
            let previous90DaysStart = calendar.date(byAdding: .day, value: -180, to: now) ?? .distantPast
            
            let last90Service = sortedServices.filter { $0.date >= last90DaysStart && $0.date <= now }.reduce(0) { $0 + $1.price }
            let last90Fuel = sortedFuel.filter { $0.date >= last90DaysStart && $0.date <= now }.reduce(0) { $0 + $1.totalCost }
            res.last90DaysSpend = last90Service + last90Fuel
            let last90SpendEntryCount = sortedServices.filter { $0.date >= last90DaysStart && $0.date <= now }.count +
                sortedFuel.filter { $0.date >= last90DaysStart && $0.date <= now }.count
            
            let prev90Service = sortedServices.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.reduce(0) { $0 + $1.price }
            let prev90Fuel = sortedFuel.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.reduce(0) { $0 + $1.totalCost }
            res.previous90DaysSpend = prev90Service + prev90Fuel
            let previous90SpendEntryCount = sortedServices.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.count +
                sortedFuel.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.count
            
            if res.previous90DaysSpend > 0, last90SpendEntryCount >= 2, previous90SpendEntryCount >= 2 {
                res.spendTrend90Days = ((res.last90DaysSpend - res.previous90DaysSpend) / res.previous90DaysSpend) * 100.0
                let direction = res.spendTrend90Days > 0 ? "up" : "down"
                if abs(res.spendTrend90Days) < 1.0 {
                    res.financialSpendTrendText = "No meaningful change vs previous 90 days."
                } else {
                    res.financialSpendTrendText = "Spending is \(direction) \(abs(Int(res.spendTrend90Days)))% vs previous 90 days."
                }
            } else if res.last90DaysSpend > 0 || res.previous90DaysSpend > 0 {
                res.financialSpendTrendText = "More history will make spend trends more reliable."
            } else {
                res.financialSpendTrendText = "Not enough history for comparison."
            }
            
            let groupedByYear = Dictionary(grouping: sortedServices) { calendar.component(.year, from: $0.date) }
            res.spendingByYear = groupedByYear.map { (year: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
                .sorted { $0.year < $1.year }
            
            let groupedByCategory = Dictionary(grouping: sortedServices) { $0.category }
            res.spendingByCategory = groupedByCategory.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
                .sorted { $0.amount > $1.amount }
                
            if let largestCat = res.spendingByCategory.first {
                if sortedServices.count >= 4 {
                    res.financialCategoryInsight = "\(largestCat.category.title) is your largest service cost category."
                } else {
                    res.financialCategoryInsight = "Early pattern: \(largestCat.category.title) is your largest service cost so far."
                }
            }

            var financePreviewCategories: [(title: String, amount: Double)] = []
            if totalFuel > 0 {
                financePreviewCategories.append((title: "Fuel", amount: totalFuel))
            }
            financePreviewCategories.append(contentsOf: res.spendingByCategory.map { ($0.category.title, $0.amount) })
            res.financePreviewTopCategories = financePreviewCategories
                .sorted { $0.amount > $1.amount }
                .prefix(2)
                .map { $0 }

            if res.financePreviewTopCategories.count >= 2 {
                let first = res.financePreviewTopCategories[0].title
                let second = res.financePreviewTopCategories[1].title
                res.financePreviewInsightText = "\(first) and \(second) currently stand out as your largest ownership costs."
            } else if let first = res.financePreviewTopCategories.first {
                res.financePreviewInsightText = "\(first.title) currently stands out as your largest ownership cost."
            }
            
            // Forecast Engine
            let threeMonthsFromNow = calendar.date(byAdding: .month, value: 3, to: now) ?? now
            let sixMonthsFromNow = calendar.date(byAdding: .month, value: 6, to: now) ?? now
            let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: now) ?? now
            
            var overdueMaintenanceReminders: [ReminderItem] = []
            var upcomingMaintenanceReminders: [ReminderItem] = []
            var policyReminderTitles: [String] = []
            var forecastFallbackCount = 0
            var forecastItemCount = 0
            
            for reminder in reminders where reminder.isEnabled {
                let reminderType = ServiceType(rawValue: reminder.typeRaw)
                let isMaintenanceReminder = reminderType?.countsTowardMaintenanceIntelligence ?? false
                let isPolicyReminder = reminderType?.isPolicyReminder ?? false

                if let due = reminder.dateDue {
                    if due >= now && due <= oneYearFromNow {
                        let relatedServices = sortedServices.filter { $0.serviceType.rawValue == reminder.typeRaw }
                        let estimatedCost = relatedServices.isEmpty
                            ? nil
                            : relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        if estimatedCost == nil {
                            forecastFallbackCount += 1
                        }
                        let itemTitle = ServiceType(rawValue: reminder.typeRaw)?.title ?? reminder.title
                        res.forecastItems.append(ForecastItem(
                            title: itemTitle,
                            dueDate: due,
                            dueMileage: nil,
                            estimatedCost: estimatedCost
                        ))
                        forecastItemCount += 1
                        if let estimatedCost {
                            res.upcomingPlannedCost += estimatedCost
                        }
                        if due <= sixMonthsFromNow {
                            if let estimatedCost {
                                res.upcomingPlannedCost6Months += estimatedCost
                            }
                            if isMaintenanceReminder {
                                res.upcomingMaintenanceCount += 1
                                upcomingMaintenanceReminders.append(reminder)
                            }
                        }
                        if due <= threeMonthsFromNow {
                            if let estimatedCost {
                                res.upcomingPlannedCost3Months += estimatedCost
                            }
                        }
                    }
                    if due < now.startOfDay {
                        if isMaintenanceReminder {
                            res.overdueMaintenanceCount += 1
                            overdueMaintenanceReminders.append(reminder)
                        } else if isPolicyReminder, let reminderType {
                            policyReminderTitles.append(reminderType.title)
                        }
                    }
                } else if let milDue = reminder.mileageDue {
                    if vehicleMileage >= milDue {
                        if isMaintenanceReminder {
                            res.overdueMaintenanceCount += 1
                            overdueMaintenanceReminders.append(reminder)
                        }
                    } else if milDue - vehicleMileage <= 5000 {
                        let relatedServices = sortedServices.filter { $0.serviceType.rawValue == reminder.typeRaw }
                        let estimatedCost = relatedServices.isEmpty
                            ? nil
                            : relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        if estimatedCost == nil {
                            forecastFallbackCount += 1
                        }
                        let itemTitle = ServiceType(rawValue: reminder.typeRaw)?.title ?? reminder.title
                        res.forecastItems.append(ForecastItem(
                            title: itemTitle,
                            dueDate: nil,
                            dueMileage: milDue,
                            estimatedCost: estimatedCost
                        ))
                        forecastItemCount += 1
                        if let estimatedCost {
                            res.upcomingPlannedCost += estimatedCost
                        }

                        if milDue - vehicleMileage <= 2500 {
                            if let estimatedCost {
                                res.upcomingPlannedCost6Months += estimatedCost
                            }
                            if isMaintenanceReminder {
                                res.upcomingMaintenanceCount += 1
                                upcomingMaintenanceReminders.append(reminder)
                            }
                        }
                    }
                }
            }
            
            func getCleanTitle(for reminder: ReminderItem) -> String? {
                if let type = ServiceType(rawValue: reminder.typeRaw), type != .custom {
                    return type.title
                }
                return nil
            }
            
            if res.overdueMaintenanceCount > 0 {
                if res.overdueMaintenanceCount == 1, let first = overdueMaintenanceReminders.first {
                    if let cleanTitle = getCleanTitle(for: first) {
                        res.maintenanceHealthText = "1 item is overdue: \(cleanTitle)"
                    } else {
                        res.maintenanceHealthText = "1 service item is overdue."
                    }
                } else {
                    res.maintenanceHealthText = "\(res.overdueMaintenanceCount) service items appear overdue."
                }
            } else if res.upcomingMaintenanceCount > 0 {
                if res.upcomingMaintenanceCount == 1, let first = upcomingMaintenanceReminders.first {
                    if let cleanTitle = getCleanTitle(for: first) {
                        res.maintenanceHealthText = "1 item due soon: \(cleanTitle)"
                    } else {
                        res.maintenanceHealthText = "1 service item due soon."
                    }
                } else {
                    res.maintenanceHealthText = "\(res.upcomingMaintenanceCount) service items need attention in the next 6 months."
                }
            } else {
                res.maintenanceHealthText = "Track upcoming service items and replacement history."
            }

            if policyReminderTitles.isEmpty {
                res.policyReminderSummaryText = nil
            } else if policyReminderTitles.count == 1, let first = policyReminderTitles.first {
                res.policyReminderSummaryText = "\(first) reminders stay separate from maintenance health."
            } else {
                res.policyReminderSummaryText = "Insurance and registration reminders stay separate from maintenance health."
            }

            res.forecastItems.sort {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): return a < b
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return ($0.dueMileage ?? 0) < ($1.dueMileage ?? 0)
                }
            }

            if res.upcomingPlannedCost == 0 {
                res.forecastConfidenceText = res.forecastItems.isEmpty
                    ? (reminders.isEmpty
                    ? "Add reminders or more service history to improve forecasts."
                    : "No upcoming costs detected yet.")
                    : "Scheduled items were found, but more matching service history is needed before showing cost estimates."
            } else if forecastFallbackCount > 0 {
                res.forecastConfidenceText = "Some scheduled items are not included in these totals yet because more matching service history is needed."
            } else if forecastItemCount < 2 {
                res.forecastConfidenceText = "Forecast is based on a small number of scheduled items."
            }
            
            // Fuel Engine
            res.lastValidTank = sortedFuel.first(where: { $0.isFullTank && $0.liters > 0 })
            let fullTanks = sortedFuel.filter { $0.isFullTank }
            if fullTanks.count >= 2 {
                var consumptions: [Double] = []
                for i in 0..<(fullTanks.count - 1) {
                    let recent = fullTanks[i]
                    let previous = fullTanks[i+1]
                    let dist = recent.mileage - previous.mileage
                    if dist > 0 && recent.liters > 0 {
                        consumptions.append((recent.liters / Double(dist)) * 100.0)
                    }
                }
                res.validFuelCycleCount = consumptions.count
                if !consumptions.isEmpty {
                    let recentWindow = Array(consumptions.prefix(min(3, consumptions.count)))
                    let recentAverage = recentWindow.reduce(0, +) / Double(recentWindow.count)
                    res.recentAverageConsumption = .ready(AppFormatters.consumption(recentAverage))
                    let chronologicalWindow = recentWindow.reversed()
                    res.fuelConsumptionPreviewPoints = Array(chronologicalWindow.enumerated()).map { index, value in
                        let isLatest = index == recentWindow.count - 1
                        return FuelConsumptionPreviewPoint(
                            label: isLatest ? "Latest" : "Cycle \(index + 1)",
                            value: value
                        )
                    }
                }
                if consumptions.count >= 3 {
                    let allTimeAverage = consumptions.reduce(0, +) / Double(consumptions.count)
                    res.allTimeAverageConsumption = .ready(AppFormatters.consumption(allTimeAverage))
                    let recentAverageValue = consumptions.prefix(min(3, consumptions.count)).reduce(0, +) / Double(min(3, consumptions.count))
                    let delta = allTimeAverage - recentAverageValue
                    if abs(delta) < 0.2 {
                        res.fuelPreviewInsightText = "Your long-term fuel trend is close to your recent average."
                    } else if delta > 0 {
                        res.fuelPreviewInsightText = "Your long-term fuel trend is slightly above your recent average."
                    } else {
                        res.fuelPreviewInsightText = "Your long-term fuel trend is slightly below your recent average."
                    }
                }
                if consumptions.count >= 3 {
                    res.threeTankAverageConsumption = .ready(AppFormatters.consumption(consumptions.prefix(3).reduce(0, +) / 3.0))
                }
                if consumptions.count >= 6 {
                    res.sixTankAverageConsumption = .ready(AppFormatters.consumption(consumptions.prefix(6).reduce(0, +) / 6.0))
                }
            }
            
            if totalFuel > 0 {
                let firstMil = sortedFuel.last?.mileage ?? 0
                let lastMil = sortedFuel.first?.mileage ?? 0
                let dist = lastMil - firstMil
                if dist > 0 {
                    res.costPer100Km = .ready(UnitFormatter.costPerDistanceCurrency((totalFuel / Double(dist)) * 100.0, currencyCode: currencyCode))
                }
                let totalLiters = sortedFuel.reduce(0) { $0 + $1.liters }
                if totalLiters > 0 {
                    res.averageFuelPrice = .ready(UnitFormatter.costPerFuelUnitCurrency(totalFuel / totalLiters, currencyCode: currencyCode))
                }
            }
            
            let last90FuelEntryCount = sortedFuel.filter { $0.date >= last90DaysStart && $0.date <= now }.count
            let previous90FuelEntryCount = sortedFuel.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.count

            if last90Fuel > 0 && prev90Fuel > 0 && last90FuelEntryCount >= 2 && previous90FuelEntryCount >= 2 {
                let diff = ((last90Fuel - prev90Fuel) / prev90Fuel) * 100
                if diff > 5 {
                    res.fuelSpendTrendText = "Fuel spend is up \(Int(diff))% vs previous 90 days."
                } else if diff < -5 {
                    res.fuelSpendTrendText = "Fuel spend is down \(Int(abs(diff)))% vs previous 90 days."
                } else {
                    res.fuelSpendTrendText = "Fuel spend has been stable recently."
                }
            } else if res.validFuelCycleCount >= 3, let recentAverage = res.recentAverageConsumption.readyValue {
                res.fuelSpendTrendText = "Recent average is \(recentAverage) based on valid full-to-full history."
            } else if res.validFuelCycleCount > 0 {
                res.fuelSpendTrendText = "Recent average is available, but long-term fuel trends need more valid fill-ups."
            } else if !sortedFuel.isEmpty {
                res.fuelSpendTrendText = "Add more full fill-ups to reveal fuel patterns."
            }

            if res.validFuelCycleCount >= 6 {
                res.fuelDataConfidenceText = "Based on \(res.validFuelCycleCount) valid full-to-full fill-up cycles."
            } else if res.validFuelCycleCount >= 3 {
                res.fuelDataConfidenceText = "Recent average uses the last 3 valid full-to-full fill-up cycles."
            } else if res.validFuelCycleCount > 0 {
                let cycleWord = res.validFuelCycleCount == 1 ? "cycle" : "cycles"
                res.fuelDataConfidenceText = "Based on \(res.validFuelCycleCount) valid fill-up \(cycleWord). More history improves reliability."
            } else {
                res.fuelDataConfidenceText = "Need more full fill-ups for a reliable consumption average."
            }
            
            // Maintenance Engine (Mapped to Component)
            let maintenanceServices = sortedServices.filter { $0.category == .maintenance || $0.category == .repair }
            res.maintenanceHistoryCount = maintenanceServices.count
            
            if maintenanceServices.count < 3 {
                res.maintenanceInsightText = "Log more services to improve alerts and predictions."
                res.maintenanceConfidenceText = "More service history is needed for reliable patterns."
            } else if maintenanceServices.count < 6 {
                res.maintenanceInsightText = "Insights improve with more service history."
                res.maintenanceConfidenceText = "Useful now, smarter with more history."
            } else {
                res.maintenanceInsightText = "Strong history — timing and prioritization are reliable."
                res.maintenanceConfidenceText = "Based on multiple maintenance events."
            }
            
            if !maintenanceServices.isEmpty {
                let groupedByComponent = Dictionary(grouping: maintenanceServices, by: { MaintenanceComponent.from(serviceType: $0.serviceType) })
                
                if let highest = groupedByComponent.max(by: { lhs, rhs in
                    lhs.value.reduce(0) { $0 + $1.price } < rhs.value.reduce(0) { $0 + $1.price }
                }) {
                    let total = highest.value.reduce(0) { $0 + $1.price }
                    res.mostExpensiveMaintenanceCategory = .ready("\(highest.key.rawValue) · \(AppFormatters.currency(total, code: currencyCode))")
                }
                
                let ascendingMaint = maintenanceServices.sorted { $0.date < $1.date }
                if ascendingMaint.count >= 2,
                   let first = ascendingMaint.first?.date,
                   let last = ascendingMaint.last?.date {
                    let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
                    let interval = max(0, days / (ascendingMaint.count - 1))
                    res.averageServiceIntervalDays = .ready("\(interval) days")
                }
                
                res.daysSinceLastOilChange = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.oilChange] ?? [], vehicleMileage: vehicleMileage, byDistance: false)
                res.distanceSinceLastBrakes = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.brakes] ?? [], vehicleMileage: vehicleMileage, byDistance: true)
                res.distanceSinceLastTires = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.tires] ?? [], vehicleMileage: vehicleMileage, byDistance: true)
                res.distanceSinceLastBattery = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.battery] ?? [], vehicleMileage: vehicleMileage, byDistance: true)

                let servicePreviewCandidates: [(title: String, state: MetricState<String>)] = [
                    ("Oil Change", res.daysSinceLastOilChange),
                    ("Brakes", res.distanceSinceLastBrakes),
                    ("Tires", res.distanceSinceLastTires),
                    ("Battery", res.distanceSinceLastBattery)
                ]

                if let candidate = servicePreviewCandidates.first(where: {
                    guard case .ready(let value) = $0.state else { return false }
                    return value.contains("Overdue") || value.contains("Due soon")
                }) ?? servicePreviewCandidates.first(where: {
                    if case .ready = $0.state { return true }
                    return false
                }) {
                    res.likelyDueNextItem = candidate.title
                    res.servicePreviewAvailable = maintenanceServices.count >= 3
                    res.servicePredictionPreviewTitle = "\(candidate.title) may need attention next"
                    res.servicePredictionPreviewText = "\(candidate.title) may need attention next based on your recent service intervals."
                    res.servicePredictionConfidenceText = "This is an estimate based on your logged maintenance history."
                }
            }
            
            // Garage Engine
            if !vehiclesData.isEmpty {
                var highestYearSpend: Double = 0
                var highestFuelSpend: Double = 0
                var latestService: (title: String, date: Date)? = nil
                res.garageVehicleCount = vehiclesData.count
                for v in vehiclesData {
                    let sTotal = v.services.reduce(0) { $0 + $1.price }
                    let fTotal = v.fuel.reduce(0) { $0 + $1.totalCost }
                    res.garageSpendByVehicle.append((v.title, sTotal + fTotal))
                    if (sTotal + fTotal) > 0, res.garageTopVehicleSummary == nil || (sTotal + fTotal) > (res.garageSpendByVehicle.first?.amount ?? 0) {
                        res.garageTopVehicleSummary = "\(v.title) · \(AppFormatters.currency(sTotal + fTotal, code: currencyCode))"
                    }
                    
                    let sYear = v.services.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.price }
                    let fYear = v.fuel.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.totalCost }
                    res.garageTotalSpendThisYear += sYear + fYear
                    if (sYear + fYear) > highestYearSpend {
                        highestYearSpend = sYear + fYear
                        res.costliestVehicleThisYear = v.title
                    }

                    if fTotal > highestFuelSpend {
                        highestFuelSpend = fTotal
                        res.garageHighestFuelSpendSummary = fTotal > 0 ? "\(v.title) · \(AppFormatters.currency(fTotal, code: currencyCode))" : nil
                    }

                    if let latestVehicleService = v.services.max(by: { $0.date < $1.date }) {
                        if latestService == nil || latestVehicleService.date > (latestService?.date ?? .distantPast) {
                            latestService = (v.title, latestVehicleService.date)
                        }
                    }
                    
                    let firstMil = min(v.services.min(by: { $0.mileage < $1.mileage })?.mileage ?? Int.max, v.fuel.min(by: { $0.mileage < $1.mileage })?.mileage ?? Int.max)
                    let lastMil = v.currentMileage
                    let dist = max(0, lastMil - (firstMil == Int.max ? 0 : firstMil))
                    
                    if dist > 500 && (sTotal + fTotal) > 0 {
                        res.costPerKmByVehicle.append((v.title, ((sTotal + fTotal) / Double(dist)) * 100.0))
                    }
                }
                res.garageSpendByVehicle.sort { $0.amount > $1.amount }
                res.costPerKmByVehicle.sort { $0.cost > $1.cost }
                if let first = res.garageSpendByVehicle.first {
                    res.garageTopVehicleSummary = "\(first.title) · \(AppFormatters.currency(first.amount, code: currencyCode))"
                }
                if let latestService {
                    res.garageLatestServiceSummary = "\(latestService.title) · \(AppFormatters.mediumDate.string(from: latestService.date))"
                }
                
                if let costliest = res.costliestVehicleThisYear {
                    res.garageIntelligenceText = "\(costliest) is your most expensive vehicle this year."
                } else {
                    res.garageIntelligenceText = "Add expenses to compare your fleet."
                }
            }
            
            // Resale Engine
            res.serviceRecordCount = sortedServices.count
            let servicesWithReceipts = sortedServices.filter { !$0.attachments.isEmpty }.count
            res.vaultDocumentCount = docs.count
            res.buyerSupportDocumentCount = docs.filter { $0.category.supportsBuyerConfidence }.count
            if sortedServices.count > 0 {
                res.receiptCoveragePercentage = (Double(servicesWithReceipts) / Double(sortedServices.count)) * 100.0
            }
            
            var score = 0
            if sortedServices.count > 3 { score += 30 } else if sortedServices.count > 0 { score += 10 }
            if res.receiptCoveragePercentage > 70 { score += 40 } else if res.receiptCoveragePercentage > 30 { score += 20 }
            if docs.count > 0 { score += 30 }
            
            res.resaleReadinessScore = min(100, score)
            
            if res.resaleReadinessScore >= 90 {
                res.resaleReadinessTier = "Buyer-Ready"
                res.resaleReadinessColor = AppTheme.accent
                res.resaleNextStepGuidance = "Your vehicle's history is highly complete."
            } else if res.resaleReadinessScore >= 70 {
                res.resaleReadinessTier = "Strong"
                res.resaleReadinessColor = AppTheme.accent.opacity(0.8)
                res.resaleNextStepGuidance = docs.isEmpty ? "Add registration or insurance documents." : "Attach remaining photos of receipts."
            } else if res.resaleReadinessScore >= 40 {
                res.resaleReadinessTier = "Fair"
                res.resaleReadinessColor = Color.orange
                res.resaleNextStepGuidance = "Improve receipt coverage to raise buyer readiness."
            } else {
                res.resaleReadinessTier = "Needs Work"
                res.resaleReadinessColor = Color.red
                res.resaleNextStepGuidance = "Add more service records to build a history."
            }

            if res.serviceRecordCount == 0 {
                res.resaleConfidenceText = "Add service history, receipts, and buyer-support documents to build resale confidence."
            } else if res.receiptCoveragePercentage < 50 {
                res.resaleConfidenceText = "Documents in Vault help, but service receipt coverage still carries the most resale weight."
            } else if res.buyerSupportDocumentCount == 0 {
                res.resaleConfidenceText = "Service history looks stronger when insurance, registration, or title documents are also stored."
            } else {
                res.resaleConfidenceText = "More supporting records improve buyer confidence and resale readiness."
            }

            res.resalePreviewAvailable = res.resaleReadinessScore >= 55
            if res.resalePreviewAvailable {
                var strengths: [String] = []
                if res.serviceRecordCount > 3 {
                    strengths.append("Your service history already shows repeated maintenance records.")
                }
                if res.receiptCoveragePercentage >= 70 {
                    strengths.append("Receipt coverage is strong enough to support buyer confidence.")
                } else if res.buyerSupportDocumentCount > 0 {
                    strengths.append("Buyer-supporting documents are already stored in your vault.")
                }
                res.resalePreviewStrengths = Array(strengths.prefix(2))

                if res.receiptCoveragePercentage < 70 {
                    res.resalePreviewWeakness = "Receipt coverage still leaves some gaps in the ownership story."
                } else if res.buyerSupportDocumentCount == 0 {
                    res.resalePreviewWeakness = "Buyer-supporting documents would make the resale story feel more complete."
                } else {
                    res.resalePreviewWeakness = "A few more supporting records would make the resale story even stronger."
                }

                res.resalePreviewSummary = "Your ownership record is starting to feel easier for a buyer to trust."
                res.resalePreviewConfidenceNote = "Preview based on your current buyer-ready score and supporting records."
            }
            
            return res
        }.value
        
        self.totalLifetimeSpend = result.totalLifetimeSpend
        self.thisYearSpend = result.thisYearSpend
        self.last12MonthsSpend = result.last12MonthsSpend
        self.averageMonthlyCost = result.averageMonthlyCost
        self.last90DaysSpend = result.last90DaysSpend
        self.previous90DaysSpend = result.previous90DaysSpend
        self.spendTrend90Days = result.spendTrend90Days
        self.financialSpendTrendText = result.financialSpendTrendText
        self.forecastConfidenceText = result.forecastConfidenceText
        self.spendingByYear = result.spendingByYear
        self.spendingByCategory = result.spendingByCategory
        self.financialCategoryInsight = result.financialCategoryInsight
        self.financePreviewTopCategories = result.financePreviewTopCategories
        self.financePreviewInsightText = result.financePreviewInsightText
        self.upcomingPlannedCost = result.upcomingPlannedCost
        self.upcomingPlannedCost3Months = result.upcomingPlannedCost3Months
        self.upcomingPlannedCost6Months = result.upcomingPlannedCost6Months
        self.forecastItems = result.forecastItems

        self.lastValidTank = result.lastValidTank
        self.recentAverageConsumption = result.recentAverageConsumption
        self.allTimeAverageConsumption = result.allTimeAverageConsumption
        self.threeTankAverageConsumption = result.threeTankAverageConsumption
        self.sixTankAverageConsumption = result.sixTankAverageConsumption
        self.costPer100Km = result.costPer100Km
        self.averageFuelPrice = result.averageFuelPrice
        self.fuelSpendTrendText = result.fuelSpendTrendText
        self.fuelDataConfidenceText = result.fuelDataConfidenceText
        self.validFuelCycleCount = result.validFuelCycleCount
        self.fuelConsumptionPreviewPoints = result.fuelConsumptionPreviewPoints
        self.fuelPreviewInsightText = result.fuelPreviewInsightText
        
        self.mostExpensiveMaintenanceCategory = result.mostExpensiveMaintenanceCategory
        self.averageServiceIntervalDays = result.averageServiceIntervalDays
        self.daysSinceLastOilChange = result.daysSinceLastOilChange
        self.distanceSinceLastBrakes = result.distanceSinceLastBrakes
        self.distanceSinceLastTires = result.distanceSinceLastTires
        self.distanceSinceLastBattery = result.distanceSinceLastBattery
        self.upcomingMaintenanceCount = result.upcomingMaintenanceCount
        self.overdueMaintenanceCount = result.overdueMaintenanceCount
        self.maintenanceHealthText = result.maintenanceHealthText
        self.maintenanceInsightText = result.maintenanceInsightText
        self.maintenanceConfidenceText = result.maintenanceConfidenceText
        self.policyReminderSummaryText = result.policyReminderSummaryText
        self.maintenanceHistoryCount = result.maintenanceHistoryCount
        self.servicePreviewAvailable = result.servicePreviewAvailable
        self.likelyDueNextItem = result.likelyDueNextItem
        self.servicePredictionPreviewTitle = result.servicePredictionPreviewTitle
        self.servicePredictionPreviewText = result.servicePredictionPreviewText
        self.servicePredictionConfidenceText = result.servicePredictionConfidenceText
        
        self.garageSpendByVehicle = result.garageSpendByVehicle
        self.costPerKmByVehicle = result.costPerKmByVehicle
        self.garageIntelligenceText = result.garageIntelligenceText
        self.garageVehicleCount = result.garageVehicleCount
        self.garageTotalSpendThisYear = result.garageTotalSpendThisYear
        self.garageTopVehicleSummary = result.garageTopVehicleSummary
        self.garageHighestFuelSpendSummary = result.garageHighestFuelSpendSummary
        self.garageLatestServiceSummary = result.garageLatestServiceSummary

        self.serviceRecordCount = result.serviceRecordCount
        self.receiptCoveragePercentage = result.receiptCoveragePercentage
        self.resaleReadinessScore = result.resaleReadinessScore
        self.resaleReadinessTier = result.resaleReadinessTier
        self.resaleReadinessColor = result.resaleReadinessColor
        self.resaleNextStepGuidance = result.resaleNextStepGuidance
        self.vaultDocumentCount = result.vaultDocumentCount
        self.buyerSupportDocumentCount = result.buyerSupportDocumentCount
        self.resaleConfidenceText = result.resaleConfidenceText
        self.resalePreviewAvailable = result.resalePreviewAvailable
        self.resalePreviewSummary = result.resalePreviewSummary
        self.resalePreviewStrengths = result.resalePreviewStrengths
        self.resalePreviewWeakness = result.resalePreviewWeakness
        self.resalePreviewConfidenceNote = result.resalePreviewConfidenceNote
    }
}

fileprivate struct ForecastItem: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let dueMileage: Int?
    let estimatedCost: Double?

    var dueDateDescription: String {
        if let date = dueDate {
            return AppFormatters.mediumDate.string(from: date)
        } else if let miles = dueMileage {
            return "At \(UnitFormatter.distance(Double(miles)))"
        }
        return "Upcoming"
    }
}

private struct IntelligenceResult {
    var totalLifetimeSpend: Double = 0
    var thisYearSpend: Double = 0
    var last12MonthsSpend: Double = 0
    var averageMonthlyCost: Double = 0
    var last90DaysSpend: Double = 0
    var previous90DaysSpend: Double = 0
    var spendTrend90Days: Double = 0
    var financialSpendTrendText: String = "Not enough data"
    var forecastConfidenceText: String? = nil
    var spendingByYear: [(year: Int, amount: Double)] = []
    var spendingByCategory: [(category: EntryCategory, amount: Double)] = []
    var financialCategoryInsight: String? = nil
    var financePreviewTopCategories: [(title: String, amount: Double)] = []
    var financePreviewInsightText: String? = nil
    var upcomingPlannedCost: Double = 0
    var upcomingPlannedCost3Months: Double = 0
    var upcomingPlannedCost6Months: Double = 0
    var forecastItems: [ForecastItem] = []

    var lastValidTank: FuelEntry? = nil
    var recentAverageConsumption: MetricState<String> = .notEnoughHistory("Need valid full fill-ups")
    var allTimeAverageConsumption: MetricState<String> = .notEnoughHistory("Long-term average needs more history")
    var threeTankAverageConsumption: MetricState<String> = .notEnoughHistory("Log 3 full fill-ups")
    var sixTankAverageConsumption: MetricState<String> = .notEnoughHistory("Log 6 full fill-ups")
    var costPer100Km: MetricState<String> = .notEnoughHistory("Not enough history")
    var averageFuelPrice: MetricState<String> = .notEnoughHistory("Not enough history")
    var fuelSpendTrendText: String = "Add more full fill-ups to reveal fuel patterns."
    var fuelDataConfidenceText: String = "Useful now, smarter over time."
    var validFuelCycleCount: Int = 0
    var fuelConsumptionPreviewPoints: [FuelConsumptionPreviewPoint] = []
    var fuelPreviewInsightText: String? = nil
    
    var mostExpensiveMaintenanceCategory: MetricState<String> = .neverRecorded
    var averageServiceIntervalDays: MetricState<String> = .notEnoughHistory("Log 2+ services")
    var daysSinceLastOilChange: MetricState<String> = .neverRecorded
    var distanceSinceLastBrakes: MetricState<String> = .neverRecorded
    var distanceSinceLastTires: MetricState<String> = .neverRecorded
    var distanceSinceLastBattery: MetricState<String> = .neverRecorded
    var upcomingMaintenanceCount: Int = 0
    var overdueMaintenanceCount: Int = 0
    var maintenanceHealthText: String = "Track upcoming service items and replacement history."
    var maintenanceInsightText: String = "Maintenance insights improve as you log more service history."
    var maintenanceConfidenceText: String = "Useful now, smarter over time."
    var policyReminderSummaryText: String? = nil
    var maintenanceHistoryCount: Int = 0
    var servicePreviewAvailable: Bool = false
    var likelyDueNextItem: String? = nil
    var servicePredictionPreviewTitle: String? = nil
    var servicePredictionPreviewText: String = "Available once more service history is logged."
    var servicePredictionConfidenceText: String? = nil
    
    var garageSpendByVehicle: [(title: String, amount: Double)] = []
    var costPerKmByVehicle: [(title: String, cost: Double)] = []
    var costliestVehicleThisYear: String? = nil
    var garageIntelligenceText: String = "Compare your multi-vehicle fleet."
    var garageVehicleCount: Int = 0
    var garageTotalSpendThisYear: Double = 0
    var garageTopVehicleSummary: String? = nil
    var garageHighestFuelSpendSummary: String? = nil
    var garageLatestServiceSummary: String? = nil
    
    var serviceRecordCount: Int = 0
    var receiptCoveragePercentage: Double = 0
    var resaleReadinessScore: Int = 0
    var resaleReadinessTier: String = "Needs Work"
    var resaleReadinessColor: Color = Color.orange
    var resaleNextStepGuidance: String = "A complete history improves resale value."
    var vaultDocumentCount: Int = 0
    var buyerSupportDocumentCount: Int = 0
    var resaleConfidenceText: String = "More supporting records improve buyer confidence."
    var resalePreviewAvailable: Bool = false
    var resalePreviewSummary: String = ""
    var resalePreviewStrengths: [String] = []
    var resalePreviewWeakness: String? = nil
    var resalePreviewConfidenceNote: String? = nil
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

private extension ServiceType {
    var countsTowardMaintenanceIntelligence: Bool {
        switch self {
        case .oilChange, .inspection, .tires, .brakes, .battery, .filters, .airConditioning, .repair:
            return true
        case .washDetailing, .registration, .insurance, .custom:
            return false
        }
    }

    var isPolicyReminder: Bool {
        switch self {
        case .registration, .insurance:
            return true
        default:
            return false
        }
    }
}

private extension DocumentVaultCategory {
    var supportsBuyerConfidence: Bool {
        switch self {
        case .insurance, .registration, .warranty, .inspection, .title, .roadside, .general:
            return true
        case .receipts:
            return false
        }
    }
}

// MARK: - Forecast Detail Sheet

private struct ForecastDetailSheet: View {
    let items: [ForecastItem]
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    Section {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(item.dueDateDescription)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(item.estimatedCost.map { AppFormatters.currency($0, code: vehicle.currencyCode) } ?? "Estimate pending")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(item.estimatedCost == nil ? AppTheme.tertiaryText : AppTheme.primaryText)
                                    if item.estimatedCost == nil {
                                        Text("need history")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Scheduled costs · next 12 months")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .textCase(nil)
                    } footer: {
                        Text("Amounts are based on your matching service history. Items marked \"Estimate pending\" need more history before a cost can be shown.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Forecast Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
