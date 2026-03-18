import Foundation
import SwiftData

struct BackupExportService {
    static let shared = BackupExportService()

    // MARK: - Export

    func exportJSON(vehicles: [Vehicle], services: [ServiceEntry], reminders: [ReminderItem], attachments: [AttachmentRecord], documents: [DocumentRecord]) throws -> URL {
        let snapshot = BackupSnapshot(
            exportedAt: .now,
            vehicles: vehicles.map(BackupVehicle.init),
            services: services.map(BackupService.init),
            reminders: reminders.map(BackupReminder.init),
            attachments: attachments.map(BackupAttachment.init),
            documents: documents.map(BackupDocument.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("car-service-passport-backup.json")
        try encoder.encode(snapshot).write(to: url)
        return url
    }

    /// Saves a timestamped backup to the app's Documents folder (accessible in Files app).
    func saveToDocuments(vehicles: [Vehicle], services: [ServiceEntry], reminders: [ReminderItem], attachments: [AttachmentRecord], documents: [DocumentRecord]) throws {
        let snapshot = BackupSnapshot(
            exportedAt: .now,
            vehicles: vehicles.map(BackupVehicle.init),
            services: services.map(BackupService.init),
            reminders: reminders.map(BackupReminder.init),
            attachments: attachments.map(BackupAttachment.init),
            documents: documents.map(BackupDocument.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("CarServicePassport/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: .now)
        let file = folder.appendingPathComponent("backup_\(timestamp).json")

        try encoder.encode(snapshot).write(to: file)

        // Keep only the latest 10 backups
        let existing = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)) ?? []
        let sorted = existing.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return aDate > bDate
        }
        for old in sorted.dropFirst(10) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    // MARK: - Import

    enum ImportError: LocalizedError {
        case invalidFile
        case decodeError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "The selected file is not a valid Car Service Passport backup."
            case .decodeError(let msg): return "Import failed: \(msg)"
            }
        }
    }

    struct ImportResult {
        let vehiclesImported: Int
        let servicesImported: Int
        let remindersImported: Int
        let documentsImported: Int
    }

    /// Imports a JSON backup into the provided modelContext. Skips records with duplicate IDs.
    @MainActor
    func importJSON(from url: URL, into context: ModelContext) throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.invalidFile }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot: BackupSnapshot
        do {
            snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw ImportError.decodeError(error.localizedDescription)
        }

        // Fetch existing IDs to avoid duplicates
        let existingVehicleIDs = Set((try? context.fetch(FetchDescriptor<Vehicle>()))?.map(\.id) ?? [])
        let existingServiceIDs = Set((try? context.fetch(FetchDescriptor<ServiceEntry>()))?.map(\.id) ?? [])
        let existingReminderIDs = Set((try? context.fetch(FetchDescriptor<ReminderItem>()))?.map(\.id) ?? [])
        let existingDocumentIDs = Set((try? context.fetch(FetchDescriptor<DocumentRecord>()))?.map(\.id) ?? [])
        let existingDocumentPageIDs = Set((try? context.fetch(FetchDescriptor<DocumentPageRecord>()))?.map(\.id) ?? [])

        var vehicleMap: [UUID: Vehicle] = [:]
        var vehiclesImported = 0

        for bv in snapshot.vehicles where !existingVehicleIDs.contains(bv.id) {
            let vehicle = Vehicle(
                id: bv.id,
                make: bv.make,
                model: bv.model,
                year: bv.year,
                licensePlate: bv.licensePlate,
                currentMileage: bv.currentMileage,
                purchaseDate: bv.purchaseDate,
                purchasePrice: bv.purchasePrice,
                currencyCode: bv.currencyCode,
                vin: bv.vin,
                notes: bv.notes,
                coverImageReference: bv.coverImageReference,
                createdAt: bv.createdAt,
                updatedAt: bv.updatedAt
            )
            context.insert(vehicle)
            vehicleMap[bv.id] = vehicle
            vehiclesImported += 1
        }

        // Also map existing vehicles so we can link imported services
        if let existing = try? context.fetch(FetchDescriptor<Vehicle>()) {
            for v in existing { vehicleMap[v.id] = v }
        }

