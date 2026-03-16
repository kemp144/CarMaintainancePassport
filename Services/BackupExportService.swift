import Foundation

struct BackupExportService {
    static let shared = BackupExportService()

    func exportJSON(vehicles: [Vehicle], services: [ServiceEntry], reminders: [ReminderItem], attachments: [AttachmentRecord]) throws -> URL {
        let snapshot = BackupSnapshot(
            exportedAt: .now,
            vehicles: vehicles.map(BackupVehicle.init),
            services: services.map(BackupService.init),
            reminders: reminders.map(BackupReminder.init),
            attachments: attachments.map(BackupAttachment.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("car-service-passport-backup.json")
        try encoder.encode(snapshot).write(to: url)
        return url
    }
}

private struct BackupSnapshot: Codable {
    let exportedAt: Date
    let vehicles: [BackupVehicle]
    let services: [BackupService]
    let reminders: [BackupReminder]
    let attachments: [BackupAttachment]
}

private struct BackupVehicle: Codable {
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

private struct BackupService: Codable {
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

private struct BackupReminder: Codable {
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

private struct BackupAttachment: Codable {
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