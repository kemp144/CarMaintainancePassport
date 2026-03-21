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
        _mileage = State(initialValue: entry.map { UnitFormatter.distanceValue(Double($0.mileage)) } ?? "")
        _entryType = State(initialValue: entry?.entryType ?? .fullFillUp)
        _liters = State(initialValue: entry.map { $0.liters > 0 ? UnitFormatter.fuelVolumeValue($0.liters) : "" } ?? "")
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
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 10) {
                            ForEach(FuelEntryType.primarySelectionCases) { type in
                                fuelTypeButton(for: type)
                            }
                        }

                        Button {
                            entryType = .missedFillUp
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entryType == .missedFillUp ? AppTheme.accent : AppTheme.secondaryText)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Forgot to log an earlier fuel stop?")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Text(FuelEntryType.missedFillUp.selectionSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(entryType == .missedFillUp ? AppTheme.surfaceSecondary : Color(hex: "020617"))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(entryType == .missedFillUp ? AppTheme.accent.opacity(0.45) : AppTheme.separator, lineWidth: 1)
                                    }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Entry Type").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text("Most drivers only need Full or Partial. Use the missed entry option to add a fuel stop that happened earlier but wasn't logged.")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    DatePicker(entryType == .missedFillUp ? "Date of fuel stop" : "Date", selection: $date, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entryType == .missedFillUp ? "Odometer at stop" : "Current odometer")
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("0", text: $mileage)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 60)
                                Text(UnitSettings.currentDistanceUnit.shortTitle)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }

                        if entry == nil, let lastKnownMileage = vehicle.resolvedCurrentMileage {
                            Text("Last known mileage: \(AppFormatters.mileage(lastKnownMileage))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                } header: {
                    Text(entryType == .missedFillUp ? "Fuel Stop Details" : "Trip Context").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text(entryType == .missedFillUp
                         ? "Enter the date and odometer reading from that earlier fuel stop."
                         : "Enter the odometer shown at the pump. The previous reading is shown only as reference, so duplicate mileage is less likely.")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    TextField(entryType == .missedFillUp ? "\(UnitSettings.currentFuelVolumeUnit.title) (optional)" : UnitSettings.currentFuelVolumeUnit.title, text: $liters)
                        .keyboardType(.decimalPad)

                    TextField(entryType == .missedFillUp ? "Total price (optional)" : "Total price", text: $totalCost)
                        .keyboardType(.decimalPad)

                    if let pricePerUnit = draft.derivedPricePerFuelUnit(using: UnitSettings.currentFuelVolumeUnit) {
                        HStack {
                            Text("Price per \(UnitSettings.currentFuelVolumeUnit.shortTitle)")
                            Spacer()
                            Text("\(AppFormatters.currency(pricePerUnit, code: resolvedCurrencyCode))/\(UnitSettings.currentFuelVolumeUnit.shortTitle)")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                } header: {
                    Text("Fuel").foregroundStyle(AppTheme.secondaryText)
                } footer: {
                    Text(entryType == .missedFillUp ? "Add any details you remember. Liters and total price are optional for missed fuel stops." : "Full and Partial entries need both fuel volume and total price.")
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
                    Text("Fuel type and station are remembered for faster future entries.")
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
                    Text("Your first fuel entry simply starts the vehicle's fuel history automatically.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Choose Full for a complete fill-up, Partial for a top-up, or add an earlier fuel stop you forgot to log.")
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(displayedEntryType == type ? AppTheme.accent : AppTheme.secondaryText)

                    Text(type.shortTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(type.selectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(displayedEntryType == type ? AppTheme.surfaceSecondary : Color(hex: "020617"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(displayedEntryType == type ? AppTheme.accent.opacity(0.45) : AppTheme.separator, lineWidth: 1)
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

    private var displayedEntryType: FuelEntryType {
        entryType == .initialTank ? .fullFillUp : entryType
    }

    private var parsedMileage: Int? {
        UnitFormatter.parseDistance(mileage)
    }

    private var parsedLiters: Double? {
        UnitFormatter.parseFuelVolume(liters)
    }

    private var parsedTotalCost: Double? {
        UnitFormatter.parseDecimal(totalCost)
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
        let validation = FuelEntryValidator.validate(draft: draft, against: vehicle.fuelEntries, for: vehicle)

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

        VehicleMileageResolver.recalculateCurrentMileage(for: vehicle)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
