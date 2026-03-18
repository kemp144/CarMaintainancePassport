import Foundation
import SwiftData

@Model
final class AttachmentRecord {
    @Attribute(.unique) var id: UUID

    var vehicle: Vehicle?

    var serviceEntry: ServiceEntry?

    var typeRaw: String
    var vaultCategoryRaw: String?
    var filename: String
    var storageReference: String
    var thumbnailReference: String?
    var metadata: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        type: AttachmentType,
        vaultCategory: DocumentVaultCategory? = nil,
        filename: String,
        storageReference: String,
        thumbnailReference: String? = nil,
        metadata: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.serviceEntry = serviceEntry
        self.typeRaw = type.rawValue
        self.vaultCategoryRaw = vaultCategory?.rawValue
        self.filename = filename
        self.storageReference = storageReference
        self.thumbnailReference = thumbnailReference
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

extension AttachmentRecord {
    var type: AttachmentType {
        get { AttachmentType(rawValue: typeRaw) ?? .pdf }
        set { typeRaw = newValue.rawValue }
    }
    
    var vaultCategory: DocumentVaultCategory? {
        get { vaultCategoryRaw.flatMap { DocumentVaultCategory(rawValue: $0) } }
        set { vaultCategoryRaw = newValue?.rawValue }
    }
}