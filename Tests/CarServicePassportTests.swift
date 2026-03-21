import XCTest
@testable import Car_Service_Passport

final class CarServicePassportTests: XCTestCase {
    func testParseDecimalSupportsCommaSeparator() throws {
        let parsed = try XCTUnwrap(UnitFormatter.parseDecimal("123,45"))
        XCTAssertEqual(parsed, 123.45, accuracy: 0.000_1)
    }

    func testDecimalInputStringRoundTripsFractionalValues() throws {
        let text = UnitFormatter.decimalInputString(123.45)
        let parsed = try XCTUnwrap(UnitFormatter.parseDecimal(text))
        XCTAssertEqual(parsed, 123.45, accuracy: 0.01)
    }

    @MainActor
    func testStoredReferencesCollectsAllVehicleAssets() {
        let vehicle = Vehicle(make: "Audi", model: "A4", year: 2022, currentMileage: 12_000)
        vehicle.coverImageReference = "cover.jpg"

        let service = ServiceEntry(vehicle: vehicle, mileage: 11_000, serviceType: .oilChange)
        let attachment = AttachmentRecord(
            vehicle: vehicle,
            serviceEntry: service,
            type: .image,
            filename: "receipt.jpg",
            storageReference: "legacy.jpg",
            thumbnailReference: "legacy-thumb.jpg"
        )
        vehicle.attachments = [attachment]

        let document = DocumentRecord(vehicle: vehicle, title: "Registration")
        let page = DocumentPageRecord(
            document: document,
            orderIndex: 0,
            type: .pdf,
            filename: "registration.pdf",
            storageReference: "doc.pdf",
            thumbnailReference: "doc-thumb.jpg"
        )
        document.pages = [page]
        vehicle.documents = [document]

        let fuelEntry = FuelEntry(
            vehicle: vehicle,
            mileage: 12_000,
            liters: 40,
            totalCost: 80,
            receiptStorageReference: "fuel.jpg",
            receiptThumbnailReference: "fuel-thumb.jpg"
        )
        vehicle.fuelEntries = [fuelEntry]

        let references = Set(AppDataMaintenanceService.storedReferences(for: vehicle))
        XCTAssertEqual(
            references,
            Set([
                "cover.jpg",
                "legacy.jpg",
                "legacy-thumb.jpg",
                "doc.pdf",
                "doc-thumb.jpg",
                "fuel.jpg",
                "fuel-thumb.jpg"
            ])
        )
    }

    @MainActor
    func testNotificationIdentifiersDeduplicateAndIgnoreNil() {
        let vehicle = Vehicle(make: "VW", model: "Golf", year: 2020, currentMileage: 50_000)
        let first = ReminderItem(vehicle: vehicle, type: .inspection, title: "Inspection", notificationIdentifier: "abc")
        let duplicate = ReminderItem(vehicle: vehicle, type: .inspection, title: "Inspection 2", notificationIdentifier: "abc")
        let second = ReminderItem(vehicle: vehicle, type: .insurance, title: "Insurance", notificationIdentifier: "xyz")
        let none = ReminderItem(vehicle: vehicle, type: .registration, title: "Registration", notificationIdentifier: nil)

        let identifiers = Set(AppDataMaintenanceService.notificationIdentifiers(for: [first, duplicate, second, none]))
        XCTAssertEqual(identifiers, Set(["abc", "xyz"]))
    }
}