        var serviceMap: [UUID: ServiceEntry] = [:]
        var servicesImported = 0

        for bs in snapshot.services where !existingServiceIDs.contains(bs.id) {
            guard let vehicle = bs.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let entry = ServiceEntry(
                id: bs.id,
                vehicle: vehicle,
                date: bs.date,
                mileage: bs.mileage,
                serviceType: ServiceType(rawValue: bs.serviceType) ?? .custom,
                customServiceTypeName: bs.customServiceTypeName,
                category: EntryCategory(rawValue: bs.category) ?? .maintenance,
                price: bs.price,
                currencyCode: bs.currencyCode,
                workshopName: bs.workshopName,
                notes: bs.notes,
                isImportant: bs.isImportant,
                createdAt: bs.createdAt,
                updatedAt: bs.updatedAt
            )
            context.insert(entry)
            serviceMap[bs.id] = entry
            servicesImported += 1
        }

        if let existing = try? context.fetch(FetchDescriptor<ServiceEntry>()) {
            for s in existing { serviceMap[s.id] = s }
        }

        var remindersImported = 0

        for br in snapshot.reminders where !existingReminderIDs.contains(br.id) {
            guard let vehicle = br.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let serviceEntry = br.serviceEntryID.flatMap { serviceMap[$0] }
            let reminder = ReminderItem(
                id: br.id,
                vehicle: vehicle,
                serviceEntry: serviceEntry,
                type: ReminderType(rawValue: br.type) ?? .custom,
                title: br.title,
                notes: br.notes,
                dateDue: br.dateDue,
                mileageDue: br.mileageDue,
                notificationTiming: NotificationTiming(rawValue: br.notificationTiming) ?? .sevenDaysBefore,
                isEnabled: br.isEnabled,
                createdAt: br.createdAt,
                updatedAt: br.updatedAt
            )
            context.insert(reminder)
            remindersImported += 1
        }

        var documentsImported = 0

        for bd in snapshot.documents ?? [] where !existingDocumentIDs.contains(bd.id) {
            guard let vehicle = bd.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let serviceEntry = bd.serviceEntryID.flatMap { serviceMap[$0] }
            let document = DocumentRecord(
                id: bd.id,
                vehicle: vehicle,
                serviceEntry: serviceEntry,
                title: bd.title,
                category: DocumentVaultCategory(rawValue: bd.category) ?? .general,
                documentDate: bd.documentDate,
                notes: bd.notes,
                createdAt: bd.createdAt,
                updatedAt: bd.updatedAt
            )
            context.insert(document)

            for pageSnapshot in bd.pages.sorted(by: { $0.orderIndex < $1.orderIndex }) where !existingDocumentPageIDs.contains(pageSnapshot.id) {
                let page = DocumentPageRecord(
                    id: pageSnapshot.id,
                    document: document,
                    orderIndex: pageSnapshot.orderIndex,
                    type: AttachmentType(rawValue: pageSnapshot.type) ?? .image,
                    filename: pageSnapshot.filename,
                    storageReference: pageSnapshot.storageReference,
                    thumbnailReference: pageSnapshot.thumbnailReference,
                    createdAt: pageSnapshot.createdAt
                )
                context.insert(page)
                document.pages.append(page)
            }

            documentsImported += 1
        }

        try context.save()
        return ImportResult(vehiclesImported: vehiclesImported, servicesImported: servicesImported, remindersImported: remindersImported, documentsImported: documentsImported)
    }
}

// MARK: - Backup Models (internal so ImportService can use them too)

struct BackupSnapshot: Codable {
    let exportedAt: Date
    let vehicles: [BackupVehicle]
    let services: [BackupService]
    let reminders: [BackupReminder]
    let attachments: [BackupAttachment]
    let documents: [BackupDocument]?
}

