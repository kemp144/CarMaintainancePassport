import SwiftData
import Foundation

enum PreviewData {
    private static let demoVehicleVINs = [
        "WAUZZZF48KA123456",
        "WVWZZZCDZMW133742",
        "VF3MCYHZRKS998877",
        "SALWA2AK9LA765432"
    ]

    static let fullDemoPrimaryVIN = "SALWA2AK9LA765432"
    static let partialDemoPrimaryVIN = "TMBJH7NE0L0123456"

    enum DemoGarageVariant {
        case full
        case partial
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            ServiceEntry.self,
            AttachmentRecord.self,
            DocumentRecord.self,
            DocumentPageRecord.self,
            ReminderItem.self,
            FuelEntry.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        seedIfNeeded(context: container.mainContext)
        return container
    }

    @MainActor
    static func generateDemoGarage(in context: ModelContext) {
        generateFullDemoGarage(in: context)
    }

    @MainActor
    static func generateFullDemoGarage(in context: ModelContext) {
        replaceGarageData(in: context, variant: .full)
    }

    @MainActor
    static func generatePartialDemoGarage(in context: ModelContext) {
        replaceGarageData(in: context, variant: .partial)
    }

    @MainActor
    private static func replaceGarageData(in context: ModelContext, variant: DemoGarageVariant) {
        clearAllData(in: context)

        switch variant {
        case .full:
            seedFullDemoGarage(in: context)
        case .partial:
            seedPartialDemoGarage(in: context)
        }
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
            notes: "Primary family car. Dealer-serviced during the first two years."
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

        let fuelEntries = [
            FuelEntry(vehicle: audi, date: Calendar.current.date(byAdding: .day, value: -40, to: .now)!, mileage: 84_000, liters: 0, totalCost: 0, currencyCode: "EUR", entryType: .initialTank, fuelTypeName: "Diesel", station: "Aral"),
            FuelEntry(vehicle: audi, date: Calendar.current.date(byAdding: .day, value: -28, to: .now)!, mileage: 84_510, liters: 24.6, totalCost: 44.70, currencyCode: "EUR", entryType: .partialFillUp, fuelTypeName: "Diesel", station: "Shell"),
            FuelEntry(vehicle: audi, date: Calendar.current.date(byAdding: .day, value: -15, to: .now)!, mileage: 85_180, liters: 38.4, totalCost: 68.35, currencyCode: "EUR", entryType: .fullFillUp, fuelTypeName: "Diesel", station: "Aral"),
            FuelEntry(vehicle: audi, date: Calendar.current.date(byAdding: .day, value: -4, to: .now)!, mileage: 85_690, liters: 31.9, totalCost: 58.10, currencyCode: "EUR", entryType: .fullFillUp, fuelTypeName: "Diesel", station: "Aral"),
            FuelEntry(vehicle: bmw, date: Calendar.current.date(byAdding: .day, value: -34, to: .now)!, mileage: 140_300, liters: 0, totalCost: 0, currencyCode: "EUR", entryType: .initialTank, fuelTypeName: "Diesel", station: "OMV"),
            FuelEntry(vehicle: bmw, date: Calendar.current.date(byAdding: .day, value: -22, to: .now)!, mileage: 140_960, liters: 42.5, totalCost: 76.90, currencyCode: "EUR", entryType: .fullFillUp, fuelTypeName: "Diesel", station: "OMV"),
            FuelEntry(vehicle: bmw, date: Calendar.current.date(byAdding: .day, value: -11, to: .now)!, mileage: 141_540, liters: 39.2, totalCost: 71.85, currencyCode: "EUR", entryType: .fullFillUp, fuelTypeName: "Diesel", station: "Shell"),
            FuelEntry(vehicle: mini, date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!, mileage: 30_250, liters: 0, totalCost: 0, currencyCode: "EUR", entryType: .initialTank, fuelTypeName: "Premium 95", station: "NIS"),
            FuelEntry(vehicle: mini, date: Calendar.current.date(byAdding: .day, value: -19, to: .now)!, mileage: 30_620, liters: 18.7, totalCost: 33.45, currencyCode: "EUR", entryType: .partialFillUp, fuelTypeName: "Premium 95", station: "NIS"),
            FuelEntry(vehicle: mini, date: Calendar.current.date(byAdding: .day, value: -9, to: .now)!, mileage: 31_040, liters: 21.4, totalCost: 39.20, currencyCode: "EUR", entryType: .fullFillUp, fuelTypeName: "Premium 95", station: "MOL")
        ]
        fuelEntries.forEach(context.insert)

        try? context.save()
    }

