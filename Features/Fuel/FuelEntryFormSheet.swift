import SwiftData
import SwiftUI

struct FuelEntryFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("fuel.lastFuelTypeName") private var lastFuelTypeName = ""
    @AppStorage("fuel.lastStation") private var lastStation = ""
    @AppStorage("fuel.lastCurrencyCode") private var lastCurrencyCode = "EUR"

    let vehicle: Vehicle
    private let entry: FuelEntry?

    @State private var date: Date
    @State private var mileage: String
    @State private var entryType: FuelEntryType
    @State private var liters: String
    @State private var totalCost: String
    @State private var fuelTypeName: String
    @State private var station: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var validationMessage: String?
    @State private var warningMessage: String?
    @State private var showingValidationAlert = false
    @State private var showingWarningAlert = false

    init(vehicle: Vehicle, entry: FuelEntry? = nil) {
        self.vehicle = vehicle
        self.entry = entry
        _date = State(initialValue: entry?.date ?? .now)
        _mileage = State(initialValue: entry.map { String($0.mileage) } ?? String(vehicle.currentMileage))
        _entryType = State(initialValue: entry?.entryType ?? .fullFillUp)
        _liters = State(initialValue: entry.map { $0.liters > 0 ? String(format: "%.2f", $0.liters) : "" } ?? "")
        _totalCost = State(initialValue: entry.map { $0.totalCost > 0 ? String(format: "%.2f", $0.totalCost) : "" } ?? "")
        _fuelTypeName = State(initialValue: entry?.fuelTypeName ?? "")
        _station = State(initialValue: entry?.station ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                if vehicle.fuelEntries.isEmpty && entry == nil {
                    introSection
                }

                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(FuelEntryType.allCases) { type in
                            fuelTypeButton(for: type)
                        }
                    }
                    Text(entryType.helperText)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                } header: {
                    Text("Entry Type").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Odometer (km)", text: $mileage)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Trip Context").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text("Entries are validated against the surrounding fuel timeline to prevent backward mileage.")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField(entryType.requiresFuelAmounts ? "Liters" : "Liters (optional)", text: $liters)
                        .keyboardType(.decimalPad)

                    TextField(entryType.requiresFuelAmounts ? "Total price" : "Total price (optional)", text: $totalCost)
                        .keyboardType(.decimalPad)

                    if let pricePerLiter = draft.derivedPricePerLiter {
                        HStack {
                            Text("Price per liter")
                            Spacer()
                            Text("\(AppFormatters.currency(pricePerLiter, code: resolvedCurrencyCode))/L")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                } header: {
                    Text("Fuel").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text(entryType.requiresFuelAmounts ? "Both liters and total price are required for fill-ups." : "You can leave these blank for an initial tank or a missed entry.")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField("Fuel type", text: $fuelTypeName)
                        .textInputAutocapitalization(.words)

                    TextField("Station / brand", text: $station)
                        .textInputAutocapitalization(.words)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Additional").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text("Fuel type, station, and currency are remembered for faster future entries.")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
        }
        .navigationTitle(entry == nil ? "Add Fuel" : "Edit Fuel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    save()
                }
                .disabled(isSaving || !isReadyToValidate)
            }
        }
        .onAppear {
            if entry == nil {
                if fuelTypeName.isEmpty {
                    fuelTypeName = lastFuelTypeName
                }
                if station.isEmpty {
                    station = lastStation
                }
            }
        }
        .alert("Couldn’t save fuel entry", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "Please review the entered values.")
        }
        .alert("Check fuel price", isPresented: $showingWarningAlert) {
            Button("Save Anyway") {
                persistEntry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(warningMessage ?? "Please review the entered values.")
        }
    }

    private var introSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Consumption becomes accurate after at least one full-to-full cycle.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Start with an initial tank if you already have a full tank, or log your next full fill-up as the starting point.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .listRowBackground(AppTheme.surface)
    }

    private func fuelTypeButton(for type: FuelEntryType) -> some View {
        Button {
            entryType = type
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entryType == type ? AppTheme.accent : AppTheme.secondaryText)

                Text(type.shortTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(entryType == type ? AppTheme.surfaceSecondary : Color(hex: "020617"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(entryType == type ? AppTheme.accent.opacity(0.45) : AppTheme.separator, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
    }

    private var resolvedCurrencyCode: String {
        if !vehicle.currencyCode.isEmpty {
            return vehicle.currencyCode
        }
        if let entry, !entry.currencyCode.isEmpty {
            return entry.currencyCode
        }
        return lastCurrencyCode
    }

    private var parsedMileage: Int? {
        Int(mileage)
    }

    private var parsedLiters: Double? {
        parseDecimal(liters)
    }

    private var parsedTotalCost: Double? {
        parseDecimal(totalCost)
    }

    private var isReadyToValidate: Bool {
        parsedMileage != nil
    }

    private var draft: FuelEntryDraft {
        FuelEntryDraft(
            id: entry?.id,
            date: date,
            odometerKm: parsedMileage,
            liters: parsedLiters,
            totalCost: parsedTotalCost,
            currencyCode: resolvedCurrencyCode,
            entryType: entryType,
            fuelTypeName: fuelTypeName.trimmingCharacters(in: .whitespacesAndNewlines),
            station: station.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptStorageReference: entry?.receiptStorageReference,
            receiptThumbnailReference: entry?.receiptThumbnailReference,
            createdAt: entry?.createdAt ?? .now
        )
    }

    private func save() {
        let validation = FuelEntryValidator.validate(draft: draft, against: vehicle.fuelEntries)

        guard validation.isValid else {
            validationMessage = validation.errors.first
            showingValidationAlert = true
            return
        }

        if let warning = validation.warnings.first {
            warningMessage = warning
            showingWarningAlert = true
            return
        }

        persistEntry()
    }

    private func persistEntry() {
        guard let mileageValue = draft.odometerKm else { return }

        isSaving = true

        let litersValue = draft.liters ?? 0
        let totalCostValue = draft.totalCost ?? 0
        let pricePerLiter = draft.derivedPricePerLiter ?? 0

        if let entry {
            entry.date = draft.date
            entry.mileage = mileageValue
            entry.liters = litersValue
            entry.pricePerLiter = pricePerLiter
            entry.totalCost = totalCostValue
            entry.currencyCode = draft.currencyCode
            entry.entryType = draft.entryType
            entry.fuelTypeName = draft.fuelTypeName
            entry.station = draft.station
            entry.notes = draft.notes
            entry.updatedAt = .now
        } else {
            let newEntry = FuelEntry(
                vehicle: vehicle,
                date: draft.date,
                mileage: mileageValue,
                liters: litersValue,
                pricePerLiter: pricePerLiter,
                totalCost: totalCostValue,
                currencyCode: draft.currencyCode,
                entryType: draft.entryType,
                fuelTypeName: draft.fuelTypeName,
                station: draft.station,
                notes: draft.notes,
                isFullTank: draft.isFullTank,
                createdAt: draft.createdAt,
                updatedAt: .now
            )
            modelContext.insert(newEntry)
        }

        lastFuelTypeName = draft.fuelTypeName
        lastStation = draft.station
        lastCurrencyCode = draft.currencyCode

        recalculateVehicleMileage(afterSavingMileage: mileageValue)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func recalculateVehicleMileage(afterSavingMileage mileage: Int) {
        let existingFuelMileage = vehicle.fuelEntries
            .filter { $0.id != entry?.id }
            .map(\.mileage)
            .max() ?? 0
        let serviceMileage = vehicle.serviceEntries.map(\.mileage).max() ?? 0
        vehicle.currentMileage = max(max(existingFuelMileage, serviceMileage), mileage)
        vehicle.updatedAt = .now
    }

    private func parseDecimal(_ value: String) -> Double? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
