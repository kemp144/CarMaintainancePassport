import Charts
import SwiftData
import SwiftUI

struct VehicleAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    
    @Query private var allVehicles: [Vehicle]
    
    @StateObject private var viewModel: VehicleIntelligenceViewModel
    @State private var selectedTab: AnalyticsTab = .financials
    
    enum AnalyticsTab: String, CaseIterable, Identifiable {
        case financials = "Finance"
        case maintenance = "Maint"
        case fuel = "Fuel"
        case resale = "Resale"
        case garage = "Garage"
        var id: String { rawValue }
    }
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        self._viewModel = StateObject(wrappedValue: VehicleIntelligenceViewModel(vehicle: vehicle))
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
                        case .maintenance:
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
        .task {
            await viewModel.calculateIntelligence(allVehicles: allVehicles)
        }
    }
    
    // MARK: - Financials Tab
    private var financialsTab: some View {
        VStack(spacing: 16) {
            SurfaceCard(tier: .primary) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL LIFETIME SPEND")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(AppFormatters.currency(viewModel.totalLifetimeSpend, code: vehicle.currencyCode))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                InsightTile(title: "This Year", value: AppFormatters.currency(viewModel.thisYearSpend, code: vehicle.currencyCode), icon: "calendar")
                InsightTile(title: "Last 12 Mo", value: AppFormatters.currency(viewModel.last12MonthsSpend, code: vehicle.currencyCode), icon: "clock.arrow.circlepath")
            }
            
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
                    Text("Ownership Forecast")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        
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
                    }
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
                        Text("Maintenance Health")
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
                if let interval = viewModel.averageServiceIntervalDays {
                    InsightTile(title: "Avg Interval", value: "\(interval) days", icon: "clock.arrow.2.circlepath")
                } else {
                    InsightTile(title: "Avg Interval", value: "--", icon: "clock.arrow.2.circlepath")
                }
                
                InsightTile(title: "Highest Cost", value: viewModel.mostExpensiveMaintenanceCategory ?? "No data", icon: "exclamationmark.triangle.fill")
            }
            
            SurfaceCard(tier: .primary) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Wear & Tear Status")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    
                    VStack(spacing: 12) {
                        wearAndTearRow(title: "Oil Change", value: viewModel.daysSinceLastOilChange.map { "\($0) days ago" } ?? "Never recorded")
                        Divider().overlay(AppTheme.separator)
                        wearAndTearRow(title: "Brakes", value: viewModel.distanceSinceLastBrakes.map { "\(AppFormatters.mileage($0)) ago" } ?? "Never recorded")
                        Divider().overlay(AppTheme.separator)
                        wearAndTearRow(title: "Tires", value: viewModel.distanceSinceLastTires.map { "\(AppFormatters.mileage($0)) ago" } ?? "Never recorded")
                        Divider().overlay(AppTheme.separator)
                        wearAndTearRow(title: "Battery", value: viewModel.distanceSinceLastBattery.map { "\(AppFormatters.mileage($0)) ago" } ?? "Never recorded")
                    }
                }
            }
        }
    }
    
    private func wearAndTearRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
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
                    }
                    Spacer()
                }
            }
            
            HStack(spacing: 12) {
                if let cp100 = viewModel.costPer100Km {
                    InsightTile(title: UnitSettings.currentDistanceUnit == .miles ? "Cost / 100 mi" : "Cost / 100 km", value: UnitFormatter.costPerDistanceCurrency(cp100, currencyCode: vehicle.currencyCode), icon: "road.lanes")
                } else {
                    InsightTile(title: UnitSettings.currentDistanceUnit == .miles ? "Cost / 100 mi" : "Cost / 100 km", value: "--", icon: "road.lanes")
                }
                
                if let avgP = viewModel.averageFuelPrice {
                    InsightTile(title: "Avg Price", value: UnitFormatter.costPerFuelUnitCurrency(avgP, currencyCode: vehicle.currencyCode), icon: "dollarsign.circle")
                } else {
                    InsightTile(title: "Avg Price", value: "--", icon: "dollarsign.circle")
                }
            }
            
            HStack(spacing: 12) {
                if let t3 = viewModel.threeTankAverageConsumption {
                    InsightTile(title: "3-Tank Avg", value: AppFormatters.consumption(t3), icon: "gauge.medium")
                } else {
                    InsightTile(title: "3-Tank Avg", value: "--", icon: "gauge.medium")
                }
                
                if let t6 = viewModel.sixTankAverageConsumption {
                    InsightTile(title: "6-Tank Avg", value: AppFormatters.consumption(t6), icon: "gauge.high")
                } else {
                    InsightTile(title: "6-Tank Avg", value: "--", icon: "gauge.high")
                }
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
                                .stroke(viewModel.resaleReadinessScore > 70 ? AppTheme.accent : Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                
                            Text("\(viewModel.resaleReadinessScore)%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.resaleReadinessScore > 70 ? "Excellent" : (viewModel.resaleReadinessScore > 40 ? "Good" : "Needs Work"))
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
                InsightTile(title: "Service Records", value: "\(viewModel.serviceRecordCount)", icon: "doc.text.fill")
                InsightTile(title: "Receipt Coverage", value: String(format: "%.0f%%", viewModel.receiptCoveragePercentage), icon: "paperclip")
            }
            
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Checklist")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        
                    ChecklistItem(title: "More than 3 service records", isComplete: viewModel.serviceRecordCount > 3)
                    ChecklistItem(title: "Over 70% receipt coverage", isComplete: viewModel.receiptCoveragePercentage > 70)
                    ChecklistItem(title: "Registration or documents in Vault", isComplete: vehicle.documents.count > 0)
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
        }
    }
}