    @MainActor
    private static func seedFullDemoGarage(in context: ModelContext) {
        let existingVehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        let existingVehiclesByVIN: [String: Vehicle] = Dictionary(
            uniqueKeysWithValues: existingVehicles.compactMap { vehicle in
                guard !vehicle.vin.isEmpty else { return nil }
                return (vehicle.vin, vehicle)
            }
        )

        let audi = existingVehiclesByVIN["WAUZZZF48KA123456"] ?? Vehicle(
            make: "Audi",
            model: "A4 Avant 40 TDI",
            year: 2019,
            licensePlate: "BG-419-CP",
            currentMileage: 126_420,
            purchaseDate: date(yearsAgo: 4, monthsAgo: 2),
            purchasePrice: 25_900,
            currencyCode: "EUR",
            vin: "WAUZZZF48KA123456",
            notes: "Family car for longer trips. Regularly serviced with a complete maintenance history."
        )
        if existingVehiclesByVIN["WAUZZZF48KA123456"] == nil {
            context.insert(audi)
        }

        let golf = existingVehiclesByVIN["WVWZZZCDZMW133742"] ?? Vehicle(
            make: "Volkswagen",
            model: "Golf 8 1.5 eTSI",
            year: 2021,
            licensePlate: "NS-128-GF",
            currentMileage: 68_500,
            purchaseDate: date(yearsAgo: 3, monthsAgo: 7),
            purchasePrice: 22_000,
            currencyCode: "EUR",
            vin: "WVWZZZCDZMW133742",
            notes: "City car with a complete service book, several seasonal investments, and detailed cost tracking."
        )
        if existingVehiclesByVIN["WVWZZZCDZMW133742"] == nil {
            context.insert(golf)
        }

        let peugeot = existingVehiclesByVIN["VF3MCYHZRKS998877"] ?? Vehicle(
            make: "Peugeot",
            model: "3008 1.6 BlueHDi",
            year: 2018,
            licensePlate: "KG-3008-PG",
            currentMileage: 154_300,
            purchaseDate: date(yearsAgo: 5, monthsAgo: 5),
            purchasePrice: 18_400,
            currencyCode: "EUR",
            vin: "VF3MCYHZRKS998877",
            notes: "Daily family vehicle with enough administrative and mechanical entries to make the timeline feel full."
        )
        if existingVehiclesByVIN["VF3MCYHZRKS998877"] == nil {
            context.insert(peugeot)
        }

        let rangeRover = existingVehiclesByVIN["SALWA2AK9LA765432"] ?? Vehicle(
            make: "Land Rover",
            model: "Range Rover Evoque",
            year: 2020,
            licensePlate: "BG-EVO-777",
            currentMileage: 92_800,
            purchaseDate: date(yearsAgo: 2, monthsAgo: 10),
            purchasePrice: 39_500,
            currencyCode: "EUR",
            vin: "SALWA2AK9LA765432",
            notes: "Premium demo vehicle with higher-cost services, ceramic coating, tires, and registration to exercise analytics."
        )
        if existingVehiclesByVIN["SALWA2AK9LA765432"] == nil {
            context.insert(rangeRover)
        }

        if audi.serviceEntries.isEmpty {
            createEntries(for: audi, in: context, entries: [
                (.inspection, 34, 51_000, 280, "Porsche Inter Auto", "Pre-purchase inspection and full checkup.", false, nil, nil),
                (.oilChange, 30, 61_400, 175, "Porsche Inter Auto", "5W-30 oil and all filters.", false, nil, nil),
                (.brakes, 24, 75_600, 640, "Brake Service Center", "Front pads and rotors.", true, .repair, nil),
                (.tires, 19, 83_000, 780, "Premium Tire Shop", "New summer Michelin Pilot Sport set.", false, nil, nil),
                (.airConditioning, 15, 91_200, 135, "Auto AC 021", "Refrigerant top-up and disinfection.", false, nil, nil),
                (.oilChange, 10, 102_500, 189, "Porsche Inter Auto", "Regular minor service.", false, nil, nil),
                (.battery, 6, 113_900, 245, "Battery Shop", "Battery replaced before winter.", false, .repair, nil),
                (.inspection, 2, 124_800, 320, "Porsche Inter Auto", "Annual inspection and diagnostics.", true, nil, nil)
            ])
        }

        if golf.serviceEntries.isEmpty {
            createEntries(for: golf, in: context, entries: [
                (.inspection, 28, 12_000, 210, "VW Novi Sad", "First inspection after purchase.", false, nil, nil),
                (.oilChange, 24, 19_800, 155, "VW Novi Sad", "Oil and cabin filter.", false, nil, nil),
                (.tires, 18, 29_200, 520, "Tire Pro", "Winter tires, 205/55 R16.", false, nil, nil),
                (.filters, 14, 37_000, 96, "VW Novi Sad", "Air and pollen filters.", false, nil, nil),
                (.oilChange, 9, 48_100, 162, "VW Novi Sad", "Minor service and service reset.", false, nil, nil),
                (.washDetailing, 5, 59_400, 85, "Gloss Studio", "Deep clean and interior protection.", false, .care, nil),
                (.insurance, 3, 64_000, 610, "DDOR", "Comprehensive policy renewal.", false, .administration, nil),
                (.registration, 1, 67_900, 340, "Inspection Center Plus", "Registration and inspection.", false, .administration, nil)
            ])
        }

        if peugeot.serviceEntries.isEmpty {
            createEntries(for: peugeot, in: context, entries: [
                (.oilChange, 40, 88_000, 145, "French Auto Service", "Oil and all filters.", false, nil, nil),
                (.repair, 33, 97_500, 420, "French Auto Service", "EGR valve replacement.", true, .repair, nil),
                (.tires, 27, 108_200, 460, "Stop & Go Tires", "All-season tires.", false, nil, nil),
                (.brakes, 20, 119_000, 390, "French Auto Service", "Rear pads and rotor resurfacing.", false, .repair, nil),
                (.inspection, 15, 128_500, 260, "French Auto Service", "Pre-trip service check.", false, nil, nil),
                (.oilChange, 9, 139_700, 168, "French Auto Service", "Minor service with AdBlue top-up.", false, nil, nil),
                (.registration, 4, 149_900, 295, "AMSS", "Vehicle registration.", false, .administration, nil),
                (.custom, 2, 153_800, 110, "Glass Point", "Headlight polishing", false, .care, "Headlight polishing")
            ])
        }

        if rangeRover.serviceEntries.isEmpty {
            createEntries(for: rangeRover, in: context, entries: [
                (.inspection, 22, 24_000, 340, "British Motors", "Premium inspection and health check.", false, nil, nil),
                (.oilChange, 18, 36_500, 240, "British Motors", "Oil, filters, and diagnostics.", false, nil, nil),
                (.washDetailing, 14, 48_200, 180, "Detailing Lab", "Ceramic protection and exterior detailing.", false, .care, nil),
                (.tires, 11, 59_400, 1_120, "Premium Tire House", "Pirelli Scorpion set.", true, nil, nil),
                (.airConditioning, 8, 67_000, 190, "British Motors", "AC service and ventilation cleaning.", false, nil, nil),
                (.insurance, 5, 78_500, 1_480, "Generali", "Comprehensive and mandatory insurance.", false, .administration, nil),
                (.registration, 3, 84_900, 410, "AMSS Premium", "Registration and inspection.", false, .administration, nil),
                (.battery, 1, 91_600, 310, "Battery Shop", "New AGM battery.", false, .repair, nil)
            ])

            createEntries(for: rangeRover, in: context, entries: [
                (.inspection, 24, 16_800, 360, "British Motors", "First major inspection and condition assessment.", false, nil, nil),
                (.oilChange, 22, 22_100, 245, "British Motors", "First oil change after purchase.", false, nil, nil),
                (.tires, 20, 27_600, 1_080, "Premium Tire House", "Summer set and balancing.", false, nil, nil),
                (.brakes, 18, 33_400, 920, "British Motors", "Front brakes and braking system service.", true, .repair, nil),
                (.airConditioning, 16, 38_900, 190, "British Motors", "AC service and cabin disinfection.", false, nil, nil),
                (.oilChange, 14, 44_500, 255, "British Motors", "Regular oil and filter service.", false, nil, nil),
                (.registration, 12, 50_300, 410, "AMSS Premium", "Registration and inspection.", false, .administration, nil),
                (.inspection, 10, 56_200, 340, "British Motors", "Annual inspection and diagnostics.", false, nil, nil),
                (.battery, 8, 61_700, 295, "Battery Shop", "New battery coding and verification.", false, .repair, nil),
                (.oilChange, 6, 67_400, 260, "British Motors", "Second oil change in a long-cycle plan.", false, nil, nil),
                (.tires, 4, 73_600, 1_120, "Premium Tire House", "Winter Pirelli Scorpion set.", false, nil, nil),
                (.brakes, 2, 79_100, 910, "British Motors", "Rear brake service.", false, .repair, nil),
                (.filters, 1, 84_300, 125, "British Motors", "Air and cabin filters.", false, nil, nil),
                (.inspection, 0, 88_900, 340, "British Motors", "Most recent inspection before analytics.", false, nil, nil)
            ])
        }

        if audi.fuelEntries.isEmpty {
            createFuelEntries(for: audi, in: context, entries: [
                (.initialTank, 130, 118_420, 0, 0, "Diesel", "OMV", "Fuel tracking started after purchase."),
                (.partialFillUp, 116, 119_060, 21.4, 36.10, "Diesel", "Shell", ""),
                (.fullFillUp, 101, 119_880, 43.8, 74.05, "Diesel", "OMV", ""),
                (.fullFillUp, 84, 120_710, 47.1, 81.60, "Diesel", "OMV", ""),
                (.partialFillUp, 66, 121_330, 18.3, 32.55, "Diesel", "MOL", "Top-up before a trip."),
                (.fullFillUp, 51, 122_120, 39.4, 70.15, "Diesel", "Shell", ""),
                (.missedFillUp, 34, 123_020, 0, 0, "Diesel", "", "One fill-up was not logged."),
                (.fullFillUp, 22, 123_690, 44.8, 79.05, "Diesel", "OMV", "Start of a new valid tracking run."),
                (.fullFillUp, 9, 124_560, 46.3, 82.25, "Diesel", "OMV", "")
            ])
        }

        if golf.fuelEntries.isEmpty {
            createFuelEntries(for: golf, in: context, entries: [
                (.initialTank, 118, 61_100, 0, 0, "95", "NIS Petrol", ""),
                (.fullFillUp, 99, 61_720, 35.9, 59.95, "95", "NIS Petrol", ""),
                (.fullFillUp, 82, 62_310, 34.4, 58.10, "95", "MOL", ""),
                (.partialFillUp, 63, 62_710, 16.8, 29.65, "95", "Shell", ""),
                (.fullFillUp, 47, 63_280, 27.5, 48.90, "95", "MOL", ""),
                (.fullFillUp, 28, 63_940, 36.1, 63.55, "95", "OMV", ""),
                (.partialFillUp, 14, 64_330, 14.9, 27.10, "95", "OMV", "Short top-up."),
                (.fullFillUp, 5, 64_910, 24.6, 45.20, "95", "NIS Petrol", "")
            ])
        }

        if peugeot.fuelEntries.isEmpty {
            createFuelEntries(for: peugeot, in: context, entries: [
                (.initialTank, 142, 146_800, 0, 0, "Diesel", "Lukoil", ""),
                (.fullFillUp, 126, 147_620, 48.7, 82.30, "Diesel", "Lukoil", ""),
                (.missedFillUp, 110, 148_540, 0, 0, "Diesel", "", "The owner forgot to log one fill-up."),
                (.fullFillUp, 94, 149_180, 41.6, 73.05, "Diesel", "MOL", "This entry should not affect consumption."),
                (.partialFillUp, 75, 149_620, 19.2, 34.10, "Diesel", "MOL", ""),
                (.fullFillUp, 57, 150_320, 33.8, 60.55, "Diesel", "OMV", "Novi validan ciklus."),
                (.fullFillUp, 38, 151_110, 45.1, 80.90, "Diesel", "Shell", ""),
                (.partialFillUp, 18, 151_540, 20.3, 37.35, "Diesel", "Lukoil", ""),
                (.fullFillUp, 6, 152_240, 31.7, 58.90, "Diesel", "OMV", "")
            ])
        }

        if rangeRover.fuelEntries.isEmpty {
            createFuelEntries(for: rangeRover, in: context, entries: [
                (.initialTank, 138, 83_200, 0, 0, "Premium Diesel", "Shell", "Started the demo fuel log."),
                (.fullFillUp, 126, 84_100, 43.6, 83.30, "Premium Diesel", "Shell", ""),
                (.partialFillUp, 111, 84_520, 22.8, 42.30, "Premium Diesel", "Shell", "City top-up."),
                (.fullFillUp, 104, 84_980, 45.1, 86.90, "Premium Diesel", "OMV MaxxMotion", ""),
                (.fullFillUp, 95, 85_150, 46.4, 88.60, "Premium Diesel", "OMV MaxxMotion", ""),
                (.fullFillUp, 86, 85_540, 44.9, 87.20, "Premium Diesel", "Shell V-Power", ""),
                (.fullFillUp, 78, 85_760, 49.9, 96.80, "Premium Diesel", "OMV MaxxMotion", ""),
                (.partialFillUp, 58, 86_210, 24.1, 47.90, "Premium Diesel", "Shell V-Power", ""),
                (.fullFillUp, 48, 86_520, 41.2, 79.60, "Premium Diesel", "Shell V-Power", ""),
                (.fullFillUp, 40, 86_930, 37.8, 76.15, "Premium Diesel", "Shell V-Power", ""),
                (.fullFillUp, 23, 87_540, 50.6, 101.40, "Premium Diesel", "OMV MaxxMotion", ""),
                (.partialFillUp, 10, 87_980, 18.5, 37.20, "Premium Diesel", "MOL", ""),
                (.fullFillUp, 3, 88_520, 29.4, 59.35, "Premium Diesel", "Shell V-Power", ""),
                (.fullFillUp, 1, 88_760, 41.0, 80.10, "Premium Diesel", "Shell V-Power", "Latest fill-up to keep the fuel analytics current.")
            ])
        }

        if audi.reminders.isEmpty {
            createReminder(for: audi, in: context, type: .oilChange, title: "Audi minor service", notes: "Plan the oil change before the summer trip.", monthsAhead: 4, mileageDue: 132_000, timing: .thirtyDaysBefore)
        }
        if golf.reminders.isEmpty {
            createReminder(for: golf, in: context, type: .registration, title: "Golf registration", notes: "Prepare the policy and inspection.", monthsAhead: 11, mileageDue: nil, timing: .thirtyDaysBefore)
        }
        if peugeot.reminders.isEmpty {
            createReminder(for: peugeot, in: context, type: .inspection, title: "Peugeot suspension check", notes: "Check alignment and balancing after winter.", monthsAhead: 2, mileageDue: 158_000, timing: .sevenDaysBefore)
        }
        if rangeRover.reminders.isEmpty {
            createReminder(for: rangeRover, in: context, type: .insurance, title: "Evoque insurance renewal", notes: "Compare insurance quotes.", monthsAhead: 5, mileageDue: nil, timing: .thirtyDaysBefore)
        }

        if (try? context.fetch(FetchDescriptor<DocumentRecord>()).isEmpty) != false {
            createDocument(
                in: context,
                for: audi,
                serviceEntry: audi.latestService,
                title: "Registration Packet",
                category: .registration,
                documentDate: date(monthsAgo: 2),
                notes: "Scanned registration and inspection paperwork.",
                pages: [
                    (orderIndex: 0, type: .pdf, filename: "Audi Registration.pdf", storageReference: "demo-full-audi-registration-pdf", thumbnailReference: nil),
                    (orderIndex: 1, type: .image, filename: "Audi Registration Card.jpg", storageReference: "demo-full-audi-registration-card", thumbnailReference: "demo-full-audi-registration-card-thumb")
                ]
            )

            createDocument(
                in: context,
                for: golf,
                serviceEntry: golf.sortedServices.first,
                title: "Insurance Policy",
                category: .insurance,
                documentDate: date(monthsAgo: 3),
                notes: "Full policy with renewal details.",
                pages: [
                    (orderIndex: 0, type: .pdf, filename: "Golf Insurance.pdf", storageReference: "demo-full-golf-insurance-pdf", thumbnailReference: nil),
                    (orderIndex: 1, type: .pdf, filename: "Golf Insurance Terms.pdf", storageReference: "demo-full-golf-insurance-terms", thumbnailReference: nil),
                    (orderIndex: 2, type: .image, filename: "Golf Insurance Card.jpg", storageReference: "demo-full-golf-insurance-card", thumbnailReference: "demo-full-golf-insurance-card-thumb")
                ]
            )

            createDocument(
                in: context,
                for: peugeot,
                serviceEntry: peugeot.sortedServices.first,
                title: "Warranty Booklet",
                category: .warranty,
                documentDate: date(monthsAgo: 5),
                notes: "Warranty booklet and service notes.",
                pages: [
                    (orderIndex: 0, type: .pdf, filename: "Peugeot Warranty.pdf", storageReference: "demo-full-peugeot-warranty-pdf", thumbnailReference: nil),
                    (orderIndex: 1, type: .image, filename: "Peugeot Warranty Card.jpg", storageReference: "demo-full-peugeot-warranty-card", thumbnailReference: "demo-full-peugeot-warranty-card-thumb")
                ]
            )

            createDocument(
                in: context,
                for: rangeRover,
                serviceEntry: rangeRover.sortedServices.first,
                title: "Import & Title Documents",
                category: .title,
                documentDate: date(monthsAgo: 10),
                notes: "Import packet and title transfer.",
                pages: [
                    (orderIndex: 0, type: .pdf, filename: "Evoque Import Packet.pdf", storageReference: "demo-full-evoque-import-pdf", thumbnailReference: nil),
                    (orderIndex: 1, type: .pdf, filename: "Evoque Title Transfer.pdf", storageReference: "demo-full-evoque-title-pdf", thumbnailReference: nil)
                ]
            )
        }

        try? context.save()
    }

