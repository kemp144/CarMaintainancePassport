import SwiftData
import Foundation

enum PreviewData {
    private static let demoVehicleVINs = [
        "WAUZZZF48KA123456",
        "WVWZZZCDZMW133742",
        "VF3MCYHZRKS998877",
        "SALWA2AK9LA765432"
    ]

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
    static func generateDemoGarage(in context: ModelContext) {
        let existingVehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        guard !existingVehicles.contains(where: { demoVehicleVINs.contains($0.vin) }) else { return }

        let audi = Vehicle(
            make: "Audi",
            model: "A4 Avant 40 TDI",
            year: 2019,
            licensePlate: "BG-419-CP",
            currentMileage: 126_420,
            purchaseDate: date(yearsAgo: 4, monthsAgo: 2),
            purchasePrice: 25_900,
            currencyCode: "EUR",
            vin: "WAUZZZF48KA123456",
            notes: "Porodični auto za duža putovanja. Redovno servisiran i sa kompletnom istorijom održavanja."
        )

        let golf = Vehicle(
            make: "Volkswagen",
            model: "Golf 8 1.5 eTSI",
            year: 2021,
            licensePlate: "NS-128-GF",
            currentMileage: 68_500,
            purchaseDate: date(yearsAgo: 3, monthsAgo: 7),
            purchasePrice: 22_000,
            currencyCode: "EUR",
            vin: "WVWZZZCDZMW133742",
            notes: "Gradski auto sa urednom servisnom knjižicom, nekoliko sezonskih ulaganja i detaljnom evidencijom troškova."
        )

        let peugeot = Vehicle(
            make: "Peugeot",
            model: "3008 1.6 BlueHDi",
            year: 2018,
            licensePlate: "KG-3008-PG",
            currentMileage: 154_300,
            purchaseDate: date(yearsAgo: 5, monthsAgo: 5),
            purchasePrice: 18_400,
            currencyCode: "EUR",
            vin: "VF3MCYHZRKS998877",
            notes: "Auto za svakodnevnu vožnju i porodicu. Ima više administrativnih i mehaničkih unosa da lepo popuni timeline."
        )

        let rangeRover = Vehicle(
            make: "Land Rover",
            model: "Range Rover Evoque",
            year: 2020,
            licensePlate: "BG-EVO-777",
            currentMileage: 92_800,
            purchaseDate: date(yearsAgo: 2, monthsAgo: 10),
            purchasePrice: 39_500,
            currencyCode: "EUR",
            vin: "SALWA2AK9LA765432",
            notes: "Premium demo vozilo sa skupljim servisima, keramikom, gumama i registracijom za test statistike."
        )

        [audi, golf, peugeot, rangeRover].forEach(context.insert)

        createEntries(for: audi, in: context, entries: [
            (.inspection, 34, 51_000, 280, "Porsche Inter Auto", "Veliki servis pregled pre kupovine.", false, nil, nil),
            (.oilChange, 30, 61_400, 175, "Porsche Inter Auto", "Ulje 5W-30, svi filteri.", false, nil, nil),
            (.brakes, 24, 75_600, 640, "Brake Service Center", "Prednje pločice i diskovi.", true, .repair, nil),
            (.tires, 19, 83_000, 780, "Vulkanizer Premium", "Novi letnji set Michelin Pilot Sport.", false, nil, nil),
            (.airConditioning, 15, 91_200, 135, "Auto Klima 021", "Dopuna freona i dezinfekcija.", false, nil, nil),
            (.oilChange, 10, 102_500, 189, "Porsche Inter Auto", "Redovan mali servis.", false, nil, nil),
            (.battery, 6, 113_900, 245, "Battery Shop", "Zamenjen akumulator pre zime.", false, .repair, nil),
            (.inspection, 2, 124_800, 320, "Porsche Inter Auto", "Godišnji pregled i dijagnostika.", true, nil, nil)
        ])

        createEntries(for: golf, in: context, entries: [
            (.inspection, 28, 12_000, 210, "VW Novi Sad", "Prva kontrola nakon kupovine.", false, nil, nil),
            (.oilChange, 24, 19_800, 155, "VW Novi Sad", "Ulje i filter kabine.", false, nil, nil),
            (.tires, 18, 29_200, 520, "Gumi Mix", "Zimske gume 205/55 R16.", false, nil, nil),
            (.filters, 14, 37_000, 96, "VW Novi Sad", "Filter vazduha i polena.", false, nil, nil),
            (.oilChange, 9, 48_100, 162, "VW Novi Sad", "Mali servis i reset servisnog intervala.", false, nil, nil),
            (.washDetailing, 5, 59_400, 85, "Gloss Studio", "Dubinsko pranje i zaštita enterijera.", false, .care, nil),
            (.insurance, 3, 64_000, 610, "DDOR", "Kasko obnova police.", false, .administration, nil),
            (.registration, 1, 67_900, 340, "Tehnički pregled Plus", "Registracija i tehnički.", false, .administration, nil)
        ])

        createEntries(for: peugeot, in: context, entries: [
            (.oilChange, 40, 88_000, 145, "French Auto Service", "Ulje i svi filteri.", false, nil, nil),
            (.repair, 33, 97_500, 420, "French Auto Service", "Zamena EGR ventila.", true, .repair, nil),
            (.tires, 27, 108_200, 460, "Stop & Go Tires", "Celogodišnje gume.", false, nil, nil),
            (.brakes, 20, 119_000, 390, "French Auto Service", "Zadnje pločice i obrada diskova.", false, .repair, nil),
            (.inspection, 15, 128_500, 260, "French Auto Service", "Servis pre dužeg puta.", false, nil, nil),
            (.oilChange, 9, 139_700, 168, "French Auto Service", "Mali servis uz AdBlue dopunu.", false, nil, nil),
            (.registration, 4, 149_900, 295, "AMSS", "Registracija vozila.", false, .administration, nil),
            (.custom, 2, 153_800, 110, "Glass Point", "Poliranje farova", false, .care, "Poliranje farova")
        ])

        createEntries(for: rangeRover, in: context, entries: [
            (.inspection, 22, 24_000, 340, "British Motors", "Redovan premium pregled.", false, nil, nil),
            (.oilChange, 18, 36_500, 240, "British Motors", "Ulje, filteri i dijagnostika.", false, nil, nil),
            (.washDetailing, 14, 48_200, 180, "Detailing Lab", "Keramička zaštita i spoljašnji detailing.", false, .care, nil),
            (.tires, 11, 59_400, 1_120, "Premium Tire House", "Pirelli Scorpion set.", true, nil, nil),
            (.airConditioning, 8, 67_000, 190, "British Motors", "Klima servis i čišćenje ventilacije.", false, nil, nil),
            (.insurance, 5, 78_500, 1_480, "Generali", "Kasko i obavezno osiguranje.", false, .administration, nil),
            (.registration, 3, 84_900, 410, "AMSS Premium", "Registracija i tehnički pregled.", false, .administration, nil),
            (.battery, 1, 91_600, 310, "Battery Shop", "Nova AGM baterija.", false, .repair, nil)
        ])

        createReminder(for: audi, in: context, type: .oilChange, title: "Audi mali servis", notes: "Planiraj zamenu ulja pre letnjeg puta.", monthsAhead: 4, mileageDue: 132_000, timing: .thirtyDaysBefore)
        createReminder(for: golf, in: context, type: .registration, title: "Golf registracija", notes: "Pripremi polisu i tehnički.", monthsAhead: 11, mileageDue: nil, timing: .thirtyDaysBefore)
        createReminder(for: peugeot, in: context, type: .inspection, title: "Peugeot kontrola ogibljenja", notes: "Proveriti trap i balans posle zime.", monthsAhead: 2, mileageDue: 158_000, timing: .sevenDaysBefore)
        createReminder(for: rangeRover, in: context, type: .insurance, title: "Evoque obnova kaska", notes: "Uporediti ponude osiguranja.", monthsAhead: 5, mileageDue: nil, timing: .thirtyDaysBefore)

        try? context.save()
    }

    @MainActor
    static func generateMockVehicle(in context: ModelContext) {
        generateDemoGarage(in: context)
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