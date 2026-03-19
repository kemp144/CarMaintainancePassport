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
        }
    }
    
    // MARK: - Financials Tab
    private var financialsTab: some View {
        VStack(spacing: 16) {
            SurfaceCard(tier: .primary) {
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
            
            HStack(spacing: 12) {
                InsightTile(title: "This Year", state: .ready(AppFormatters.currency(viewModel.thisYearSpend, code: vehicle.currencyCode)), icon: "calendar")
                InsightTile(title: "Last 12 Months", state: .ready(AppFormatters.currency(viewModel.last12MonthsSpend, code: vehicle.currencyCode)), icon: "clock.arrow.circlepath")
            }

            SurfaceCard(tier: .primary) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ownership Forecast")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        
                    if viewModel.upcomingPlannedCost == 0 {
                        Text("No planned costs detected")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Next 3 Mo")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text(AppFormatters.currency(viewModel.upcomingPlannedCost3Months, code: vehicle.currencyCode))
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Next 6 Mo")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text(AppFormatters.currency(viewModel.upcomingPlannedCost6Months, code: vehicle.currencyCode))
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Next 12 Mo")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text(AppFormatters.currency(viewModel.upcomingPlannedCost, code: vehicle.currencyCode))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    if let forecastConfidenceText = viewModel.forecastConfidenceText {
                        DataConfidenceFootnote(message: forecastConfidenceText)
                            .padding(.top, 2)
                    }
                }
            }

            if hasAdvancedInsights {
                SurfaceCard {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 40, height: 40)
                            Image(systemName: viewModel.spendTrend90Days > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                                .foregroundStyle(viewModel.spendTrend90Days > 0 ? Color.orange : AppTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("90-Day Trend")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(viewModel.financialSpendTrendText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                }

                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending by Year")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        if viewModel.spendingByYear.isEmpty {
                            Text("Not enough history")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(height: 180)
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
                            .frame(height: 180)
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
                                    .padding(.vertical, 8)

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
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
            } else {
                LockedInsightCard(
                    title: "Full cost breakdown",
                    message: "Understand where your money goes and spot the patterns that quietly raise ownership costs.",
                    highlights: [
                        "Spending trends over time",
                        "Category-by-category totals",
                        "Hidden cost detection"
                    ],
                    ctaTitle: "Unlock Pro",
                    previewText: financePreviewText
                ) {
                    paywallCoordinator.present(.analytics)
                }
            }
        }
    }
    
    // MARK: - Maintenance Tab
    private var maintenanceTab: some View {
        VStack(spacing: 16) {
            SurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 40, height: 40)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service Health")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        Text(viewModel.maintenanceHealthText)
                            .font(.subheadline)
                            .foregroundStyle(viewModel.overdueMaintenanceCount > 0 ? Color.red : AppTheme.secondaryText)
                    }
                    Spacer()
                }
            }
            
            HStack(spacing: 12) {
                InsightTile(title: "Due Soon", state: .ready("\(viewModel.upcomingMaintenanceCount)"), icon: "clock.badge.exclamationmark.fill")
                InsightTile(title: "Overdue", state: .ready("\(viewModel.overdueMaintenanceCount)"), icon: "exclamationmark.circle.fill")
            }

            SurfaceCard(tier: .primary) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(hasAdvancedInsights ? "Maintenance Tracking" : "Basic Tracking")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(hasAdvancedInsights
                         ? "Maintenance health focuses on service items only. Insurance and registration reminders stay separate so status stays clear."
                         : "Keep an eye on the essentials. Free gives you core status tracking, while Pro adds predictions, prioritization, and deeper patterns.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(spacing: 12) {
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

            if let policyReminderSummaryText = viewModel.policyReminderSummaryText {
                SurfaceCard(tier: .compact) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Policy reminders")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(policyReminderSummaryText)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }

            if hasAdvancedInsights {
                HStack(spacing: 12) {
                    InsightTile(title: "Average Interval", state: viewModel.averageServiceIntervalDays, icon: "clock.arrow.2.circlepath")
                    InsightTile(title: "Highest Cost Category", state: viewModel.mostExpensiveMaintenanceCategory, icon: "exclamationmark.triangle.fill")
                }

                DataConfidenceFootnote(message: viewModel.maintenanceConfidenceText)
                    .padding(.horizontal, 2)

                Text(viewModel.maintenanceInsightText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                DataConfidenceFootnote(message: viewModel.maintenanceConfidenceText)
                    .padding(.horizontal, 2)

                LockedInsightCard(
                    title: "Smarter maintenance tracking",
                    message: "Know what is likely due next before a routine service turns into an expensive surprise.",
                    highlights: [
                        "Replacement predictions",
                        "Smarter due-soon prioritization",
                        "Maintenance trends over time"
                    ],
                    ctaTitle: "Unlock Pro",
                    previewText: maintenancePreviewText
                ) {
                    paywallCoordinator.present(.analytics)
                }
            }
        }
    }
    
    // MARK: - Fuel Tab
    private var fuelTab: some View {
        VStack(spacing: 16) {
            SurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 40, height: 40)
                        Image(systemName: "fuelpump.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fuel Intelligence")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        Text(viewModel.fuelSpendTrendText)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
            
            HStack(spacing: 12) {
                InsightTile(title: "Average Fuel Price", state: viewModel.averageFuelPrice, icon: "dollarsign.circle")
                InsightTile(title: "Recent Avg (Up to 3 valid fill-ups)", state: viewModel.recentAverageConsumption, icon: "gauge.medium")
            }

            if let last = viewModel.lastValidTank {
                SurfaceCard(tier: .primary) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last Valid Fill-up")
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
                .padding(.horizontal, 2)

            if hasAdvancedInsights {
                HStack(spacing: 12) {
                    InsightTile(title: "All-Time Avg (Valid fill-ups)", state: viewModel.allTimeAverageConsumption, icon: "chart.line.uptrend.xyaxis")
                    InsightTile(title: "Fuel Cost / 100 km", state: viewModel.costPer100Km, icon: "road.lanes")
                }
            } else {
                LockedInsightCard(
                    title: "See your real fuel efficiency",
                    message: "Start with the basics for free, then track the long-term patterns that actually reveal how your car is performing.",
                    highlights: [
                        "Long-term average consumption",
                        "Trend chart across fill-ups",
                        "Efficiency score"
                    ],
                    ctaTitle: "Unlock Pro",
                    previewText: fuelPreviewText
                ) {
                    paywallCoordinator.present(.fuelTracking)
                }
            }
        }
    }
    
    // MARK: - Resale Tab
    private var resaleTab: some View {
        VStack(spacing: 16) {
            SurfaceCard(tier: .primary) {
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
            
            HStack(spacing: 12) {
                InsightTile(title: "Service Records", state: .ready("\(viewModel.serviceRecordCount)"), icon: "doc.text.fill")
                InsightTile(title: "Service Receipt Coverage", state: .ready(String(format: "%.0f%%", viewModel.receiptCoveragePercentage)), icon: "paperclip")
            }

            HStack(spacing: 12) {
                InsightTile(title: "Buyer Support Docs", state: .ready("\(viewModel.buyerSupportDocumentCount)"), icon: "text.book.closed.fill")
                InsightTile(title: "Documents in Vault", state: .ready("\(viewModel.vaultDocumentCount)"), icon: "doc.on.doc.fill")
            }
            
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Checklist")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        
                    ChecklistItem(title: "More than 3 service records", isComplete: viewModel.serviceRecordCount > 3)
                    ChecklistItem(title: "Over 70% service receipt coverage", isComplete: viewModel.receiptCoveragePercentage > 70)
                    ChecklistItem(title: "Buyer support documents in Vault", isComplete: viewModel.buyerSupportDocumentCount > 0)
                }
            }

            DataConfidenceFootnote(message: viewModel.resaleConfidenceText)
                .padding(.horizontal, 2)

            if !hasAdvancedInsights {
                LockedInsightCard(
                    title: "Resale insights",
                    message: "Know what strengthens buyer confidence before you decide to sell.",
                    highlights: [
                        "Estimated market value",
                        "Buyer-ready PDF report",
                        "What reduces your resale price"
                    ],
                    ctaTitle: "Unlock Pro",
                    previewText: resalePreviewText
                ) {
                    paywallCoordinator.present(.analytics)
                }
            }
        }
    }
    
    // MARK: - Garage Tab
    private var garageTab: some View {
        VStack(spacing: 16) {
            SurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 40, height: 40)
                        Image(systemName: "car.2.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Garage Intelligence")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        
                        Text(viewModel.garageIntelligenceText)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                InsightTile(title: "Vehicles in Garage", state: .ready("\(viewModel.garageVehicleCount)"), icon: "car.2.fill")
                InsightTile(title: "Garage Spend This Year", state: .ready(AppFormatters.currency(viewModel.garageTotalSpendThisYear, code: vehicle.currencyCode)), icon: "calendar")
            }

            SurfaceCard(tier: .primary) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Garage Snapshot")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    AnalyticsDetailRow(
                        title: "Top vehicle by total cost",
                        value: viewModel.garageTopVehicleSummary ?? "Add more tracked costs to compare your garage."
                    )
                    Divider().overlay(AppTheme.separator)
                    AnalyticsDetailRow(
                        title: "Highest fuel spend",
                        value: viewModel.garageHighestFuelSpendSummary ?? "Log fuel across vehicles to compare spend."
                    )
                    Divider().overlay(AppTheme.separator)
                    AnalyticsDetailRow(
                        title: "Latest serviced vehicle",
                        value: viewModel.garageLatestServiceSummary ?? "Add service records to build a garage timeline."
                    )
                }
            }

            if allVehicles.count == 1 {
                DataConfidenceFootnote(message: "Add another vehicle to unlock side-by-side ownership comparisons across your garage.")
                    .padding(.horizontal, 2)
            }

            if hasAdvancedInsights {
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
                                    .padding(.vertical, 8)

                                    if index < viewModel.costPerKmByVehicle.count - 1 {
                                        Divider().overlay(AppTheme.separator)
                                    }
                                }
                            }
                        }
                    }
                } else if allVehicles.count > 0 {
                    SurfaceCard(tier: .primary) {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "road.lanes")
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.tertiaryText)
                            Text("Not enough distance data")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Log more fuel and service entries with accurate mileage across your garage to unlock cost-per-distance insights.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
            } else {
                LockedInsightCard(
                    title: "Compare your garage side by side",
                    message: "Track every car in one calm place and instantly see which vehicle costs the most to own.",
                    highlights: [
                        "Spend by vehicle",
                        "Cost per distance across the garage",
                        "Multi-car ownership comparisons"
                    ],
                    ctaTitle: "Unlock Pro",
                    previewText: garagePreviewText
                ) {
                    paywallCoordinator.present(.secondVehicle)
                }
            }
        }
    }

    private var financePreviewText: String? {
        if viewModel.spendingByCategory.isEmpty {
            return "Log more service history to reveal cost patterns."
        }

        if let insight = viewModel.financialCategoryInsight {
            return insight
        }

        guard viewModel.totalLifetimeSpend > 0 else { return nil }
        return "You have logged \(AppFormatters.currency(viewModel.totalLifetimeSpend, code: vehicle.currencyCode)) so far."
    }

    private var maintenancePreviewText: String? {
        if viewModel.overdueMaintenanceCount > 0 || viewModel.upcomingMaintenanceCount > 0 {
            return viewModel.maintenanceHealthText
        }

        if let category = viewModel.mostExpensiveMaintenanceCategory.readyValue {
            return "Highest service cost so far: \(category)"
        }

        return viewModel.maintenanceInsightText
    }

    private var fuelPreviewText: String? {
        if let average = viewModel.recentAverageConsumption.readyValue {
            return "Recent average: \(average)"
        }

        if let note = viewModel.recentAverageConsumption.placeholderText {
            return note
        }

        return nil
    }

    private var resalePreviewText: String? {
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
}

