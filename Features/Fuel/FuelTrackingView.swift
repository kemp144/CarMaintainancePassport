import Charts
import SwiftData
import SwiftUI

struct FuelTrackingView: View {
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    @State private var showingAddFuel = false
    @State private var entryToEdit: FuelEntry?
    @State private var entryToDelete: FuelEntry?
    @State private var showingDeleteConfirmation = false
    @State private var selectedPeriod: FuelLogPeriod = .allTime
    @State private var selectedChartMetric: FuelChartMetric = .spend

    private var analysis: FuelLogAnalysis {
        FuelAnalyticsService.analysis(for: vehicle.fuelEntries, period: selectedPeriod)
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
                VStack(spacing: 24) {
                    headerSection

                    periodSelector

                    if vehicle.fuelEntries.isEmpty {
                        emptyStateSection
                    } else if displayedEntries.isEmpty {
                        filteredEmptyState
                    } else {
                        if let note = analysis.insights.lastValidConsumption.note {
                            inlineEducationCard(message: note)
                        }

                        statsSection
                        chartSection
                        entriesSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 100)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fuel Log")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Trustworthy fuel costs and consumption, only when the sequence is mathematically sound.")
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
                    HStack(spacing: 12) {
                        headerMetric(
                            title: "Last Fill-up",
                            value: AppFormatters.mediumDate.string(from: lastFillUp.date)
                        )
                        headerMetric(
                            title: "Liters",
                            value: lastFillUp.liters.map { "\(AppFormatters.decimal($0)) L" } ?? "—"
                        )
                        headerMetric(
                            title: "Spend",
                            value: lastFillUp.totalCost.map { AppFormatters.currency($0, code: lastFillUp.currencyCode) } ?? "—"
                        )
                    }
                }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FuelLogPeriod.allCases) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        FilterPill(title: period.title, isSelected: selectedPeriod == period)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
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
                subtitle: "Only valid cycles feed the consumption metrics."
            )

            HStack(spacing: 12) {
                fuelStatCard(
                    title: "Last Valid Tank",
                    value: analysis.insights.lastValidConsumption.value.map { "\(AppFormatters.decimal($0)) L/100 km" } ?? "—",
                    note: analysis.insights.lastValidConsumption.note,
                    icon: "gauge.with.dots.needle.33percent"
                )
                fuelStatCard(
                    title: "3-Tank Average",
                    value: analysis.insights.rollingThreeCycleAverage.value.map { "\(AppFormatters.decimal($0)) L/100 km" } ?? "—",
                    note: analysis.insights.rollingThreeCycleAverage.note,
                    icon: "waveform.path.ecg"
                )
            }

            HStack(spacing: 12) {
                fuelStatCard(
                    title: "Avg Price / L",
                    value: analysis.insights.averagePricePerLiter.map { "\(AppFormatters.currency($0, code: vehicle.currencyCode))/L" } ?? "—",
                    note: selectedPeriod.title,
                    icon: "eurosign.circle.fill"
                )
                fuelStatCard(
                    title: "Fuel Spend This Month",
                    value: AppFormatters.currency(analysis.insights.spendThisMonth, code: vehicle.currencyCode),
                    note: analysis.insights.spendThisMonth == 0 ? "No spend logged this month." : nil,
                    icon: "calendar"
                )
            }

            HStack(spacing: 12) {
                fuelStatCard(
                    title: "Cost / 100 km",
                    value: analysis.insights.averageCostPer100Km.value.map { AppFormatters.currency($0, code: vehicle.currencyCode) } ?? "—",
                    note: analysis.insights.averageCostPer100Km.note,
                    icon: "banknote.fill"
                )
                fuelStatCard(
                    title: "Tracked Distance",
                    value: analysis.insights.totalTrackedDistanceKm > 0 ? AppFormatters.mileage(analysis.insights.totalTrackedDistanceKm) : "—",
                    note: analysis.insights.totalTrackedDistanceKm == 0 ? "Needs at least two odometer points." : nil,
                    icon: "road.lanes"
                )
            }
        }
    }

    private func fuelStatCard(title: String, value: String, note: String?, icon: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
                subtitle: "\(displayedEntries.count) entries in \(selectedPeriod.title.lowercased())"
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

        return Button {
            entryToEdit = entry
        } label: {
            SurfaceCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
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

                            Text(AppFormatters.mileage(entry.odometerKm))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)

                            if !entry.station.isEmpty || !entry.fuelTypeName.isEmpty {
                                Text([entry.station, entry.fuelTypeName].filter { !$0.isEmpty }.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(entry.totalCost > 0 ? AppFormatters.currency(entry.totalCost, code: entry.currencyCode) : "—")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(entry.liters > 0 ? "\(AppFormatters.decimal(entry.liters)) L" : "No fuel amount")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    HStack(spacing: 12) {
                        detailPill(title: "Price / L", value: insight?.pricePerLiter.map { "\(AppFormatters.currency($0, code: entry.currencyCode))/L" } ?? "—")
                        detailPill(title: "Since Previous", value: insight?.distanceSincePreviousEntryKm.map(AppFormatters.mileage) ?? "—")
                    }

                    if let consumption = insight?.cycleConsumption {
                        HStack(spacing: 12) {
                            detailPill(title: "Consumption", value: "\(AppFormatters.decimal(consumption)) L/100 km")
                            detailPill(
                                title: "Cost / 100 km",
                                value: insight?.cycleCostPer100Km.map { AppFormatters.currency($0, code: entry.currencyCode) } ?? "—"
                            )
                        }
                    } else if let note = insight?.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(insight?.status == .invalid ? AppTheme.warning : AppTheme.secondaryText)
                    }

                    HStack(spacing: 10) {
                        Button {
                            entryToEdit = entry
                        } label: {
                            rowActionIcon("pencil")
                        }

                        Button(role: .destructive) {
                            entryToDelete = entry
                            showingDeleteConfirmation = true
                        } label: {
                            rowActionIcon("trash")
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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

    private func detailPill(title: String, value: String) -> some View {
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

    private func rowActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(systemName == "trash" ? AppTheme.secondaryText : AppTheme.accent)
            .padding(8)
            .background(Circle().fill(AppTheme.surfaceSecondary))
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
