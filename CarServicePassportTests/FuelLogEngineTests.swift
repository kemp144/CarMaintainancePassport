import XCTest
@testable import CarServicePassport

final class FuelLogEngineTests: XCTestCase {

    // Helper za kreiranje unosnog podatka (FuelEntry)
    private func createEntry(date: Date, odometer: Int, liters: Double, cost: Double, isFull: Bool, type: FuelEntryType = .full) -> FuelEntry {
        FuelEntry(
            date: date,
            odometerKm: odometer,
            liters: liters,
            pricePerLiter: cost / (liters > 0 ? liters : 1),
            totalCost: cost,
            isFullTank: isFull,
            entryType: type,
            station: "Test Station",
            notes: "",
            currencyCode: "EUR",
            receiptStorageReference: nil
        )
    }

    // 1. Osovni test kalkulacije između dva puna rezervoara
    func testSimpleFullToFullCycle() {
        let entry1 = createEntry(date: Date().addingTimeInterval(-86400 * 10), odometer: 10000, liters: 40, cost: 60, isFull: true)
        let entry2 = createEntry(date: Date(), odometer: 10500, liters: 30, cost: 45, isFull: true)
        
        let entries = [entry1, entry2]
        
        let analysis = FuelAnalyticsService.analysis(for: entries, period: .allTime)
        
        // 30 litara potrošeno za 500 km = (30 / 500) * 100 = 6.0 L/100km
        XCTAssertEqual(analysis.insights.validCycleCount, 1)
        XCTAssertEqual(analysis.insights.lastValidConsumption.value, 6.0, accuracy: 0.01)
        XCTAssertEqual(analysis.insights.totalCost, 105.0)
        XCTAssertEqual(analysis.insights.totalLiters, 70.0)
    }

    // 2. Test ignorisanja delimičnih (partial) sipanja kod ciklusa
    func testPartialFillUpBreaksCycle() {
        let entry1 = createEntry(date: Date().addingTimeInterval(-86400 * 10), odometer: 10000, liters: 40, cost: 60, isFull: true)
        let entry2 = createEntry(date: Date().addingTimeInterval(-86400 * 5), odometer: 10300, liters: 15, cost: 20, isFull: false, type: .partial)
        let entry3 = createEntry(date: Date(), odometer: 10600, liters: 35, cost: 50, isFull: true)
        
        let entries = [entry1, entry2, entry3]
        
        let analysis = FuelAnalyticsService.analysis(for: entries, period: .allTime)
        
        // Ciklus 1 (E1 -> E2) ne bi trebao da postoji kao validan jer E2 nije full.
        // Sistem treba ili da spoji E2 i E3, ili da ignoriše E2. Zavisno od implementacije.
        // U oba slučaja ne bi smelo da prijavi netačan visok/nizak consumption.
        
        // Ukupni troškovi bi trebali biti tačni bez obzira na cycle: 60 + 20 + 50 = 130
        XCTAssertEqual(analysis.insights.totalCost, 130.0)
        XCTAssertEqual(analysis.insights.totalLiters, 90.0)
    }

    // 3. Test propuštenog sipanja (missed fill-up)
    func testMissedFillUpBreaksChain() {
        let entry1 = createEntry(date: Date().addingTimeInterval(-86400 * 15), odometer: 10000, liters: 40, cost: 60, isFull: true)
        let entry2 = createEntry(date: Date().addingTimeInterval(-86400 * 10), odometer: 10500, liters: 40, cost: 60, isFull: true)
        let entry3 = createEntry(date: Date().addingTimeInterval(-86400 * 5), odometer: 11000, liters: 0, cost: 0, isFull: false, type: .missedFillUp) // propušteno!
        let entry4 = createEntry(date: Date(), odometer: 11500, liters: 40, cost: 60, isFull: true)
        
        let entries = [entry1, entry2, entry3, entry4]
        
        let analysis = FuelAnalyticsService.analysis(for: entries, period: .allTime)
        
        // E1 -> E2 je validan (1 ciklus)
        // E2 -> E3 je missed, E3 -> E4 je razbijen lanac
        XCTAssertEqual(analysis.insights.validCycleCount, 1)
        XCTAssertEqual(analysis.insights.totalCost, 180.0)
    }

    // 4. Test za obradu prazne liste
    func testEmptyLog() {
        let analysis = FuelAnalyticsService.analysis(for: [], period: .allTime)
        
        XCTAssertEqual(analysis.insights.validCycleCount, 0)
        XCTAssertEqual(analysis.insights.totalCost, 0)
        XCTAssertEqual(analysis.insights.totalLiters, 0)
        XCTAssertNil(analysis.insights.lastValidConsumption.value)
    }
}
