import Foundation
import SwiftData

struct BackupExportService {
    static let shared = BackupExportService()

    enum BackupError: LocalizedError {
        case noDataToBackup

        var errorDescription: String? {
            switch self {
            case .noDataToBackup:
                return "There’s nothing to back up yet."
            }
        }
    }

    // MARK: - Storage locations

    /// iCloud Drive folder for backups — survives app deletion.
    /// Requires the iCloud Documents capability to be enabled in the Xcode project
    /// (Signing & Capabilities → iCloud → CloudKit or iCloud Documents).
    /// Returns nil when iCloud is unavailable or the entitlement is not configured.
    var iCloudBackupFolder: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let folder = container.appendingPathComponent("Documents/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// On-device Documents folder — accessible via Files app, but deleted with the app.
    var localBackupFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        let folder = docs.appendingPathComponent("CarServicePassport/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Whether the current backup target is iCloud Drive (true) or on-device only (false).
    var isUsingICloud: Bool {
        iCloudBackupFolder != nil
    }

    // MARK: - Auto backup

    /// Saves a timestamped backup to iCloud Drive if available, otherwise to the local Documents folder.
    /// Retains the 10 most recent backups and prunes older ones.
    func saveBackup(
        vehicles: [Vehicle],
        services: [ServiceEntry],
        reminders: [ReminderItem],
        attachments: [AttachmentRecord],
        documents: [DocumentRecord],
        fuelEntries: [FuelEntry]
    ) throws {
        let snapshot = BackupSnapshot(
            exportedAt: .now,
            vehicles:    vehicles.map(BackupVehicle.init),
            services:    services.map(BackupService.init),
            reminders:   reminders.map(BackupReminder.init),
            attachments: attachments.map(BackupAttachment.init),
            documents:   documents.map(BackupDocument.init),
            fuelEntries: fuelEntries.map(BackupFuelEntry.init),
            storedAssets: storedAssets(
                vehicles: vehicles,
                attachments: attachments,
                documents: documents,
                fuelEntries: fuelEntries
            )
        )

        guard snapshot.hasContent else {
            throw BackupError.noDataToBackup
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let folder = iCloudBackupFolder ?? localBackupFolder
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let file = folder.appendingPathComponent("backup_\(formatter.string(from: .now)).json")
        try encoder.encode(snapshot).write(to: file)

        pruneBackups(in: folder)
    }

    /// Keeps the 10 most recent backup files in the given folder.
    private func pruneBackups(in folder: URL) {
        let all = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        let sorted = all.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return aDate > bDate
        }
        for old in sorted.dropFirst(10) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    // MARK: - Restore detection

    /// Returns the URL of the most recent backup file across iCloud and local storage.
    func findLatestBackup() -> URL? {
        backupCandidates().first(where: isRestorableBackup(at:))
    }

    /// Returns the creation date of the most recent backup, if any.
    func lastBackupDate() -> Date? {
        guard let url = findLatestBackup() else { return nil }
        return (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
    }

    // MARK: - Import

    enum ImportError: LocalizedError {
        case invalidFile
        case decodeError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFile:         return "The selected file is not a valid Car Maintenance Passport backup."
            case .decodeError(let m):  return "Import failed: \(m)"
            }
        }
    }

    private func backupCandidates() -> [URL] {
        let folders: [URL] = [iCloudBackupFolder, localBackupFolder].compactMap { $0 }
        return folders
            .flatMap { folder in
                (try? FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )) ?? []
            }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return aDate > bDate
            }
    }

    private func isRestorableBackup(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(BackupSnapshot.self, from: data) else { return false }
        return snapshot.hasContent
    }

    struct ImportResult {
        let vehiclesImported:  Int
        let servicesImported:  Int
        let remindersImported: Int
        let attachmentsImported: Int
        let documentsImported: Int
        let fuelEntriesImported: Int
        let assetsRestored: Int
    }

