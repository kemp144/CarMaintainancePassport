import Charts
import SwiftData
import SwiftUI

struct FuelTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator

    let vehicle: Vehicle

    @State private var showingAddFuel = false
    @State private var entryToEdit: FuelEntry?
    @State private var entryToDelete: FuelEntry?
    @State private var showingDeleteConfirmation = false
    @State private var selectedPeriod: FuelLogPeriod = .allTime
    @State private var selectedChartMetric: FuelChartMetric = .spend
    @State private var expandedEntryIDs: Set<UUID> = []

    private var hasDetailedFuelAccess: Bool {
        entitlementStore.canUseDetailedFuelTracking()
    }

    private var analysis: FuelLogAnalysis {
        FuelAnalyticsService.analysis(
            for: vehicle.fuelEntries,
            period: hasDetailedFuelAccess ? selectedPeriod : .allTime
        )
    }

    private var entryLookup: [UUID: FuelEntry] {
        Dictionary(uniqueKeysWithValues: vehicle.fuelEntries.map { ($0.id, $0) })
    }

    private var displayedEntries: [FuelEntry] {
        analysis.filteredEntries.reversed().compactMap { entryLookup[$0.id] }
    }

    private var chartPoints: [FuelTrendPoint] {
        analysis.chartPoints(for: selectedChartMetric)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection

                    if hasDetailedFuelAccess {
                        periodSelector
                    } else {
                        fuelProTeaser
                    }

                    if vehicle.fuelEntries.isEmpty {
                        emptyStateSection
                    } else if displayedEntries.isEmpty {
                        filteredEmptyState
                    } else {
                        if hasDetailedFuelAccess, let note = analysis.insights.lastValidConsumption.note {
                            inlineEducationCard(message: note)
                        }

                        if hasDetailedFuelAccess {
                            statsSection
                            chartSection
                        }
                        entriesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 124)
            }
        }
        .navigationTitle("Fuel Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFuel = true
                } label: {
                    Image(systemName: "plus")
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showingAddFuel) {
            NavigationStack {
                FuelEntryFormSheet(vehicle: vehicle)
            }
        }
        .sheet(item: $entryToEdit) { entry in
            NavigationStack {
                FuelEntryFormSheet(vehicle: vehicle, entry: entry)
            }
        }
        .confirmationDialog("Delete fuel entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var headerSection: some View {
        SurfaceCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overview")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(hasDetailedFuelAccess ? "Selected-period summary with only valid fuel data." : "Basic totals, recent fill-up, and full history.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(10)
                        .background(Circle().fill(AppTheme.surfaceSecondary))
                }

                if let lastFillUp = analysis.insights.lastFillUp {
                    HStack(spacing: 10) {
                        headerMetric(
                            title: "Last Fill-up",
                            value: AppFormatters.mediumDate.string(from: lastFillUp.date)
                        )
                        headerMetric(
                            title: "Total Fuel",
                            value: analysis.insights.totalLiters > 0 ? AppFormatters.fuelVolume(analysis.insights.totalLiters) : "—"
                        )
                        headerMetric(
                            title: "Total Spend",
                            value: analysis.insights.totalCost > 0 ? AppFormatters.currency(analysis.insights.totalCost, code: vehicle.currencyCode) : "—"
                        )
                    }
                }
            }
        }
    }

    private var fuelProTeaser: some View {
        SurfaceCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Detailed Fuel Tracking")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Pro")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                    }

                    Text("Unlock consumption, charts, advanced filters, OCR receipts, and deeper fuel insights.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 12)

                Button("Upgrade") {
                    paywallCoordinator.present(.fuelTracking)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private func headerMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodSelector: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: FuelLogPeriod.allCases.count),
            spacing: 8
        ) {
            ForEach(FuelLogPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    periodTabPill(title: period.shortTitle, isSelected: selectedPeriod == period)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func periodTabPill(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : AppTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppTheme.accent : Color.clear)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(isSelected ? AppTheme.accent.opacity(0.7) : AppTheme.separator, lineWidth: 1)
                    )
            )
    }

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            inlineEducationCard(message: "Consumption becomes accurate after at least one full-to-full cycle.")

            EmptyStateCard(
                icon: "fuelpump.fill",
                title: "Log your first fuel entry",
                message: "Use an initial tank if you are starting with a full tank already, or add the next full fill-up as your starting point.",
                actionTitle: "Add Fuel"
            ) {
                showingAddFuel = true
            }
        }
    }

    private var filteredEmptyState: some View {
        SurfaceCard {
            Text("No fuel entries match this period yet.")
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func inlineEducationCard(message: String) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PremiumSectionHeader(
                title: "Highlights",
                subtitle: "Everything here follows the selected period."
            )

            HStack(spacing: 12) {
                fuelStatCard(
                    title: "Last Valid Tank",
                    value: analysis.insights.lastValidConsumption.value.map { AppFormatters.consumption($0) } ?? "—",
                    note: analysis.insights.lastValidConsumption.note,
                    icon: "gauge.with.dots.needle.33percent",
                    emphasis: .primary
                )
                fuelStatCard(
                    title: "3-Tank Average",
                    value: analysis.insights.rollingThreeCycleAverage.value.map { AppFormatters.consumption($0) } ?? "—",
                    note: analysis.insights.rollingThreeCycleAverage.note,
                    icon: "waveform.path.ecg",
                    emphasis: .primary
                )
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                fuelStatCard(
                    title: "Avg Price / \(UnitSettings.currentFuelVolumeUnit.shortTitle)",
                    value: analysis.insights.averagePricePerLiter.map { UnitFormatter.costPerFuelUnitCurrency($0, currencyCode: vehicle.currencyCode) } ?? "—",
                    note: nil,
                    icon: "eurosign.circle.fill",
                    emphasis: .secondary
                )
                fuelStatCard(
                    title: "Fuel Spend",
                    value: AppFormatters.currency(analysis.insights.totalCost, code: vehicle.currencyCode),
                    note: nil,
                    icon: "calendar",
                    emphasis: .secondary
                )
                fuelStatCard(
                    title: UnitFormatter.costRateTitle(),
                    value: analysis.insights.averageCostPer100Km.value.map { UnitFormatter.costPerDistanceCurrency($0, currencyCode: vehicle.currencyCode) } ?? "—",
                    note: analysis.insights.averageCostPer100Km.note,
                    icon: "banknote.fill",
                    emphasis: .secondary
                )
                fuelStatCard(
                    title: "Tracked Distance",
                    value: analysis.insights.totalTrackedDistanceKm > 0 ? AppFormatters.mileage(analysis.insights.totalTrackedDistanceKm) : "—",
                    note: analysis.insights.totalTrackedDistanceKm == 0 ? "Needs at least two odometer points." : nil,
                    icon: "road.lanes",
                    emphasis: .secondary
                )
            }
        }
    }

    private enum FuelStatCardEmphasis {
        case primary
        case secondary
    }

    private func fuelStatCard(title: String, value: String, note: String?, icon: String, emphasis: FuelStatCardEmphasis) -> some View {
        let isPrimary = emphasis == .primary

        return SurfaceCard(padding: isPrimary ? 16 : 14) {
            VStack(alignment: .leading, spacing: isPrimary ? 10 : 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: isPrimary ? 12 : 11, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(isPrimary ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Text(value)
                    .font(.system(size: isPrimary ? 19 : 16, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(isPrimary ? 2 : 1)
                    .minimumScaleFactor(0.9)

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: isPrimary ? 110 : 88, alignment: .topLeading)
        }
    }

    private var chartSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trend")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("A quick read on spend, consumption, or pump prices.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(FuelChartMetric.allCases) { metric in
                        Button {
                            selectedChartMetric = metric
                        } label: {
                            FilterPill(title: metric.title, isSelected: selectedChartMetric == metric)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if chartPoints.isEmpty {
                    Text("Not enough data yet for this chart.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    Chart {
                        switch selectedChartMetric {
                        case .spend:
                            ForEach(chartPoints) { point in
                                BarMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppTheme.accent.gradient)
                                .cornerRadius(6)
                            }
                        case .consumption, .price:
                            ForEach(chartPoints) { point in
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppTheme.accent.opacity(0.14))

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppTheme.accent)
                                .lineStyle(.init(lineWidth: 2.5, lineCap: .round))

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.value)
                                )
                                .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .frame(height: 210)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(chartPoints.count, 4))) {
                            AxisValueLabel(format: .dateTime.month().day())
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PremiumSectionHeader(
                title: "History",
                subtitle: "\(displayedEntries.count) entries • \(hasDetailedFuelAccess ? selectedPeriod.title : FuelLogPeriod.allTime.title)"
            )

            VStack(spacing: 10) {
                ForEach(displayedEntries) { entry in
                    fuelRow(entry)
                }
            }
        }
    }

    private func fuelRow(_ entry: FuelEntry) -> some View {
        let insight = analysis.insight(for: entry)
        let isExpanded = expandedEntryIDs.contains(entry.id)
        let stationLine = entry.station.trimmingCharacters(in: .whitespacesAndNewlines)
        let litersText = entry.liters > 0 ? AppFormatters.fuelVolume(entry.liters) : "—"
        let odometerText = AppFormatters.mileage(entry.odometerKm)
        let priceText = entry.totalCost > 0 ? AppFormatters.currency(entry.totalCost, code: entry.currencyCode) : "—"

        return SurfaceCard(padding: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    if isExpanded {
                        expandedEntryIDs.remove(entry.id)
                    } else {
                        expandedEntryIDs.insert(entry.id)
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text(AppFormatters.mediumDate.string(from: entry.date))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                badge(for: entry.entryType)

                                if entry.receiptStorageReference != nil {
                                    Image(systemName: "doc.text.image")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }

                            HStack(spacing: 10) {
                                HStack(spacing: 5) {
                                    Text("Liters")
                                    Text(litersText)
                                }

                                Text("•")
                                    .foregroundStyle(AppTheme.tertiaryText)

                                HStack(spacing: 5) {
                                    Text("Odometer")
                                    Text(odometerText)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        }

                        Spacer(minLength: 12)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(priceText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text("Total")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .padding(.top, 4)
                    }

                    if !stationLine.isEmpty {
                        Text(stationLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    if isExpanded {
                        Divider()
                            .overlay(AppTheme.separator)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            expandedMetric(
                                title: "Price / \(UnitSettings.currentFuelVolumeUnit.shortTitle)",
                                value: insight?.pricePerLiter.map { UnitFormatter.costPerFuelUnitCurrency($0, currencyCode: entry.currencyCode) } ?? "—"
                            )
                            expandedMetric(
                                title: "Since Prev",
                                value: insight?.distanceSincePreviousEntryKm.map(AppFormatters.mileage) ?? "—"
                            )

                            expandedMetric(
                                title: "Consumption",
                                value: insight?.cycleConsumption.map(AppFormatters.consumption) ?? "—"
                            )
                            expandedMetric(
                                title: UnitFormatter.costRateTitle(),
                                value: insight?.cycleCostPer100Km.map { UnitFormatter.costPerDistanceCurrency($0, currencyCode: entry.currencyCode) } ?? "—"
                            )
                        }

                        if let note = insight?.note {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.opening")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(insight?.status == .invalid ? AppTheme.warning : AppTheme.secondaryText)

                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(insight?.status == .invalid ? AppTheme.warning : AppTheme.secondaryText)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button {
                entryToEdit = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                entryToDelete = entry
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func badge(for type: FuelEntryType) -> some View {
        Text(type.shortTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(type == .missedFillUp ? AppTheme.warning : AppTheme.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(type == .missedFillUp ? AppTheme.warning.opacity(0.18) : AppTheme.surfaceSecondary)
            )
    }

    private func expandedMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "020617"))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }
        )
    }

    private func deleteEntry(_ entry: FuelEntry) {
        modelContext.delete(entry)
        recalculateVehicleMileage()
        try? modelContext.save()
        entryToDelete = nil
        showingDeleteConfirmation = false
    }

    private func recalculateVehicleMileage() {
        let fuelMileage = vehicle.fuelEntries.map(\.mileage).max() ?? 0
        let serviceMileage = vehicle.serviceEntries.map(\.mileage).max() ?? 0
        vehicle.currentMileage = max(fuelMileage, serviceMileage)
        vehicle.updatedAt = .now
    }
}
