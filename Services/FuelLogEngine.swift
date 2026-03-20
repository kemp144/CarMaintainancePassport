import Foundation

struct FuelLogRecord: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let odometerKm: Int
    let liters: Double?
    let totalCost: Double?
    let currencyCode: String
    let fuelTypeName: String
    let station: String
    let notes: String
    let isFullTank: Bool
    let entryType: FuelEntryType
    let hasReceipt: Bool
    let createdAt: Date

    var pricePerLiter: Double? {
        guard let liters, let totalCost, liters > 0, totalCost > 0 else { return nil }
        return totalCost / liters
    }
}

enum FuelCycleStatus: String {
    case valid
    case pending
    case invalid
}

struct FuelEntryInsight: Hashable {
    let entryID: UUID
    let distanceSincePreviousEntryKm: Int?
    let distanceSinceSequenceStartKm: Int?
    let pricePerLiter: Double?
    let cycleConsumption: Double?
    let cycleCostPer100Km: Double?
    let status: FuelCycleStatus
    let note: String?
}

struct FuelCycle: Identifiable, Hashable {
    let id: UUID
    let startEntryID: UUID
    let endEntryID: UUID
    let startDate: Date
    let endDate: Date
    let distanceKm: Int
    let liters: Double
    let totalCost: Double
    let consumption: Double
    let costPer100Km: Double
    let includedEntryIDs: [UUID]
}

struct FuelMetricValue: Hashable {
    let value: Double?
    let note: String?
}

struct FuelTrendPoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let label: String
    let value: Double
}

struct FuelLogInsights: Hashable {
    let totalLiters: Double
    let totalCost: Double
    let averagePricePerLiter: Double?
    let lastFillUp: FuelLogRecord?
    let lastValidConsumption: FuelMetricValue
    let rollingThreeCycleAverage: FuelMetricValue
    let rollingSixCycleAverage: FuelMetricValue
    let averageCostPer100Km: FuelMetricValue
    let spendThisMonth: Double
    let spendThisYear: Double
    let highestPricePerLiter: Double?
    let lowestPricePerLiter: Double?
    let totalTrackedDistanceKm: Int
    let validCycleCount: Int
}

struct FuelLogAnalysis {
    let period: FuelLogPeriod
    let allEntries: [FuelLogRecord]
    let filteredEntries: [FuelLogRecord]
    let entryInsights: [UUID: FuelEntryInsight]
    let validCycles: [FuelCycle]
    let filteredValidCycles: [FuelCycle]
    let insights: FuelLogInsights

    func insight(for entry: FuelEntry) -> FuelEntryInsight? {
        entryInsights[entry.id]
    }

    func chartPoints(for metric: FuelChartMetric) -> [FuelTrendPoint] {
        switch metric {
        case .spend:
            return groupedMonthlySpendPoints(from: filteredEntries)
        case .consumption:
            return filteredValidCycles.map {
                FuelTrendPoint(
                    id: $0.id,
                    date: $0.endDate,
                    label: AppFormatters.mediumDate.string(from: $0.endDate),
                    value: $0.consumption
                )
            }
        case .price:
            return filteredEntries.compactMap { entry in
                guard let price = entry.pricePerLiter else { return nil }
                return FuelTrendPoint(
                    id: entry.id,
                    date: entry.date,
                    label: AppFormatters.mediumDate.string(from: entry.date),
                    value: price
                )
            }
        }
    }

    private func groupedMonthlySpendPoints(from entries: [FuelLogRecord]) -> [FuelTrendPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        }

        return grouped
            .map { month, monthEntries in
                FuelTrendPoint(
                    id: UUID(),
                    date: month,
                    label: AppFormatters.monthYear.string(from: month),
                    value: monthEntries.compactMap(\.totalCost).reduce(0, +)
                )
            }
            .sorted { $0.date < $1.date }
    }
}

enum FuelLogEngine {
    struct Configuration {
        let minimumMeaningfulDistanceKm: Int

        static let `default` = Configuration(minimumMeaningfulDistanceKm: 50)
    }