// MARK: - Reusable Components

struct InsightTile: View {
    let title: String
    let state: MetricState<String>
    let icon: String
    
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                switch state {
                case .ready(let value):
                    Text(value)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(2)
                case .neverRecorded:
                    Text("No recent record")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate only")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72, alignment: .topLeading)
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
            Spacer()
            
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
                Text("No recent record")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
            case .incompleteRecord:
                Text("Estimate only")
                    .font(.subheadline)
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
            return "No recent record found."
        case .incompleteRecord:
            return "Estimate only until more history is logged."
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
    
    // Fuel Intelligence
    @Published var lastValidTank: FuelEntry?
    @Published var recentAverageConsumption: MetricState<String> = .notEnoughHistory("Need valid full fill-ups")
    @Published var allTimeAverageConsumption: MetricState<String> = .notEnoughHistory("Long-term average needs more history")
    @Published var threeTankAverageConsumption: MetricState<String> = .notEnoughHistory("Requires 3 valid fill-ups")
    @Published var sixTankAverageConsumption: MetricState<String> = .notEnoughHistory("Requires 6 valid fill-ups")
    @Published var costPer100Km: MetricState<String> = .notEnoughHistory("Not enough history")
    @Published var averageFuelPrice: MetricState<String> = .notEnoughHistory("Not enough history")
    @Published var fuelSpendTrendText: String = "Add more full fill-ups to reveal fuel patterns."
    @Published var fuelDataConfidenceText: String = "Useful now, smarter over time."
    @Published var validFuelCycleCount: Int = 0
    
    // Maintenance Intelligence
    @Published var mostExpensiveMaintenanceCategory: MetricState<String> = .neverRecorded
    @Published var averageServiceIntervalDays: MetricState<String> = .notEnoughHistory("Needs 2+ services")
    @Published var daysSinceLastOilChange: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastBrakes: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastTires: MetricState<String> = .neverRecorded
    @Published var distanceSinceLastBattery: MetricState<String> = .neverRecorded
    @Published var upcomingMaintenanceCount: Int = 0
    @Published var overdueMaintenanceCount: Int = 0
    @Published var maintenanceHealthText: String = "All maintenance is up to date."
    @Published var maintenanceInsightText: String = "Maintenance insights improve as you log more service history."
    @Published var maintenanceConfidenceText: String = "Useful now, smarter over time."
    @Published var policyReminderSummaryText: String? = nil

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
            return .notEnoughHistory("Tracking needs more history")
        }
        