// MARK: - Reusable Components

struct InsightTile: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // Breakdown
    @Published var spendingByYear: [(year: Int, amount: Double)] = []
    @Published var spendingByCategory: [(category: EntryCategory, amount: Double)] = []
    
    // Fuel Intelligence
    @Published var lastValidTank: FuelEntry?
    @Published var threeTankAverageConsumption: Double?
    @Published var sixTankAverageConsumption: Double?
    @Published var costPer100Km: Double?
    @Published var averageFuelPrice: Double?
    @Published var fuelSpendTrendText: String = "Not enough data to calculate fuel trends."
    
    // Maintenance Intelligence
    @Published var mostExpensiveMaintenanceCategory: String?
    @Published var averageServiceIntervalDays: Int?
    @Published var daysSinceLastOilChange: Int?
    @Published var distanceSinceLastBrakes: Int?
    @Published var distanceSinceLastTires: Int?
    @Published var distanceSinceLastBattery: Int?
    @Published var upcomingMaintenanceCount: Int = 0
    @Published var overdueMaintenanceCount: Int = 0
    @Published var maintenanceHealthText: String = "All maintenance is up to date."

    // Garage Intelligence
    @Published var garageSpendByVehicle: [(title: String, amount: Double)] = []
    @Published var garageFuelSpendByVehicle: [(title: String, amount: Double)] = []
    @Published var costliestVehicleThisYear: String?
    @Published var costPerKmByVehicle: [(title: String, cost: Double)] = []
    @Published var garageIntelligenceText: String = "Compare your multi-vehicle fleet."

    // Resale Readiness
    @Published var serviceRecordCount: Int = 0
    @Published var receiptCoveragePercentage: Double = 0
    @Published var resaleReadinessScore: Int = 0
    @Published var resaleNextStepGuidance: String = "A complete history improves resale value."

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
    }
    
    func calculateIntelligence(allVehicles: [Vehicle] = []) async {
        let sortedServices = vehicle.serviceEntries.sorted { $0.date > $1.date }
        let sortedFuel = vehicle.fuelEntries.sorted { $0.date > $1.date }
        let reminders = vehicle.reminders
        let docs = vehicle.documents
        let vehicleMileage = vehicle.currentMileage
        
        let now = Date()
        let calendar = Calendar.current
        
        let vehiclesData = allVehicles.map { v in
            (title: v.title, currentMileage: v.currentMileage, services: v.serviceEntries, fuel: v.fuelEntries)
        }
        
        let result = await Task.detached { () -> IntelligenceResult in
            var res = IntelligenceResult()
            
            let totalService = sortedServices.reduce(0) { $0 + $1.price }
            let totalFuel = sortedFuel.reduce(0) { $0 + $1.totalCost }
            res.totalLifetimeSpend = totalService + totalFuel
            
            let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? .distantPast
            res.thisYearSpend = sortedServices.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.price } +
                                sortedFuel.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.totalCost }
            
            let last12MonthsStart = calendar.date(byAdding: .month, value: -12, to: now) ?? .distantPast
            res.last12MonthsSpend = sortedServices.filter { $0.date >= last12MonthsStart }.reduce(0) { $0 + $1.price } +
                                    sortedFuel.filter { $0.date >= last12MonthsStart }.reduce(0) { $0 + $1.totalCost }
            
            let earliestService = sortedServices.last?.date
            let earliestFuel = sortedFuel.last?.date
            var firstDate = now
            if let es = earliestService, let ef = earliestFuel {
                firstDate = min(es, ef)
            } else if let es = earliestService {
                firstDate = es
            } else if let ef = earliestFuel {
                firstDate = ef
            }
            let components = calendar.dateComponents([.month], from: firstDate, to: now)
            let monthsOwned = max(1, components.month ?? 1)
            res.averageMonthlyCost = res.totalLifetimeSpend / Double(monthsOwned)
            
            let last90DaysStart = calendar.date(byAdding: .day, value: -90, to: now) ?? .distantPast
            let previous90DaysStart = calendar.date(byAdding: .day, value: -180, to: now) ?? .distantPast
            
            let last90Service = sortedServices.filter { $0.date >= last90DaysStart && $0.date <= now }.reduce(0) { $0 + $1.price }
            let last90Fuel = sortedFuel.filter { $0.date >= last90DaysStart && $0.date <= now }.reduce(0) { $0 + $1.totalCost }
            res.last90DaysSpend = last90Service + last90Fuel
            
            let prev90Service = sortedServices.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.reduce(0) { $0 + $1.price }
            let prev90Fuel = sortedFuel.filter { $0.date >= previous90DaysStart && $0.date < last90DaysStart }.reduce(0) { $0 + $1.totalCost }
            res.previous90DaysSpend = prev90Service + prev90Fuel
            
            if res.previous90DaysSpend > 0 {
                res.spendTrend90Days = ((res.last90DaysSpend - res.previous90DaysSpend) / res.previous90DaysSpend) * 100.0
                let direction = res.spendTrend90Days > 0 ? "up" : "down"
                res.financialSpendTrendText = "Spending is \(direction) \(abs(Int(res.spendTrend90Days)))% vs previous 90 days."
            } else if res.last90DaysSpend > 0 {
                res.spendTrend90Days = 100.0
                res.financialSpendTrendText = "Spending is up vs previous 90 days."
            } else {
                res.financialSpendTrendText = "Not enough data to calculate spending trends."
            }
            
            let groupedByYear = Dictionary(grouping: sortedServices) { calendar.component(.year, from: $0.date) }
            res.spendingByYear = groupedByYear.map { (year: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
                .sorted { $0.year < $1.year }
            
            let groupedByCategory = Dictionary(grouping: sortedServices) { $0.category }
            res.spendingByCategory = groupedByCategory.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.price }) }
                .sorted { $0.amount > $1.amount }
                
            let threeMonthsFromNow = calendar.date(byAdding: .month, value: 3, to: now) ?? now
            let sixMonthsFromNow = calendar.date(byAdding: .month, value: 6, to: now) ?? now
            let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: now) ?? now
            
            var expectedCost3M: Double = 0
            var expectedCost6M: Double = 0
            var expectedCost12M: Double = 0
            
            for reminder in reminders where reminder.isEnabled {
                if let due = reminder.dateDue {
                    if due >= now && due <= oneYearFromNow {
                        let relatedServices = sortedServices.filter { $0.serviceType.rawValue == reminder.typeRaw }
                        let avg = relatedServices.isEmpty ? 100.0 : relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        expectedCost12M += avg
                        if due <= sixMonthsFromNow {
                            expectedCost6M += avg
                            res.upcomingMaintenanceCount += 1
                        }
                        if due <= threeMonthsFromNow {
                            expectedCost3M += avg
                        }
                    }
                    if due < now.startOfDay {
                        res.overdueMaintenanceCount += 1
                    }
                } else if let milDue = reminder.mileageDue {
                    if vehicleMileage >= milDue {
                        res.overdueMaintenanceCount += 1
                    } else if milDue - vehicleMileage <= 5000 {
                        let relatedServices = sortedServices.filter { $0.serviceType.rawValue == reminder.typeRaw }
                        let avg = relatedServices.isEmpty ? 100.0 : relatedServices.reduce(0) { $0 + $1.price } / Double(relatedServices.count)
                        expectedCost12M += avg
                        
                        if milDue - vehicleMileage <= 2500 {
                            expectedCost6M += avg
                            res.upcomingMaintenanceCount += 1
                        }
                    }
                }
            }
            res.upcomingPlannedCost = expectedCost12M
            res.upcomingPlannedCost6Months = expectedCost6M
            res.upcomingPlannedCost3Months = expectedCost3M
            
            if res.overdueMaintenanceCount > 0 {
                res.maintenanceHealthText = "You have \(res.overdueMaintenanceCount) overdue items requiring attention."
            } else if res.upcomingMaintenanceCount > 0 {
                res.maintenanceHealthText = "\(res.upcomingMaintenanceCount) maintenance items are due in the next 6 months."
            } else {
                res.maintenanceHealthText = "All maintenance is currently up to date."
            }
            
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
                if consumptions.count >= 3 {
                    res.threeTankAverageConsumption = consumptions.prefix(3).reduce(0, +) / 3.0
                }
                if consumptions.count >= 6 {
                    res.sixTankAverageConsumption = consumptions.prefix(6).reduce(0, +) / 6.0
                }
            }
            
            if totalFuel > 0 {
                let firstMil = sortedFuel.last?.mileage ?? 0
                let lastMil = sortedFuel.first?.mileage ?? 0
                let dist = lastMil - firstMil
                if dist > 0 {
                    res.costPer100Km = (totalFuel / Double(dist)) * 100.0
                }
                let totalLiters = sortedFuel.reduce(0) { $0 + $1.liters }
                if totalLiters > 0 {
                    res.averageFuelPrice = totalFuel / totalLiters
                }
            }
            
            if last90Fuel > 0 && prev90Fuel > 0 {
                let diff = ((last90Fuel - prev90Fuel) / prev90Fuel) * 100
                if diff > 5 {
                    res.fuelSpendTrendText = "Fuel spend is up \(Int(diff))% vs previous 90 days."
                } else if diff < -5 {
                    res.fuelSpendTrendText = "Fuel spend is down \(Int(abs(diff)))% vs previous 90 days."
                } else {
                    res.fuelSpendTrendText = "Fuel spend has been stable recently."
                }
            } else if last90Fuel > 0 {
                res.fuelSpendTrendText = "Track more fuel to unlock trend comparisons."
            }
            
            let maintenanceServices = sortedServices.filter { $0.category == .maintenance || $0.category == .repair }
            if !maintenanceServices.isEmpty {
                let grouped = Dictionary(grouping: maintenanceServices, by: \.serviceType)
                if let highest = grouped.max(by: { lhs, rhs in
                    lhs.value.reduce(0) { $0 + $1.price } < rhs.value.reduce(0) { $0 + $1.price }
                }) {
                    res.mostExpensiveMaintenanceCategory = highest.key.title
                }
                let ascendingMaint = maintenanceServices.sorted { $0.date < $1.date }
                if ascendingMaint.count >= 2 {
                    let first = ascendingMaint.first!.date
                    let last = ascendingMaint.last!.date
                    let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
                    res.averageServiceIntervalDays = max(0, days / (ascendingMaint.count - 1))
                }
            }
            
            if let lastOil = sortedServices.first(where: { $0.serviceType == .oilChange }) {
                res.daysSinceLastOilChange = max(0, calendar.dateComponents([.day], from: lastOil.date, to: now).day ?? 0)
            }
            if let lastBrakes = sortedServices.first(where: { $0.serviceType == .brakes }) {
                let dist = vehicleMileage - lastBrakes.mileage
                res.distanceSinceLastBrakes = dist >= 0 ? dist : nil
            }
            if let lastTires = sortedServices.first(where: { $0.serviceType == .tires }) {
                let dist = vehicleMileage - lastTires.mileage
                res.distanceSinceLastTires = dist >= 0 ? dist : nil
            }
            if let lastBattery = sortedServices.first(where: { $0.serviceType == .battery }) {
                let dist = vehicleMileage - lastBattery.mileage
                res.distanceSinceLastBattery = dist >= 0 ? dist : nil
            }
            
            if !vehiclesData.isEmpty {
                var highestYearSpend: Double = 0
                for v in vehiclesData {
                    let sTotal = v.services.reduce(0) { $0 + $1.price }
                    let fTotal = v.fuel.reduce(0) { $0 + $1.totalCost }
                    res.garageSpendByVehicle.append((v.title, sTotal + fTotal))
                    res.garageFuelSpendByVehicle.append((v.title, fTotal))
                    
                    let sYear = v.services.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.price }
                    let fYear = v.fuel.filter { $0.date >= thisYearStart }.reduce(0) { $0 + $1.totalCost }
                    if (sYear + fYear) > highestYearSpend {
                        highestYearSpend = sYear + fYear
                        res.costliestVehicleThisYear = v.title
                    }
                    
                    let firstMil = min(v.services.min(by: { $0.mileage < $1.mileage })?.mileage ?? Int.max, v.fuel.min(by: { $0.mileage < $1.mileage })?.mileage ?? Int.max)
                    let lastMil = v.currentMileage
                    let dist = max(0, lastMil - (firstMil == Int.max ? 0 : firstMil))
                    
                    if dist > 50 && (sTotal + fTotal) > 0 {
                        res.costPerKmByVehicle.append((v.title, ((sTotal + fTotal) / Double(dist)) * 100.0))
                    }
                }
                res.garageSpendByVehicle.sort { $0.amount > $1.amount }
                res.garageFuelSpendByVehicle.sort { $0.amount > $1.amount }
                res.costPerKmByVehicle.sort { $0.cost > $1.cost }
                
                if let costliest = res.costliestVehicleThisYear {
                    res.garageIntelligenceText = "\(costliest) is your most expensive vehicle this year."
                } else {
                    res.garageIntelligenceText = "Add expenses to compare your fleet."
                }
            }
            
            res.serviceRecordCount = sortedServices.count
            let servicesWithReceipts = sortedServices.filter { !$0.attachments.isEmpty }.count
            if sortedServices.count > 0 {
                res.receiptCoveragePercentage = (Double(servicesWithReceipts) / Double(sortedServices.count)) * 100.0
            }
            
            var score = 0
            if sortedServices.count > 3 { score += 30 }
            else if sortedServices.count > 0 { score += 10 }
            
            if res.receiptCoveragePercentage > 70 { score += 40 }
            else if res.receiptCoveragePercentage > 30 { score += 20 }
            
            if docs.count > 0 { score += 30 }
            
            res.resaleReadinessScore = min(100, score)
            
            if sortedServices.count < 3 {
                res.resaleNextStepGuidance = "Add more service records to build a complete history."
            } else if res.receiptCoveragePercentage < 70 {
                res.resaleNextStepGuidance = "Attach photos of receipts to your service entries."
            } else if docs.isEmpty {
                res.resaleNextStepGuidance = "Add registration or insurance documents to the Vault."
            } else {
                res.resaleNextStepGuidance = "Your vehicle's history is highly complete."
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
        self.spendingByYear = result.spendingByYear
        self.spendingByCategory = result.spendingByCategory
        self.upcomingPlannedCost = result.upcomingPlannedCost
        self.upcomingPlannedCost3Months = result.upcomingPlannedCost3Months
        self.upcomingPlannedCost6Months = result.upcomingPlannedCost6Months
        
        self.lastValidTank = result.lastValidTank
        self.threeTankAverageConsumption = result.threeTankAverageConsumption
        self.sixTankAverageConsumption = result.sixTankAverageConsumption
        self.costPer100Km = result.costPer100Km
        self.averageFuelPrice = result.averageFuelPrice
        self.fuelSpendTrendText = result.fuelSpendTrendText
        
        self.mostExpensiveMaintenanceCategory = result.mostExpensiveMaintenanceCategory
        self.averageServiceIntervalDays = result.averageServiceIntervalDays
        self.daysSinceLastOilChange = result.daysSinceLastOilChange
        self.distanceSinceLastBrakes = result.distanceSinceLastBrakes
        self.distanceSinceLastTires = result.distanceSinceLastTires
        self.distanceSinceLastBattery = result.distanceSinceLastBattery
        self.upcomingMaintenanceCount = result.upcomingMaintenanceCount
        self.overdueMaintenanceCount = result.overdueMaintenanceCount
        self.maintenanceHealthText = result.maintenanceHealthText
        
        self.garageSpendByVehicle = result.garageSpendByVehicle
        self.garageFuelSpendByVehicle = result.garageFuelSpendByVehicle
        self.costliestVehicleThisYear = result.costliestVehicleThisYear
        self.costPerKmByVehicle = result.costPerKmByVehicle
        self.garageIntelligenceText = result.garageIntelligenceText

        self.serviceRecordCount = result.serviceRecordCount
        self.receiptCoveragePercentage = result.receiptCoveragePercentage
        self.resaleReadinessScore = result.resaleReadinessScore
        self.resaleNextStepGuidance = result.resaleNextStepGuidance
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
    var spendingByYear: [(year: Int, amount: Double)] = []
    var spendingByCategory: [(category: EntryCategory, amount: Double)] = []
    var upcomingPlannedCost: Double = 0
    var upcomingPlannedCost3Months: Double = 0
    var upcomingPlannedCost6Months: Double = 0
    
    var lastValidTank: FuelEntry? = nil
    var threeTankAverageConsumption: Double? = nil
    var sixTankAverageConsumption: Double? = nil
    var costPer100Km: Double? = nil
    var averageFuelPrice: Double? = nil
    var fuelSpendTrendText: String = "Not enough data to calculate fuel trends."
    
    var mostExpensiveMaintenanceCategory: String? = nil
    var averageServiceIntervalDays: Int? = nil
    var daysSinceLastOilChange: Int? = nil
    var distanceSinceLastBrakes: Int? = nil
    var distanceSinceLastTires: Int? = nil
    var distanceSinceLastBattery: Int? = nil
    var upcomingMaintenanceCount: Int = 0
    var overdueMaintenanceCount: Int = 0
    var maintenanceHealthText: String = "All maintenance is up to date."
    
    var garageSpendByVehicle: [(title: String, amount: Double)] = []
    var garageFuelSpendByVehicle: [(title: String, amount: Double)] = []
    var costliestVehicleThisYear: String? = nil
    var costPerKmByVehicle: [(title: String, cost: Double)] = []
    var garageIntelligenceText: String = "Compare your multi-vehicle fleet."
    
    var serviceRecordCount: Int = 0
    var receiptCoveragePercentage: Double = 0
    var resaleReadinessScore: Int = 0
    var resaleNextStepGuidance: String = "A complete history improves resale value."
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
