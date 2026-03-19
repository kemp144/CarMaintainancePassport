import SwiftData
import SwiftUI

struct FuelTrackingView: View {
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    @State private var showingAddFuel = false
    @State private var entryToEdit: FuelEntry?
    @State private var entryToDelete: FuelEntry?
    @State private var showingDeleteConfirmation = false

    private var sortedEntries: [FuelEntry] {
        (vehicle.fuelEntries).sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if sortedEntries.isEmpty {
                        fuelIntroCard
                    }

                    if !sortedEntries.isEmpty {
                        statsSection
                    }

                    entriesSection
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

    private var fuelIntroCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Fuel log")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("Optional but useful")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Text("Track fill-ups to see spending, consumption, and ownership cost over time. It becomes more useful with every entry.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var statsSection: some View {
        let summary = FuelAnalyticsService.summary(for: sortedEntries)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 12) {
                statCard(title: "Total Liters", value: summary.totalLiters > 0 ? String(format: "%.1f L", summary.totalLiters) : "—")
                statCard(title: "Total Fuel Cost", value: summary.totalCost > 0 ? AppFormatters.currency(summary.totalCost, code: vehicle.currencyCode) : "—")
            }
            HStack(spacing: 12) {
                statCard(
                    title: "Avg Price/L",
                    value: summary.averagePricePerLiter.map { "\(AppFormatters.currency($0, code: vehicle.currencyCode))/L" } ?? "—"
                )
                statCard(
                    title: "Avg Consumption",
                    value: summary.consumption.value.map { String(format: "%.1f L/100 km", $0) } ?? "—",
                    note: summary.consumption.note
                )
            }
        }
    }

    private func statCard(title: String, value: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.surface))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fill-ups")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("\(sortedEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if sortedEntries.isEmpty {
                EmptyStateCard(
                    icon: "fuelpump.fill",
                    title: "Log your first fill-up",
                    message: "A few fuel entries reveal total cost, average consumption, and how the car behaves over time.",
                    actionTitle: "Add Fuel"
                ) {
                    showingAddFuel = true
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedEntries) { entry in
                        fuelRow(entry)
                    }
                }
            }
        }
    }

    private func fuelRow(_ entry: FuelEntry) -> some View {
        Button {
            entryToEdit = entry
        } label: {
            SurfaceCard(padding: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.isFullTank ? "fuelpump.fill" : "fuelpump")
                                .font(.system(size: 13))
                                .foregroundStyle(entry.isFullTank ? AppTheme.accent : AppTheme.secondaryText)
                            Text(AppFormatters.mediumDate.string(from: entry.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            if entry.isFullTank {
                                Text("Full")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(AppTheme.accent.opacity(0.22)))
                            }
                        }
                        Text(String(format: "%.1f L", entry.liters) + " • " + AppFormatters.mileage(entry.odometerKm))
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                        if !entry.station.isEmpty {
                            Text(entry.station)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Text(AppFormatters.currency(entry.totalCost, code: entry.currencyCode))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        if entry.pricePerLiter > 0 {
                            Text("\(AppFormatters.currency(entry.pricePerLiter, code: entry.currencyCode))/L")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        HStack(spacing: 10) {
                            Button {
                                entryToEdit = entry
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(8)
                                    .background(Circle().fill(AppTheme.surfaceSecondary))
                            }

                            Button(role: .destructive) {
                                entryToDelete = entry
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .padding(8)
                                    .background(Circle().fill(AppTheme.surfaceSecondary))
                            }
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
