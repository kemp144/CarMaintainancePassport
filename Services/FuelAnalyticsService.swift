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
    static func analysis(
        for entries: [FuelEntry],
        period: FuelLogPeriod = .allTime,
        referenceDate: Date = .now
    ) -> FuelLogAnalysis {
        FuelLogEngine.analyze(entries: entries, period: period, referenceDate: referenceDate)
    }

    static func summary(
        for entries: [FuelEntry],
        period: FuelLogPeriod = .allTime,
        referenceDate: Date = .now
    ) -> FuelLogSummary {
        let analysis = FuelLogEngine.analyze(entries: entries, period: period, referenceDate: referenceDate)
        let insights = analysis.insights

        return FuelLogSummary(
            totalLiters: insights.totalLiters,
            totalCost: insights.totalCost,
            averagePricePerLiter: insights.averagePricePerLiter,
            consumption: FuelConsumptionSummary(
                value: insights.lastValidConsumption.value,
                note: insights.lastValidConsumption.note,
                validSegmentCount: insights.validCycleCount
            )
        )
    }

    static func consumption(
        for entries: [FuelEntry],
        period: FuelLogPeriod = .allTime,
        referenceDate: Date = .now
    ) -> FuelConsumptionSummary {
        summary(for: entries, period: period, referenceDate: referenceDate).consumption
    }
}