    /// Imports the latest available backup into the model context.
    @MainActor
    func importLatestBackup(into context: ModelContext) throws -> ImportResult {
        guard let url = findLatestBackup() else { throw ImportError.invalidFile }
        return try importJSON(from: url, into: context)
    }

    /// Imports a backup JSON file into the provided model context. Skips records with duplicate IDs.
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

        let restoredAssets = restoreAssets(snapshot.storedAssets ?? [])

        // Collect existing IDs to skip duplicates
        let existingVehicleIDs     = Set((try? context.fetch(FetchDescriptor<Vehicle>()))?.map(\.id) ?? [])
        let existingServiceIDs     = Set((try? context.fetch(FetchDescriptor<ServiceEntry>()))?.map(\.id) ?? [])
        let existingReminderIDs    = Set((try? context.fetch(FetchDescriptor<ReminderItem>()))?.map(\.id) ?? [])
        let existingAttachmentIDs  = Set((try? context.fetch(FetchDescriptor<AttachmentRecord>()))?.map(\.id) ?? [])
        let existingDocumentIDs    = Set((try? context.fetch(FetchDescriptor<DocumentRecord>()))?.map(\.id) ?? [])
        let existingDocPageIDs     = Set((try? context.fetch(FetchDescriptor<DocumentPageRecord>()))?.map(\.id) ?? [])
        let existingFuelIDs        = Set((try? context.fetch(FetchDescriptor<FuelEntry>()))?.map(\.id) ?? [])

        // --- Vehicles ---
        var vehicleMap: [UUID: Vehicle] = [:]
        var vehiclesImported = 0

        for bv in snapshot.vehicles where !existingVehicleIDs.contains(bv.id) {
            let v = Vehicle(
                id: bv.id, make: bv.make, model: bv.model, year: bv.year,
                licensePlate: bv.licensePlate, currentMileage: bv.currentMileage,
                purchaseDate: bv.purchaseDate, purchasePrice: bv.purchasePrice,
                currencyCode: bv.currencyCode, vin: bv.vin, notes: bv.notes,
                coverImageReference: bv.coverImageReference,
                createdAt: bv.createdAt, updatedAt: bv.updatedAt
            )
            context.insert(v)
            vehicleMap[bv.id] = v
            vehiclesImported += 1
        }
        if let existing = try? context.fetch(FetchDescriptor<Vehicle>()) {
            for v in existing { vehicleMap[v.id] = v }
        }

        // --- Services ---
        var serviceMap: [UUID: ServiceEntry] = [:]
        var servicesImported = 0

        for bs in snapshot.services where !existingServiceIDs.contains(bs.id) {
            guard let vehicle = bs.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let entry = ServiceEntry(
                id: bs.id, vehicle: vehicle, date: bs.date, mileage: bs.mileage,
                serviceType: ServiceType(rawValue: bs.serviceType) ?? .custom,
                customServiceTypeName: bs.customServiceTypeName,
                category: EntryCategory(rawValue: bs.category) ?? .maintenance,
                price: bs.price, currencyCode: bs.currencyCode,
                workshopName: bs.workshopName, notes: bs.notes,
                isImportant: bs.isImportant,
                createdAt: bs.createdAt, updatedAt: bs.updatedAt
            )
            context.insert(entry)
            serviceMap[bs.id] = entry
            servicesImported += 1
        }
        if let existing = try? context.fetch(FetchDescriptor<ServiceEntry>()) {
            for s in existing { serviceMap[s.id] = s }
        }

        // --- Reminders ---
        var remindersImported = 0

        for br in snapshot.reminders where !existingReminderIDs.contains(br.id) {
            guard let vehicle = br.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let reminder = ReminderItem(
                id: br.id, vehicle: vehicle,
                serviceEntry: br.serviceEntryID.flatMap { serviceMap[$0] },
                linkedServiceEntryID: br.linkedServiceEntryID ?? br.serviceEntryID,
                linkedServiceDate: br.linkedServiceDate,
                linkedServiceMileage: br.linkedServiceMileage,
                type: ReminderType(rawValue: br.type) ?? .custom,
                title: br.title, notes: br.notes,
                dateDue: br.dateDue, mileageDue: br.mileageDue,
                notificationTiming: NotificationTiming(rawValue: br.notificationTiming) ?? .sevenDaysBefore,
                isEnabled: br.isEnabled,
                createdAt: br.createdAt, updatedAt: br.updatedAt
            )
            context.insert(reminder)
            remindersImported += 1
        }