    @MainActor
    static func generateMockVehicle(in context: ModelContext) {
        generateDemoGarage(in: context)
    }

    @MainActor
    private static func seedPartialDemoGarage(in context: ModelContext) {
        let skoda = Vehicle(
            make: "Skoda",
            model: "Octavia Combi",
            year: 2020,
            licensePlate: "BG-OT-204",
            currentMileage: 88_200,
            purchaseDate: date(yearsAgo: 3, monthsAgo: 4),
            purchasePrice: 16_800,
            currencyCode: "EUR",
            vin: "TMBJH7NE0L0123456",
            notes: "Mixed demo vehicle with some records intentionally missing."
        )

        let fiat = Vehicle(
            make: "Fiat",
            model: "Panda",
            year: 2014,
            licensePlate: "",
            currentMileage: 112_400,
            purchaseDate: nil,
            purchasePrice: nil,
            currencyCode: "EUR",
            vin: "",
            notes: ""
        )

        [skoda, fiat].forEach(context.insert)

        let skodaInspection = ServiceEntry(
            vehicle: skoda,
            date: date(monthsAgo: 7),
            mileage: 72_400,
            serviceType: .inspection,
            price: 180,
            currencyCode: "EUR",
            workshopName: "Autocenter East",
            notes: "Standard annual inspection."
        )
        let skodaOil = ServiceEntry(
            vehicle: skoda,
            date: date(monthsAgo: 4),
            mileage: 78_900,
            serviceType: .oilChange,
            price: 165,
            currencyCode: "EUR",
            workshopName: "Autocenter East",
            notes: "Oil and filter only."
        )
        let skodaBrakes = ServiceEntry(
            vehicle: skoda,
            date: date(monthsAgo: 1),
            mileage: 86_300,
            serviceType: .brakes,
            category: .repair,
            price: 420,
            currencyCode: "EUR",
            workshopName: "Brake Lab",
            notes: "Front pads replaced.",
            isImportant: true
        )
        let fiatRepair = ServiceEntry(
            vehicle: fiat,
            date: date(monthsAgo: 6),
            mileage: 107_800,
            serviceType: .repair,
            category: .repair,
            price: 120,
            currencyCode: "EUR",
            workshopName: "City Garage",
            notes: "Bulb and clip repair."
        )
        [skodaInspection, skodaOil, skodaBrakes, fiatRepair].forEach(context.insert)

        createFuelEntries(for: skoda, in: context, entries: [
            (.initialTank, 70, 71_800, 0, 0, "Diesel", "OMV", ""),
            (.fullFillUp, 56, 72_420, 37.2, 64.80, "Diesel", "Shell", ""),
            (.partialFillUp, 41, 73_010, 18.5, 33.40, "Diesel", "OMV", "Short top-up."),
            (.missedFillUp, 29, 73_580, 0, 0, "Diesel", "", "One fill-up is intentionally missing."),
            (.fullFillUp, 12, 74_260, 41.7, 73.10, "Diesel", "MOL", "")
        ])

        let skodaReminder = ReminderItem(
            vehicle: skoda,
            serviceEntry: skodaInspection,
            type: .inspection,
            title: "Skoda inspection",
            notes: "Upcoming reminder for a mostly complete vehicle.",
            dateDue: date(monthsAhead: 2),
            mileageDue: 92_000,
            notificationTiming: .thirtyDaysBefore,
            isEnabled: true
        )
        let fiatReminder = ReminderItem(
            vehicle: fiat,
            type: .insurance,
            title: "Fiat insurance",
            notes: "Disabled on purpose for an incomplete setup.",
            notificationTiming: .sevenDaysBefore,
            isEnabled: false
        )
        [skodaReminder, fiatReminder].forEach(context.insert)

        let skodaReceipt = AttachmentRecord(
            vehicle: skoda,
            serviceEntry: skodaOil,
            type: .pdf,
            filename: "Skoda Oil Invoice.pdf",
            storageReference: "demo-partial-skoda-oil-pdf"
        )
        context.insert(skodaReceipt)

        createDocument(
            in: context,
            for: skoda,
            serviceEntry: skodaInspection,
            title: "Skoda Inspection Report",
            category: .inspection,
            documentDate: date(monthsAgo: 1),
            notes: "Single document to keep the vault partial.",
            pages: [
                (orderIndex: 0, type: .pdf, filename: "Skoda Inspection Report.pdf", storageReference: "demo-partial-skoda-inspection-pdf", thumbnailReference: nil),
                (orderIndex: 1, type: .image, filename: "Skoda Inspection Photo.jpg", storageReference: "demo-partial-skoda-inspection-photo", thumbnailReference: "demo-partial-skoda-inspection-photo-thumb")
            ]
        )

        try? context.save()
    }

