import Foundation
import SwiftData

@Model
final class ServiceEntry {
    @Attribute(.unique) var id: UUID

    var vehicle: Vehicle?

    var date: Date
    var mileage: Int
    var serviceTypeRaw: String
    var customServiceTypeName: String?
    var categoryRaw: String
    var price: Double
    var currencyCode: String
    var workshopName: String
    var notes: String
    var isImportant: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AttachmentRecord.serviceEntry)
    var attachments: [AttachmentRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \DocumentRecord.serviceEntry)
    var linkedDocuments: [DocumentRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \ReminderItem.serviceEntry)
    var reminders: [ReminderItem] = []

    init(
        id: UUID = UUID(),
        vehicle: Vehicle,
        date: Date = .now,
        mileage: Int,
        serviceType: ServiceType,
        customServiceTypeName: String? = nil,
        category: EntryCategory? = nil,
        price: Double = 0,
        currencyCode: String = CurrencyPreset.suggested().rawValue,
        workshopName: String = "",
        notes: String = "",
        isImportant: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.date = date
        self.mileage = mileage
        self.serviceTypeRaw = serviceType.rawValue
        self.customServiceTypeName = customServiceTypeName
        self.categoryRaw = (category ?? serviceType.defaultCategory).rawValue
        self.price = price
        self.currencyCode = currencyCode
        self.workshopName = workshopName
        self.notes = notes
        self.isImportant = isImportant
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ServiceEntry {
    var serviceType: ServiceType {
        get { ServiceType(rawValue: serviceTypeRaw) ?? .custom }
        set { serviceTypeRaw = newValue.rawValue }
    }

    var category: EntryCategory {
        get { EntryCategory(rawValue: categoryRaw) ?? serviceType.defaultCategory }
        set { categoryRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if serviceType == .custom, let customServiceTypeName, !customServiceTypeName.isEmpty {
            return customServiceTypeName
        }
        return serviceType.title
    }
}