    static func analyze(
        entries: [FuelEntry],
        period: FuelLogPeriod = .allTime,
        referenceDate: Date = .now,
        configuration: Configuration = .default
    ) -> FuelLogAnalysis {
        analyze(
            records: entries.map(\.fuelLogRecord),
            period: period,
            referenceDate: referenceDate,
            configuration: configuration
        )
    }

    static func analyze(
        records: [FuelLogRecord],
        period: FuelLogPeriod = .allTime,
        referenceDate: Date = .now,
        configuration: Configuration = .default
    ) -> FuelLogAnalysis {
        let ordered = sort(records)
        let computation = buildInsights(for: ordered, configuration: configuration)
        let filteredEntries = filter(entries: ordered, for: period, referenceDate: referenceDate)
        let filteredIDs = Set(filteredEntries.map(\.id))
        let filteredValidCycles = computation.validCycles.filter { filteredIDs.contains($0.endEntryID) }
        let insights = makeInsights(
            allEntries: ordered,
            filteredEntries: filteredEntries,
            filteredValidCycles: filteredValidCycles,
            referenceDate: referenceDate
        )

        return FuelLogAnalysis(
            period: period,
            allEntries: ordered,
            filteredEntries: filteredEntries,
            entryInsights: computation.entryInsights,
            validCycles: computation.validCycles,
            filteredValidCycles: filteredValidCycles,
            insights: insights
        )
    }

    static func sort(_ records: [FuelLogRecord]) -> [FuelLogRecord] {
        records.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.odometerKm != $1.odometerKm { return $0.odometerKm < $1.odometerKm }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func filter(
        entries: [FuelLogRecord],
        for period: FuelLogPeriod,
        referenceDate: Date = .now
    ) -> [FuelLogRecord] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current

        switch period {
        case .allTime:
            return entries
        case .days30:
            let threshold = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? .distantPast
            return entries.filter { $0.date >= threshold }
        case .days90:
            let threshold = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? .distantPast
            return entries.filter { $0.date >= threshold }
        case .months12:
            let threshold = calendar.date(byAdding: .month, value: -12, to: referenceDate) ?? .distantPast
            return entries.filter { $0.date >= threshold }
        case .currentTank:
            if let startIndex = entries.lastIndex(where: { $0.entryType == .fullFillUp || $0.entryType == .initialTank }) {
                return Array(entries[startIndex...])
            }
            return entries
        }
    }

    private struct PendingWindow {
        var start: FuelLogRecord?
        var accumulatedLiters = 0.0
        var accumulatedCost = 0.0
        var includedEntryIDs: [UUID] = []
        var isBroken = false

        mutating func reset(start: FuelLogRecord?) {
            self.start = start
            accumulatedLiters = 0
            accumulatedCost = 0
            includedEntryIDs = []
            isBroken = false
        }
    }

    private struct ComputationResult {
        let entryInsights: [UUID: FuelEntryInsight]
        let validCycles: [FuelCycle]
    }