        let sorted = validItems.sorted { byDistance ? $0.mileage < $1.mileage : $0.date < $1.date }
        let first = sorted.first!
        let last = sorted.last!
        
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
                        let avg: Double
                        if relatedServices.isEmpty {
                            avg = 100.0
                            forecastFallbackCount += 1
                        } else {
                            avg = relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        }
                        forecastItemCount += 1
                        res.upcomingPlannedCost += avg
                        if due <= sixMonthsFromNow {
                            res.upcomingPlannedCost6Months += avg
                            if isMaintenanceReminder {
                                res.upcomingMaintenanceCount += 1
                                upcomingMaintenanceReminders.append(reminder)
                            }
                        }
                        if due <= threeMonthsFromNow {
                            res.upcomingPlannedCost3Months += avg
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
                        let avg: Double
                        if relatedServices.isEmpty {
                            avg = 100.0
                            forecastFallbackCount += 1
                        } else {
                            avg = relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        }
                        forecastItemCount += 1
                        res.upcomingPlannedCost += avg
                        
                        if milDue - vehicleMileage <= 2500 {
                            res.upcomingPlannedCost6Months += avg
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

            if res.upcomingPlannedCost == 0 {
                res.forecastConfidenceText = reminders.isEmpty
                    ? "Add reminders or more service history to improve forecasts."
                    : "No upcoming costs detected yet."
            } else if forecastFallbackCount > 0 {
                res.forecastConfidenceText = "Some upcoming costs are estimate-only until more history is logged."
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
                }
                if consumptions.count >= 4 {
                    let allTimeAverage = consumptions.reduce(0, +) / Double(consumptions.count)
                    res.allTimeAverageConsumption = .ready(AppFormatters.consumption(allTimeAverage))
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
            
            if maintenanceServices.count < 3 {
                res.maintenanceInsightText = "Add more maintenance records to improve status tracking, due-soon alerts, and replacement insights."
                res.maintenanceConfidenceText = "Tracking needs more history before maintenance patterns become reliable."
            } else if maintenanceServices.count < 6 {
                res.maintenanceInsightText = "Maintenance insights improve as you log more service history."
                res.maintenanceConfidenceText = "Useful now, smarter with a little more service history."
            } else {
                res.maintenanceInsightText = "More service history improves maintenance timing and prioritization."
                res.maintenanceConfidenceText = "Based on repeat service history across multiple maintenance events."
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
                if ascendingMaint.count >= 2 {
                    let first = ascendingMaint.first!.date
                    let last = ascendingMaint.last!.date
                    let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
                    let interval = max(0, days / (ascendingMaint.count - 1))
                    res.averageServiceIntervalDays = .ready("\(interval) days")
                }
                
                res.daysSinceLastOilChange = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.oilChange] ?? [], vehicleMileage: vehicleMileage, byDistance: false)
                res.distanceSinceLastBrakes = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.brakes] ?? [], vehicleMileage: vehicleMileage, byDistance: true)
                res.distanceSinceLastTires = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.tires] ?? [], vehicleMileage: vehicleMileage, byDistance: true)
                res.distanceSinceLastBattery = VehicleIntelligenceViewModel.evaluateHealth(items: groupedByComponent[.battery] ?? [], vehicleMileage: vehicleMileage, byDistance: true)
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
                        if latestService == nil || latestVehicleService.date > latestService!.date {
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
        self.upcomingPlannedCost = result.upcomingPlannedCost
        self.upcomingPlannedCost3Months = result.upcomingPlannedCost3Months
        self.upcomingPlannedCost6Months = result.upcomingPlannedCost6Months
        
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
    var upcomingPlannedCost: Double = 0
    var upcomingPlannedCost3Months: Double = 0
    var upcomingPlannedCost6Months: Double = 0
    
    var lastValidTank: FuelEntry? = nil
    var recentAverageConsumption: MetricState<String> = .notEnoughHistory("Need valid full fill-ups")
    var allTimeAverageConsumption: MetricState<String> = .notEnoughHistory("Long-term average needs more history")
    var threeTankAverageConsumption: MetricState<String> = .notEnoughHistory("Requires 3 valid fill-ups")
    var sixTankAverageConsumption: MetricState<String> = .notEnoughHistory("Requires 6 valid fill-ups")
    var costPer100Km: MetricState<String> = .notEnoughHistory("Not enough history")
    var averageFuelPrice: MetricState<String> = .notEnoughHistory("Not enough history")
    var fuelSpendTrendText: String = "Add more full fill-ups to reveal fuel patterns."
    var fuelDataConfidenceText: String = "Useful now, smarter over time."
    var validFuelCycleCount: Int = 0
    
    var mostExpensiveMaintenanceCategory: MetricState<String> = .neverRecorded
    var averageServiceIntervalDays: MetricState<String> = .notEnoughHistory("Needs 2+ services")
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
