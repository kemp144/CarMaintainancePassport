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
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statsSection: some View {
        let totalLiters = sortedEntries.reduce(0.0) { $0 + $1.liters }
        let totalCost = sortedEntries.reduce(0.0) { $0 + $1.totalCost }
        let avgPrice = totalLiters > 0 ? totalCost / totalLiters : 0
        let consumption = averageConsumption()

        return VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 12) {
                statCard(title: "Total Liters", value: String(format: "%.1f L", totalLiters))
                statCard(title: "Total Fuel Cost", value: AppFormatters.currency(totalCost, code: vehicle.currencyCode))
            }
            HStack(spacing: 12) {
                statCard(title: "Avg Price/L", value: avgPrice > 0 ? String(format: "%.3f %@/L", avgPrice, vehicle.currencyCode) : "—")
                statCard(title: "Avg Consumption", value: consumption.map { String(format: "%.1f L/100km", $0) } ?? "—")
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
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
                SurfaceCard(padding: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "fuelpump")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("No fuel entries yet")
                            .foregroundStyle(AppTheme.secondaryText)
                        Button("Add First Fill-up") {
                            showingAddFuel = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 200)
                    }
                    .frame(maxWidth: .infinity)
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
        SurfaceCard(padding: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if entry.isFullTank {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Image(systemName: "fuelpump")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Text(AppFormatters.mediumDate.string(from: entry.date))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    Text(String(format: "%.2f L", entry.liters) + " • " + AppFormatters.mileage(entry.mileage))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                    if !entry.station.isEmpty {
                        Text(entry.station)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormatters.currency(entry.totalCost, code: entry.currencyCode))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    if entry.pricePerLiter > 0 {
                        Text(String(format: "%.3f/L", entry.pricePerLiter))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
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

    // L/100km based on consecutive full-tank fills with mileage
    private func averageConsumption() -> Double? {
        let fullTanks = sortedEntries
            .filter { $0.isFullTank && $0.mileage > 0 }
            .sorted { $0.mileage < $1.mileage }

        guard fullTanks.count >= 2 else { return nil }

        var consumptions: [Double] = []
        for i in 1..<fullTanks.count {
            let kmDriven = fullTanks[i].mileage - fullTanks[i - 1].mileage
            guard kmDriven > 10 else { continue }
            let l100km = (fullTanks[i].liters / Double(kmDriven)) * 100
            if l100km > 2, l100km < 40 { consumptions.append(l100km) }
        }

        guard !consumptions.isEmpty else { return nil }
        return consumptions.reduce(0, +) / Double(consumptions.count)
    }
}
