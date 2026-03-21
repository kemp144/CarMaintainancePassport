import Foundation
import SwiftData

@Model
final class FuelEntry {
    @Attribute(.unique) var id: UUID
    var vehicle: Vehicle?
    var date: Date
    var mileage: Int
    var liters: Double
    var pricePerLiter: Double
    var totalCost: Double
    var currencyCode: String
    var entryTypeRaw: String
    var fuelTypeName: String
    var station: String
    var notes: String
    var isFullTank: Bool
    var receiptStorageReference: String?
    var receiptThumbnailReference: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        vehicle: Vehicle? = nil,
        date: Date = .now,
        mileage: Int,
        liters: Double,
        pricePerLiter: Double = 0,
        totalCost: Double,
        currencyCode: String = CurrencyPreset.suggested().rawValue,
        entryType: FuelEntryType = .fullFillUp,
        fuelTypeName: String = "",
        station: String = "",
        notes: String = "",
        isFullTank: Bool? = nil,
        receiptStorageReference: String? = nil,
        receiptThumbnailReference: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.date = date
        self.mileage = mileage
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.totalCost = totalCost
        self.currencyCode = currencyCode
        self.entryTypeRaw = entryType.rawValue
        self.fuelTypeName = fuelTypeName
        self.station = station
        self.notes = notes
        self.isFullTank = isFullTank ?? entryType.defaultIsFullTank
        self.receiptStorageReference = receiptStorageReference
        self.receiptThumbnailReference = receiptThumbnailReference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension FuelEntry {
    var odometerKm: Int {
        get { mileage }
        set { mileage = newValue }
    }

    var entryType: FuelEntryType {
        get {
            FuelEntryType(rawValue: entryTypeRaw) ?? (isFullTank ? .fullFillUp : .partialFillUp)
        }
        set {
            entryTypeRaw = newValue.rawValue
            isFullTank = newValue.defaultIsFullTank
        }
    }

    var effectivePricePerLiter: Double? {
        guard liters > 0 else { return nil }
        let resolvedPrice = totalCost > 0 ? totalCost / liters : pricePerLiter
        return resolvedPrice > 0 ? resolvedPrice : nil
    }
}