        // --- Legacy attachments ---
        var attachmentsImported = 0

        for ba in snapshot.attachments where !existingAttachmentIDs.contains(ba.id) {
            guard let vehicle = ba.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let attachment = AttachmentRecord(
                id: ba.id,
                vehicle: vehicle,
                serviceEntry: ba.serviceEntryID.flatMap { serviceMap[$0] },
                type: AttachmentType(rawValue: ba.type) ?? .pdf,
                vaultCategory: ba.vaultCategory.flatMap { DocumentVaultCategory(rawValue: $0) },
                filename: ba.filename,
                storageReference: ba.storageReference,
                thumbnailReference: ba.thumbnailReference,
                metadata: ba.metadata,
                createdAt: ba.createdAt
            )
            context.insert(attachment)
            attachmentsImported += 1
        }

        // --- Documents ---
        var documentsImported = 0

        for bd in snapshot.documents ?? [] where !existingDocumentIDs.contains(bd.id) {
            guard let vehicle = bd.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let doc = DocumentRecord(
                id: bd.id, vehicle: vehicle,
                serviceEntry: bd.serviceEntryID.flatMap { serviceMap[$0] },
                title: bd.title,
                category: DocumentVaultCategory(rawValue: bd.category) ?? .general,
                documentDate: bd.documentDate, notes: bd.notes,
                createdAt: bd.createdAt, updatedAt: bd.updatedAt
            )
            context.insert(doc)
            for ps in bd.pages.sorted(by: { $0.orderIndex < $1.orderIndex })
            where !existingDocPageIDs.contains(ps.id) {
                let page = DocumentPageRecord(
                    id: ps.id, document: doc, orderIndex: ps.orderIndex,
                    type: AttachmentType(rawValue: ps.type) ?? .image,
                    filename: ps.filename, storageReference: ps.storageReference,
                    thumbnailReference: ps.thumbnailReference, createdAt: ps.createdAt
                )
                context.insert(page)
                doc.pages.append(page)
            }
            documentsImported += 1
        }

        // --- Fuel entries ---
        var fuelEntriesImported = 0

        for bf in snapshot.fuelEntries ?? [] where !existingFuelIDs.contains(bf.id) {
            guard let vehicle = bf.vehicleID.flatMap({ vehicleMap[$0] }) else { continue }
            let entry = FuelEntry(
                id: bf.id, vehicle: vehicle, date: bf.date, mileage: bf.mileage,
                liters: bf.liters, pricePerLiter: bf.pricePerLiter,
                totalCost: bf.totalCost, currencyCode: bf.currencyCode,
                entryType: FuelEntryType(rawValue: bf.entryType) ?? .fullFillUp,
                fuelTypeName: bf.fuelTypeName, station: bf.station, notes: bf.notes,
                isFullTank: bf.isFullTank,
                receiptStorageReference: bf.receiptStorageReference,
                receiptThumbnailReference: bf.receiptThumbnailReference,
                createdAt: bf.createdAt, updatedAt: bf.updatedAt
            )
            context.insert(entry)
            fuelEntriesImported += 1
        }