struct BackupVehicle: Codable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let licensePlate: String
    let currentMileage: Int
    let purchaseDate: Date?
    let purchasePrice: Double?
    let currencyCode: String
    let vin: String
    let notes: String
    let coverImageReference: String?
    let createdAt: Date
    let updatedAt: Date

    init(vehicle: Vehicle) {
        id = vehicle.id
        make = vehicle.make
        model = vehicle.model
        year = vehicle.year
        licensePlate = vehicle.licensePlate
        currentMileage = vehicle.currentMileage
        purchaseDate = vehicle.purchaseDate
        purchasePrice = vehicle.purchasePrice
        currencyCode = vehicle.currencyCode
        vin = vehicle.vin
        notes = vehicle.notes
        coverImageReference = vehicle.coverImageReference
        createdAt = vehicle.createdAt
        updatedAt = vehicle.updatedAt
    }
}

struct BackupService: Codable {
    let id: UUID
    let vehicleID: UUID?
    let date: Date
    let mileage: Int
    let serviceType: String
    let customServiceTypeName: String?
    let category: String
    let price: Double
    let currencyCode: String
    let workshopName: String
    let notes: String
    let isImportant: Bool
    let createdAt: Date
    let updatedAt: Date

    init(service: ServiceEntry) {
        id = service.id
        vehicleID = service.vehicle?.id
        date = service.date
        mileage = service.mileage
        serviceType = service.serviceTypeRaw
        customServiceTypeName = service.customServiceTypeName
        category = service.categoryRaw
        price = service.price
        currencyCode = service.currencyCode
        workshopName = service.workshopName
        notes = service.notes
        isImportant = service.isImportant
        createdAt = service.createdAt
        updatedAt = service.updatedAt
    }
}

struct BackupReminder: Codable {
    let id: UUID
    let vehicleID: UUID?
    let serviceEntryID: UUID?
    let type: String
    let title: String
    let notes: String
    let dateDue: Date?
    let mileageDue: Int?
    let notificationTiming: String
    let isEnabled: Bool
    let createdAt: Date
    let updatedAt: Date

    init(reminder: ReminderItem) {
        id = reminder.id
        vehicleID = reminder.vehicle?.id
        serviceEntryID = reminder.serviceEntry?.id
        type = reminder.typeRaw
        title = reminder.title
        notes = reminder.notes
        dateDue = reminder.dateDue
        mileageDue = reminder.mileageDue
        notificationTiming = reminder.notificationTimingRaw
        isEnabled = reminder.isEnabled
        createdAt = reminder.createdAt
        updatedAt = reminder.updatedAt
    }
}

struct BackupAttachment: Codable {
    let id: UUID
    let vehicleID: UUID?
    let serviceEntryID: UUID?
    let type: String
    let filename: String
    let storageReference: String
    let thumbnailReference: String?
    let metadata: String?
    let createdAt: Date

    init(attachment: AttachmentRecord) {
        id = attachment.id
        vehicleID = attachment.vehicle?.id
        serviceEntryID = attachment.serviceEntry?.id
        type = attachment.typeRaw
        filename = attachment.filename
        storageReference = attachment.storageReference
        thumbnailReference = attachment.thumbnailReference
        metadata = attachment.metadata
        createdAt = attachment.createdAt
    }
}

struct BackupDocument: Codable {
    let id: UUID
    let vehicleID: UUID?
    let serviceEntryID: UUID?
    let title: String
    let category: String
    let documentDate: Date
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let pages: [BackupDocumentPage]

    init(document: DocumentRecord) {
        id = document.id
        vehicleID = document.vehicle?.id
        serviceEntryID = document.serviceEntry?.id
        title = document.title
        category = document.categoryRaw
        documentDate = document.documentDate
        notes = document.notes
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        pages = document.sortedPages.map(BackupDocumentPage.init)
    }
}

struct BackupDocumentPage: Codable {
    let id: UUID
    let documentID: UUID?
    let orderIndex: Int
    let type: String
    let filename: String
    let storageReference: String
    let thumbnailReference: String?
    let createdAt: Date

    init(page: DocumentPageRecord) {
        id = page.id
        documentID = page.document?.id
        orderIndex = page.orderIndex
        type = page.typeRaw
        filename = page.filename
        storageReference = page.storageReference
        thumbnailReference = page.thumbnailReference
        createdAt = page.createdAt
    }
}