    private static func createEntries(
        for vehicle: Vehicle,
        in context: ModelContext,
        entries: [(type: ServiceType, monthsAgo: Int, mileage: Int, price: Double, workshop: String, notes: String, important: Bool, category: EntryCategory?, customTitle: String?)]
    ) {
        for entry in entries {
            let item = ServiceEntry(
                vehicle: vehicle,
                date: date(monthsAgo: entry.monthsAgo),
                mileage: entry.mileage,
                serviceType: entry.type,
                customServiceTypeName: entry.customTitle,
                category: entry.category,
                price: entry.price,
                currencyCode: vehicle.currencyCode,
                workshopName: entry.workshop,
                notes: entry.notes,
                isImportant: entry.important
            )
            context.insert(item)
        }
    }

    private static func createReminder(
        for vehicle: Vehicle,
        in context: ModelContext,
        type: ReminderType,
        title: String,
        notes: String,
        monthsAhead: Int,
        mileageDue: Int?,
        timing: NotificationTiming
    ) {
        let reminder = ReminderItem(
            vehicle: vehicle,
            type: type,
            title: title,
            notes: notes,
            dateDue: date(monthsAhead: monthsAhead),
            mileageDue: mileageDue,
            notificationTiming: timing,
            isEnabled: true
        )
        context.insert(reminder)
    }

