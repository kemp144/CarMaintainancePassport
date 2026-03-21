import Foundation

struct FuelEntryDraft {
    var id: UUID?
    var date: Date
    var odometerKm: Int?
    var liters: Double?
    var totalCost: Double?
    var currencyCode: String
    var entryType: FuelEntryType
    var fuelTypeName: String
    var station: String
    var notes: String
    var receiptStorageReference: String?
    var receiptThumbnailReference: String?
    var createdAt: Date

    var derivedPricePerLiter: Double? {
        guard let liters, let totalCost, liters > 0, totalCost > 0 else { return nil }
        return totalCost / liters
    }

    func derivedPricePerFuelUnit(using fuelVolumeUnit: FuelVolumeUnit) -> Double? {
        guard let totalCost, totalCost > 0, let liters, liters > 0 else { return nil }

        let volumeInDisplayedUnits: Double
        switch fuelVolumeUnit {
        case .liters:
            volumeInDisplayedUnits = liters
        case .gallons:
            volumeInDisplayedUnits = liters / (UnitSettings.currentConsumptionUnit == .mpgUK ? UnitConverter.litersPerImperialGallon : UnitConverter.litersPerUSGallon)
        }

        guard volumeInDisplayedUnits > 0 else { return nil }
        return totalCost / volumeInDisplayedUnits
    }

    var isFullTank: Bool {
        entryType.defaultIsFullTank
    }

    var asRecord: FuelLogRecord? {
        guard let odometerKm else { return nil }
        return FuelLogRecord(
            id: id ?? UUID(),
            date: date,
            odometerKm: odometerKm,
            liters: liters,
            totalCost: totalCost,
            currencyCode: currencyCode,
            fuelTypeName: fuelTypeName,
            station: station,
            notes: notes,
            isFullTank: isFullTank,
            entryType: entryType,
            hasReceipt: receiptStorageReference != nil,
            createdAt: createdAt
        )
    }
}

struct FuelEntryValidationResult {
    let errors: [String]
    let warnings: [String]

    var isValid: Bool {
        errors.isEmpty
    }
}

enum FuelEntryValidator {
    private static let suspiciousPricePerLiterRange = 0.15...6.5
    // Max plausible fill-up in liters (~400L covers the largest truck tanks)
    private static let maxReasonableLiters: Double = 400

    static func validate(
        draft: FuelEntryDraft,
        against entries: [FuelEntry],
        for vehicle: Vehicle
    ) -> FuelEntryValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        guard let odometer = draft.odometerKm else {
            return FuelEntryValidationResult(
                errors: ["Odometer is required."],
                warnings: []
            )
        }

        if odometer < 0 {
            errors.append("Odometer cannot be negative.")
        }

        let today = Calendar.current.startOfDay(for: .now)
        if Calendar.current.startOfDay(for: draft.date) > today {
            errors.append("Fuel stop date cannot be in the future.")
        }

        // Warn if the odometer looks like a trip distance instead of an actual reading
        let latestRecordedOdometer = FuelLogEngine.sort(
            entries
                .filter { $0.id != draft.id }
                .map(\.fuelLogRecord)
        )
        .last?
        .odometerKm ?? 0
        if latestRecordedOdometer > 0, odometer > 0, odometer < latestRecordedOdometer / 2 {
            warnings.append("This odometer value (\(UnitFormatter.distance(Double(odometer)))) is much lower than the last recorded reading (\(UnitFormatter.distance(Double(latestRecordedOdometer)))). Make sure you're entering the full odometer, not a trip distance.")
        }

        let displayedFuelUnit = UnitSettings.currentFuelVolumeUnit.title.lowercased()
        let requiresAmounts = draft.entryType.requiresFuelAmounts
        let hasLiters = (draft.liters ?? 0) > 0
        let hasTotalCost = (draft.totalCost ?? 0) > 0

        if requiresAmounts {
            if !hasLiters || !hasTotalCost {
                errors.append("\(displayedFuelUnit.capitalized) and total price are both required for this fuel entry.")
            }
        } else if hasLiters != hasTotalCost {
            errors.append("If you enter \(displayedFuelUnit), please enter the total price too.")
        }

        if let liters = draft.liters {
            if liters < 0 {
                errors.append("\(displayedFuelUnit.capitalized) cannot be negative.")
            } else if liters > maxReasonableLiters {
                warnings.append("That's an unusually large volume (\(UnitFormatter.fuelVolume(liters))). Please double-check the amount.")
            }
        }

        if let totalCost = draft.totalCost, totalCost < 0 {
            errors.append("Total price cannot be negative.")
        }

        if let pricePerLiter = draft.derivedPricePerLiter,
           !suspiciousPricePerLiterRange.contains(pricePerLiter) {
            warnings.append("This fuel price seems unusual for the entered volume. Please double-check the amount.")
        }

        let timelineErrors = VehicleOdometerTimelineValidator.validateFuelEntry(
            vehicle: vehicle,
            fuelID: draft.id,
            date: draft.date,
            mileage: odometer,
            createdAt: draft.createdAt
        )
        errors.append(contentsOf: timelineErrors)

        if let draftRecord = draft.asRecord {
            let otherRecords = entries
                .filter { $0.id != draft.id }
                .map(\.fuelLogRecord)
            let ordered = FuelLogEngine.sort(otherRecords + [draftRecord])

            if let currentIndex = ordered.firstIndex(where: { $0.id == draftRecord.id }) {
                if currentIndex > 0 {
                    let previous = ordered[currentIndex - 1]
                    if odometer <= previous.odometerKm {
                        errors.append("Odometer must be higher than the previous fuel entry.")
                    }
                }

                if currentIndex < ordered.count - 1 {
                    let next = ordered[currentIndex + 1]
                    if odometer >= next.odometerKm {
                        errors.append("Odometer must stay lower than the next fuel entry in the timeline.")
                    }
                }
            }
        }

        return FuelEntryValidationResult(errors: errors, warnings: warnings)
    }
}
