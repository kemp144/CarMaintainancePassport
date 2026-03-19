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
    private static let suspiciousPricePerLiterRange = 0.4...4.5

    static func validate(
        draft: FuelEntryDraft,
        against entries: [FuelEntry]
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

        let requiresAmounts = draft.entryType.requiresFuelAmounts
        let hasLiters = (draft.liters ?? 0) > 0
        let hasTotalCost = (draft.totalCost ?? 0) > 0

        if requiresAmounts {
            if !hasLiters || !hasTotalCost {
                errors.append("Liters and total price are both required for this fuel entry.")
            }
        } else if hasLiters != hasTotalCost {
            errors.append("If you enter liters, please enter the total price too.")
        }

        if let liters = draft.liters, liters < 0 {
            errors.append("Liters cannot be negative.")
        }

        if let totalCost = draft.totalCost, totalCost < 0 {
            errors.append("Total price cannot be negative.")
        }

        if let pricePerLiter = draft.derivedPricePerLiter,
           !suspiciousPricePerLiterRange.contains(pricePerLiter) {
            warnings.append("This price looks unusually high for the entered liters. Please check the decimal value.")
        }

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
