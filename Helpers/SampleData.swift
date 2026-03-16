import SwiftData
import Foundation

enum PreviewData {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            ServiceEntry.self,
            AttachmentRecord.self,
            ReminderItem.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        seedIfNeeded(context: container.mainContext)
        return container
    }

    @MainActor
    private static func seedIfNeeded(context: ModelContext) {
        guard (try? context.fetch(FetchDescriptor<Vehicle>()).isEmpty) != false else { return }

        let audi = Vehicle(
            make: "Audi",
            model: "A4 Avant",
            year: 2019,
            licensePlate: "B-CP 419",
            currentMileage: 86_200,
            purchaseDate: Calendar.current.date(byAdding: .year, value: -3, to: .now),
            purchasePrice: 24_500,
            currencyCode: "EUR",
            vin: "WAUZZZ8K1KA123456",
            notes: "Primary family car. Dealer serviced in the first two years."
        )

        let bmw = Vehicle(
            make: "BMW",
            model: "320d Touring",
            year: 2016,
            licensePlate: "M-CP 320",
            currentMileage: 143_000,
            purchaseDate: Calendar.current.date(byAdding: .year, value: -5, to: .now),
            purchasePrice: 17_900,
            currencyCode: "EUR",
            vin: "WBA8K31020K987654"
        )

        let mini = Vehicle(
            make: "Mini",
            model: "Cooper S",
            year: 2021,
            licensePlate: "HH-MS 021",
            currentMileage: 31_500,
            purchaseDate: Calendar.current.date(byAdding: .year, value: -2, to: .now),
            purchasePrice: 27_200,
            currencyCode: "EUR"
        )

        [audi, bmw, mini].forEach(context.insert)

        let oil = ServiceEntry(vehicle: audi, date: Calendar.current.date(byAdding: .month, value: -2, to: .now)!, mileage: 82_100, serviceType: .oilChange, price: 189, currencyCode: "EUR", workshopName: "Autohaus Keller", notes: "Long-life oil and filter.")
        let brakes = ServiceEntry(vehicle: audi, date: Calendar.current.date(byAdding: .month, value: -8, to: .now)!, mileage: 74_000, serviceType: .brakes, category: .repair, price: 640, currencyCode: "EUR", workshopName: "Brake Center Berlin", notes: "Front pads and discs.", isImportant: true)
        let inspection = ServiceEntry(vehicle: bmw, date: Calendar.current.date(byAdding: .month, value: -1, to: .now)!, mileage: 141_200, serviceType: .inspection, price: 320, currencyCode: "EUR", workshopName: "Munich Service Works")
        let tires = ServiceEntry(vehicle: bmw, date: Calendar.current.date(byAdding: .month, value: -5, to: .now)!, mileage: 137_400, serviceType: .tires, price: 470, currencyCode: "EUR", workshopName: "Seasonal Tire House", notes: "Winter set mounted.")
        let insurance = ServiceEntry(vehicle: mini, date: Calendar.current.date(byAdding: .day, value: -20, to: .now)!, mileage: 30_900, serviceType: .insurance, category: .administration, price: 560, currencyCode: "EUR", workshopName: "Nordic Insurance")
        [oil, brakes, inspection, tires, insurance].forEach(context.insert)

        let reminder1 = ReminderItem(vehicle: audi, serviceEntry: oil, type: .oilChange, title: "Oil change due", dateDue: Calendar.current.date(byAdding: .month, value: 10, to: .now), mileageDue: 92_000, notificationTiming: .sevenDaysBefore, isEnabled: true)
        let reminder2 = ReminderItem(vehicle: bmw, serviceEntry: inspection, type: .inspection, title: "Annual inspection", dateDue: Calendar.current.date(byAdding: .month, value: 11, to: .now), notificationTiming: .thirtyDaysBefore, isEnabled: true)
        let reminder3 = ReminderItem(vehicle: mini, type: .insurance, title: "Insurance renewal", dateDue: Calendar.current.date(byAdding: .month, value: 1, to: .now), notificationTiming: .sevenDaysBefore, isEnabled: true)
        [reminder1, reminder2, reminder3].forEach(context.insert)

        let attachment1 = AttachmentRecord(vehicle: audi, serviceEntry: oil, type: .pdf, filename: "Oil Change Invoice.pdf", storageReference: "preview-invoice.pdf")
        let attachment2 = AttachmentRecord(vehicle: bmw, serviceEntry: tires, type: .image, filename: "Tire Condition.jpg", storageReference: "preview-tires.jpg", thumbnailReference: "preview-tires-thumb.jpg")
        let attachment3 = AttachmentRecord(vehicle: mini, type: .pdf, filename: "Insurance Contract.pdf", storageReference: "preview-insurance.pdf")
        [attachment1, attachment2, attachment3].forEach(context.insert)

        try? context.save()
    }

    @MainActor
    static func generateMockVehicle(in context: ModelContext) {
        let golf = Vehicle(
            make: "Volkswagen",
            model: "Golf 8",
            year: 2021,
            licensePlate: "BG 123-AB",
            currentMileage: 68_500,
            purchaseDate: Calendar.current.date(byAdding: .year, value: -4, to: .now),
            purchasePrice: 22_000,
            currencyCode: "EUR",
            vin: "WVWZZZCDZLW133742",
            notes: "Test mock data car with lots of history."
        )
        context.insert(golf)

        let services: [(type: ServiceType, monthsAgo: Int, mileage: Int, price: Double)] = [
            (.inspection, 45, 12_000, 250.0),
            (.oilChange, 40, 18_000, 150.0),
            (.tires, 36, 22_000, 400.0),
            (.airConditioning, 30, 30_000, 120.0),
            (.oilChange, 24, 40_000, 160.0),
            (.brakes, 18, 48_000, 350.0),
            (.inspection, 12, 55_000, 280.0),
            (.oilChange, 6, 62_000, 180.0),
            (.battery, 2, 67_000, 210.0),
            (.washDetailing, 0, 68_500, 50.0)
        ]

        for s in services {
            var date = Calendar.current.date(byAdding: .month, value: -s.monthsAgo, to: .now)!
            date = Calendar.current.date(byAdding: .day, value: Int.random(in: -15...15), to: date) ?? date

            let entry = ServiceEntry(
                vehicle: golf,
                date: date,
                mileage: s.mileage,
                serviceType: s.type,
                price: s.price,
                currencyCode: "EUR",
                workshopName: "Mock Auto Center"
            )
            context.insert(entry)
        }

        let reminder = ReminderItem(
            vehicle: golf,
            type: .oilChange,
            title: "Next Oil Change",
            dateDue: Calendar.current.date(byAdding: .month, value: 6, to: .now),
            mileageDue: 75_000,
            isEnabled: true
        )
        context.insert(reminder)

        try? context.save()
    }
}