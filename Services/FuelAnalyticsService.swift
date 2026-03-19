import Foundation

struct FuelConsumptionSummary {
    let value: Double?
    let note: String?
    let validSegmentCount: Int
}

struct FuelLogSummary {
    let totalLiters: Double
    let totalCost: Double
    let averagePricePerLiter: Double?
    let consumption: FuelConsumptionSummary
}

enum FuelAnalyticsService {
    static func summary(for entries: [FuelEntry]) -> FuelLogSummary {
        let validMoneyEntries = entries.filter { $0.liters > 0 && $0.totalCost > 0 }
        let totalLiters = validMoneyEntries.reduce(0) { $0 + $1.liters }
        let totalCost = validMoneyEntries.reduce(0) { $0 + $1.totalCost }
        let averagePricePerLiter = totalLiters > 0 ? totalCost / totalLiters : nil

        return FuelLogSummary(
            totalLiters: totalLiters,
            totalCost: totalCost,
            averagePricePerLiter: averagePricePerLiter,
            consumption: consumption(for: entries)
        )
    }

    static func consumption(for entries: [FuelEntry]) -> FuelConsumptionSummary {
        let ordered = entries
            .filter { $0.liters > 0 }
            .sorted {
                if $0.odometerKm != $1.odometerKm {
                    return $0.odometerKm < $1.odometerKm
                }
                if $0.date != $1.date {
                    return $0.date < $1.date
                }
                return $0.createdAt < $1.createdAt
            }

        guard ordered.count >= 2 else {
            return FuelConsumptionSummary(
                value: nil,
                note: "Add two full fill-ups with mileage to see consumption.",
                validSegmentCount: 0
            )
        }

        var totalLiters = 0.0
        var totalDistance = 0.0
        var validSegmentCount = 0

        for index in 1..<ordered.count {
            let previous = ordered[index - 1]
            let current = ordered[index]

            guard previous.isFullTank, current.isFullTank else { continue }
            guard current.odometerKm > previous.odometerKm else { continue }
            guard current.liters > 0 else { continue }

            let distance = Double(current.odometerKm - previous.odometerKm)
            guard distance > 0 else { continue }

            totalLiters += current.liters
            totalDistance += distance
            validSegmentCount += 1

            #if DEBUG
            let segmentConsumption = (current.liters / distance) * 100
            if segmentConsumption > 40 || segmentConsumption < 2 {
                print("[FuelAnalytics] Suspicious consumption segment: \(segmentConsumption) L/100km for entry \(current.id)")
            }
            #endif
        }

        guard validSegmentCount > 0, totalDistance > 0, totalLiters > 0 else {
            return FuelConsumptionSummary(
                value: nil,
                note: "Add two full fill-ups with mileage to see consumption.",
                validSegmentCount: 0
            )
        }

        return FuelConsumptionSummary(
            value: (totalLiters / totalDistance) * 100,
            note: nil,
            validSegmentCount: validSegmentCount
        )
    }
}