        try context.save()
        return ImportResult(
            vehiclesImported:    vehiclesImported,
            servicesImported:    servicesImported,
            remindersImported:   remindersImported,
            attachmentsImported: attachmentsImported,
            documentsImported:   documentsImported,
            fuelEntriesImported: fuelEntriesImported,
            assetsRestored:      restoredAssets
        )
    }

    private func storedAssets(
        vehicles: [Vehicle],
        attachments: [AttachmentRecord],
        documents: [DocumentRecord],
        fuelEntries: [FuelEntry]
    ) -> [BackupStoredAsset] {
        // Backups must be self-contained, otherwise reinstall/restore would recreate
        // records that point to files that no longer exist in Application Support.
        var seenReferences = Set<String>()
        var assets: [BackupStoredAsset] = []

        let references = vehicles.compactMap(\.coverImageReference)
            + attachments.flatMap { [$0.storageReference, $0.thumbnailReference].compactMap { $0 } }
            + documents.flatMap { document in
                document.sortedPages.flatMap { [$0.storageReference, $0.thumbnailReference].compactMap { $0 } }
            }
            + fuelEntries.flatMap { [$0.receiptStorageReference, $0.receiptThumbnailReference].compactMap { $0 } }

        for reference in references where seenReferences.insert(reference).inserted {
            guard let data = AttachmentStorageService.data(for: reference) else { continue }
            assets.append(BackupStoredAsset(reference: reference, data: data))
        }

        return assets
    }

    private func restoreAssets(_ assets: [BackupStoredAsset]) -> Int {
        var restored = 0

        for asset in assets {
            do {
                try AttachmentStorageService.restoreFileData(asset.data, reference: asset.reference)
                restored += 1
            } catch {
                continue
            }
        }

        return restored
    }
}

// MARK: - Backup snapshot models

struct BackupSnapshot: Codable {
    let exportedAt:  Date
    let vehicles:    [BackupVehicle]
    let services:    [BackupService]
    let reminders:   [BackupReminder]
    let attachments: [BackupAttachment]
    let documents:   [BackupDocument]?
    let fuelEntries: [BackupFuelEntry]?
    let storedAssets: [BackupStoredAsset]?
}

private extension BackupSnapshot {
    var hasContent: Bool {
        !vehicles.isEmpty
            || !services.isEmpty
            || !reminders.isEmpty
            || !attachments.isEmpty
            || !(documents?.isEmpty ?? true)
            || !(fuelEntries?.isEmpty ?? true)
            || !(storedAssets?.isEmpty ?? true)
    }
}

struct BackupVehicle: Codable {
    let id: UUID; let make: String; let model: String; let year: Int
    let licensePlate: String; let currentMileage: Int
    let purchaseDate: Date?; let purchasePrice: Double?
    let currencyCode: String; let vin: String; let notes: String
    let coverImageReference: String?
    let createdAt: Date; let updatedAt: Date

    init(vehicle: Vehicle) {
        id = vehicle.id; make = vehicle.make; model = vehicle.model; year = vehicle.year
        licensePlate = vehicle.licensePlate; currentMileage = vehicle.currentMileage
        purchaseDate = vehicle.purchaseDate; purchasePrice = vehicle.purchasePrice
        currencyCode = vehicle.currencyCode; vin = vehicle.vin; notes = vehicle.notes
        coverImageReference = vehicle.coverImageReference
        createdAt = vehicle.createdAt; updatedAt = vehicle.updatedAt
    }
}

struct BackupService: Codable {
    let id: UUID; let vehicleID: UUID?; let date: Date; let mileage: Int
    let serviceType: String; let customServiceTypeName: String?
    let category: String; let price: Double; let currencyCode: String
    let workshopName: String; let notes: String; let isImportant: Bool
    let createdAt: Date; let updatedAt: Date

    init(service: ServiceEntry) {
        id = service.id; vehicleID = service.vehicle?.id; date = service.date; mileage = service.mileage
        serviceType = service.serviceTypeRaw; customServiceTypeName = service.customServiceTypeName
        category = service.categoryRaw; price = service.price; currencyCode = service.currencyCode
        workshopName = service.workshopName; notes = service.notes; isImportant = service.isImportant
        createdAt = service.createdAt; updatedAt = service.updatedAt
    }
}

struct BackupReminder: Codable {
    let id: UUID; let vehicleID: UUID?; let serviceEntryID: UUID?
    let linkedServiceEntryID: UUID?; let linkedServiceDate: Date?; let linkedServiceMileage: Int?
    let type: String; let title: String; let notes: String
    let dateDue: Date?; let mileageDue: Int?
    let notificationTiming: String; let isEnabled: Bool
    let createdAt: Date; let updatedAt: Date