    private static func buildInsights(
        for entries: [FuelLogRecord],
        configuration: Configuration
    ) -> ComputationResult {
        var previous: FuelLogRecord?
        var entryInsights: [UUID: FuelEntryInsight] = [:]
        var validCycles: [FuelCycle] = []
        var window = PendingWindow()

        for entry in entries {
            let distanceSincePrevious = previous.flatMap { positiveDistance(from: $0.odometerKm, to: entry.odometerKm) }
            let distanceSinceSequenceStart = window.start.flatMap { positiveDistance(from: $0.odometerKm, to: entry.odometerKm) }

            var status: FuelCycleStatus = .pending
            var note: String?
            var cycleConsumption: Double?
            var cycleCostPer100Km: Double?

            switch entry.entryType {
            case .initialTank:
                status = .pending
                note = "Starts the fuel log."
                window.reset(start: entry)

            case .missedFillUp:
                status = .invalid
                note = "Consumption unavailable due to a missed entry."
                window.isBroken = true

            case .partialFillUp:
                if let liters = entry.liters, let totalCost = entry.totalCost, liters > 0, totalCost >= 0, window.start != nil, !window.isBroken {
                    window.accumulatedLiters += liters
                    window.accumulatedCost += totalCost
                    window.includedEntryIDs.append(entry.id)
                }

                if window.start == nil {
                    note = "Add a full fill-up to begin consumption tracking."
                } else if window.isBroken {
                    status = .invalid
                    note = "Sequence is incomplete until the next full fill-up."
                } else {
                    note = "Included in the current full-to-full cycle."
                }

            case .fullFillUp:
                guard let currentLiters = positiveValue(entry.liters),
                      let currentCost = nonNegativeValue(entry.totalCost)
                else {
                    status = .invalid
                    note = "Fuel amount or total price is missing."
                    window.reset(start: entry)
                    entryInsights[entry.id] = FuelEntryInsight(
                        entryID: entry.id,
                        distanceSincePreviousEntryKm: distanceSincePrevious,
                        distanceSinceSequenceStartKm: distanceSinceSequenceStart,
                        pricePerLiter: entry.pricePerLiter,
                        cycleConsumption: nil,
                        cycleCostPer100Km: nil,
                        status: status,
                        note: note
                    )
                    previous = entry
                    continue
                }

                if window.start == nil {
                    note = "Begins a new fuel cycle."
                    window.reset(start: entry)
                } else if window.isBroken {
                    status = .invalid
                    note = "Starts a new accurate cycle after the missed entry."
                    window.reset(start: entry)
                } else if let start = window.start,
                          let distance = positiveDistance(from: start.odometerKm, to: entry.odometerKm) {
                    let liters = window.accumulatedLiters + currentLiters
                    let totalCost = window.accumulatedCost + currentCost

                    if distance < configuration.minimumMeaningfulDistanceKm {
                        note = "Not enough data yet."
                    } else if liters <= 0 {
                        note = "Waiting for enough fuel data."
                    } else {
                        let consumption = liters / Double(distance) * 100
                        let costPer100Km = totalCost / Double(distance) * 100
                        cycleConsumption = consumption
                        cycleCostPer100Km = costPer100Km
                        status = .valid
                        note = nil

                        validCycles.append(
                            FuelCycle(
                                id: entry.id,
                                startEntryID: start.id,
                                endEntryID: entry.id,
                                startDate: start.date,
                                endDate: entry.date,
                                distanceKm: distance,
                                liters: liters,
                                totalCost: totalCost,
                                consumption: consumption,
                                costPer100Km: costPer100Km,
                                includedEntryIDs: window.includedEntryIDs + [entry.id]
                            )
                        )
                    }

                    window.reset(start: entry)
                } else {
                    status = .invalid
                    note = "Odometer progression is invalid."
                    window.reset(start: entry)
                }
            }

            entryInsights[entry.id] = FuelEntryInsight(
                entryID: entry.id,
                distanceSincePreviousEntryKm: distanceSincePrevious,
                distanceSinceSequenceStartKm: distanceSinceSequenceStart,
                pricePerLiter: entry.pricePerLiter,
                cycleConsumption: cycleConsumption,
                cycleCostPer100Km: cycleCostPer100Km,
                status: status,
                note: note
            )

            previous = entry
        }

        return ComputationResult(entryInsights: entryInsights, validCycles: validCycles)
    }

