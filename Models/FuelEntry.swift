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
    var station: String
    var notes: String
    var isFullTank: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicle: Vehicle? = nil,
        date: Date = .now,
        mileage: Int,
        liters: Double,
        pricePerLiter: Double = 0,
        totalCost: Double,
        currencyCode: String = "EUR",
        station: String = "",
        notes: String = "",
        isFullTank: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.date = date
        self.mileage = mileage
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.totalCost = totalCost
        self.currencyCode = currencyCode
        self.station = station
        self.notes = notes
        self.isFullTank = isFullTank
        self.createdAt = createdAt
    }
}

extension FuelEntry {
    var odometerKm: Int {
        get { mileage }
        set { mileage = newValue }
    }
}