    private static func createFuelEntries(
        for vehicle: Vehicle,
        in context: ModelContext,
        entries: [(type: FuelEntryType, daysAgo: Int, mileage: Int, liters: Double, totalCost: Double, fuelType: String, station: String, notes: String)]
    ) {
        for entry in entries {
            let liters = entry.type.requiresFuelAmounts ? entry.liters : 0
            let totalCost = entry.type.requiresFuelAmounts ? entry.totalCost : 0
            let pricePerLiter = liters > 0 ? totalCost / liters : 0

            let item = FuelEntry(
                vehicle: vehicle,
                date: Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: .now) ?? .now,
                mileage: entry.mileage,
                liters: liters,
                pricePerLiter: pricePerLiter,
                totalCost: totalCost,
                currencyCode: vehicle.currencyCode,
                entryType: entry.type,
                fuelTypeName: entry.fuelType,
                station: entry.station,
                notes: entry.notes
            )
            context.insert(item)
        }
    }

    private static func createDocument(
        in context: ModelContext,
        for vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        title: String,
        category: DocumentVaultCategory = .general,
        documentDate: Date = .now,
        notes: String = "",
        pages: [(orderIndex: Int, type: AttachmentType, filename: String, storageReference: String, thumbnailReference: String?)]
    ) {
        let document = DocumentRecord(
            vehicle: vehicle,
            serviceEntry: serviceEntry,
            title: title,
            category: category,
            documentDate: documentDate,
            notes: notes
        )
        context.insert(document)

        for page in pages {
            let pageRecord = DocumentPageRecord(
                document: document,
                orderIndex: page.orderIndex,
                type: page.type,
                filename: page.filename,
                storageReference: page.storageReference,
                thumbnailReference: page.thumbnailReference
            )
            context.insert(pageRecord)
        }
    }

    private static func clearAllData(in context: ModelContext) {
        (try? context.fetch(FetchDescriptor<DocumentPageRecord>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<DocumentRecord>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<AttachmentRecord>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<ReminderItem>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<FuelEntry>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<ServiceEntry>()))?.forEach(context.delete)
        (try? context.fetch(FetchDescriptor<Vehicle>()))?.forEach(context.delete)
        try? context.save()
    }

    private static func date(monthsAgo: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -monthsAgo, to: .now) ?? .now
    }

    private static func date(monthsAhead: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: monthsAhead, to: .now) ?? .now
    }

    private static func date(yearsAgo: Int, monthsAgo: Int = 0) -> Date {
        let totalMonths = (yearsAgo * 12) + monthsAgo
        return Calendar.current.date(byAdding: .month, value: -totalMonths, to: .now) ?? .now
    }
}