    private static func makeInsights(
        allEntries: [FuelLogRecord],
        filteredEntries: [FuelLogRecord],
        filteredValidCycles: [FuelCycle],
        referenceDate: Date
    ) -> FuelLogInsights {
        let allCostEntries = filteredEntries.compactMap(\.totalCost)
        let allLitersEntries = filteredEntries.compactMap(\.liters)
        let totalCost = allCostEntries.reduce(0, +)
        let totalLiters = allLitersEntries.reduce(0, +)
        let averagePricePerLiter = totalLiters > 0 ? totalCost / totalLiters : nil
        let priceValues = filteredEntries.compactMap(\.pricePerLiter)
        let lastFillUp = filteredEntries.last(where: { $0.entryType != .missedFillUp })
        let trackedDistance = totalTrackedDistance(in: filteredEntries)
        let costPer100Km = metricFromValidCycles(
            filteredValidCycles,
            minRequiredCount: 1,
            value: {
                let totalDistance = filteredValidCycles.reduce(0) { $0 + $1.distanceKm }
                guard totalDistance > 0 else { return nil }
                let totalCost = filteredValidCycles.reduce(0) { $0 + $1.totalCost }
                return totalCost / Double(totalDistance) * 100
            },
            emptyStateNote: availabilityNote(from: filteredEntries)
        )

        return FuelLogInsights(
            totalLiters: totalLiters,
            totalCost: totalCost,
            averagePricePerLiter: averagePricePerLiter,
            lastFillUp: lastFillUp,
            lastValidConsumption: metricFromValidCycles(
                filteredValidCycles,
                minRequiredCount: 1,
                value: { filteredValidCycles.last?.consumption },
                emptyStateNote: availabilityNote(from: filteredEntries)
            ),
            rollingThreeCycleAverage: metricFromValidCycles(
                filteredValidCycles,
                minRequiredCount: 3,
                value: { average(filteredValidCycles.suffix(3).map(\.consumption)) },
                emptyStateNote: "Available after 3 valid cycles."
            ),
            rollingSixCycleAverage: metricFromValidCycles(
                filteredValidCycles,
                minRequiredCount: 6,
                value: { average(filteredValidCycles.suffix(6).map(\.consumption)) },
                emptyStateNote: "Available after 6 valid cycles."
            ),
            averageCostPer100Km: costPer100Km,
            spendThisMonth: spend(in: .month, entries: allEntries, referenceDate: referenceDate),
            spendThisYear: spend(in: .year, entries: allEntries, referenceDate: referenceDate),
            highestPricePerLiter: priceValues.max(),
            lowestPricePerLiter: priceValues.min(),
            totalTrackedDistanceKm: trackedDistance,
            validCycleCount: filteredValidCycles.count
        )
    }

    private static func spend(
        in component: Calendar.Component,
        entries: [FuelLogRecord],
        referenceDate: Date
    ) -> Double {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDate($0.date, equalTo: referenceDate, toGranularity: component) }
            .compactMap(\.totalCost)
            .reduce(0, +)
    }

    private static func availabilityNote(from entries: [FuelLogRecord]) -> String {
        if entries.isEmpty {
            return "Add your first fuel entry."
        }
        if entries.contains(where: { $0.entryType == .missedFillUp }) {
            return "Consumption unavailable due to incomplete fuel sequence."
        }
        if entries.contains(where: { $0.entryType == .fullFillUp || $0.entryType == .initialTank }) {
            return "Waiting for first full-to-full cycle."
        }
        return "Not enough data yet."
    }

    private static func metricFromValidCycles(
        _ cycles: [FuelCycle],
        minRequiredCount: Int,
        value: () -> Double?,
        emptyStateNote: String
    ) -> FuelMetricValue {
        guard cycles.count >= minRequiredCount else {
            return FuelMetricValue(value: nil, note: emptyStateNote)
        }
        return FuelMetricValue(value: value(), note: nil)
    }

    private static func totalTrackedDistance(in entries: [FuelLogRecord]) -> Int {
        guard entries.count >= 2 else { return 0 }

        return zip(entries, entries.dropFirst()).reduce(0) { runningTotal, pair in
            runningTotal + max(pair.1.odometerKm - pair.0.odometerKm, 0)
        }
    }

    private static func positiveDistance(from start: Int, to end: Int) -> Int? {
        let distance = end - start
        return distance > 0 ? distance : nil
    }

    private static func positiveValue(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private static func nonNegativeValue(_ value: Double?) -> Double? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

extension FuelEntry {
    var fuelLogRecord: FuelLogRecord {
        FuelLogRecord(
            id: id,
            date: date,
            odometerKm: odometerKm,
            liters: liters > 0 ? liters : nil,
            totalCost: totalCost > 0 ? totalCost : (entryType.requiresFuelAmounts ? nil : totalCost),
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