    init(reminder: ReminderItem) {
        id = reminder.id; vehicleID = reminder.vehicle?.id
        serviceEntryID = reminder.serviceEntry?.id
        linkedServiceEntryID = reminder.linkedServiceEntryID
        linkedServiceDate = reminder.linkedServiceDate
        linkedServiceMileage = reminder.linkedServiceMileage
        type = reminder.typeRaw; title = reminder.title; notes = reminder.notes
        dateDue = reminder.dateDue; mileageDue = reminder.mileageDue
        notificationTiming = reminder.notificationTimingRaw; isEnabled = reminder.isEnabled
        createdAt = reminder.createdAt; updatedAt = reminder.updatedAt
    }
}

struct BackupAttachment: Codable {
    let id: UUID; let vehicleID: UUID?; let serviceEntryID: UUID?
    let type: String; let filename: String
    let storageReference: String; let thumbnailReference: String?
    let vaultCategory: String?
    let metadata: String?; let createdAt: Date

    init(attachment: AttachmentRecord) {
        id = attachment.id; vehicleID = attachment.vehicle?.id
        serviceEntryID = attachment.serviceEntry?.id
        type = attachment.typeRaw; filename = attachment.filename
        storageReference = attachment.storageReference
        thumbnailReference = attachment.thumbnailReference
        vaultCategory = attachment.vaultCategoryRaw
        metadata = attachment.metadata; createdAt = attachment.createdAt
    }
}

struct BackupStoredAsset: Codable {
    let reference: String
    let data: Data
}

struct BackupDocument: Codable {
    let id: UUID; let vehicleID: UUID?; let serviceEntryID: UUID?
    let title: String; let category: String
    let documentDate: Date; let notes: String
    let createdAt: Date; let updatedAt: Date
    let pages: [BackupDocumentPage]

    init(document: DocumentRecord) {
        id = document.id; vehicleID = document.vehicle?.id
        serviceEntryID = document.serviceEntry?.id
        title = document.title; category = document.categoryRaw
        documentDate = document.documentDate; notes = document.notes
        createdAt = document.createdAt; updatedAt = document.updatedAt
        pages = document.sortedPages.map(BackupDocumentPage.init)
    }
}

struct BackupDocumentPage: Codable {
    let id: UUID; let documentID: UUID?; let orderIndex: Int
    let type: String; let filename: String
    let storageReference: String; let thumbnailReference: String?
    let createdAt: Date

    init(page: DocumentPageRecord) {
        id = page.id; documentID = page.document?.id; orderIndex = page.orderIndex
        type = page.typeRaw; filename = page.filename
        storageReference = page.storageReference
        thumbnailReference = page.thumbnailReference; createdAt = page.createdAt
    }
}

struct BackupFuelEntry: Codable {
    let id: UUID; let vehicleID: UUID?; let date: Date; let mileage: Int
    let liters: Double; let pricePerLiter: Double; let totalCost: Double
    let currencyCode: String; let entryType: String
    let fuelTypeName: String; let station: String; let notes: String
    let isFullTank: Bool
    let receiptStorageReference: String?; let receiptThumbnailReference: String?
    let createdAt: Date; let updatedAt: Date

    init(entry: FuelEntry) {
        id = entry.id; vehicleID = entry.vehicle?.id; date = entry.date; mileage = entry.mileage
        liters = entry.liters; pricePerLiter = entry.pricePerLiter; totalCost = entry.totalCost
        currencyCode = entry.currencyCode; entryType = entry.entryTypeRaw
        fuelTypeName = entry.fuelTypeName; station = entry.station; notes = entry.notes
        isFullTank = entry.isFullTank
        receiptStorageReference = entry.receiptStorageReference
        receiptThumbnailReference = entry.receiptThumbnailReference
        createdAt = entry.createdAt; updatedAt = entry.updatedAt
    }
}
