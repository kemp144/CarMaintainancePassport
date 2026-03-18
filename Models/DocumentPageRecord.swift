import Foundation
import SwiftData

@Model
final class DocumentPageRecord {
    @Attribute(.unique) var id: UUID

    var document: DocumentRecord?
    var orderIndex: Int

    var typeRaw: String
    var filename: String
    var storageReference: String
    var thumbnailReference: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        document: DocumentRecord? = nil,
        orderIndex: Int,
        type: AttachmentType,
        filename: String,
        storageReference: String,
        thumbnailReference: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.document = document
        self.orderIndex = orderIndex
        self.typeRaw = type.rawValue
        self.filename = filename
        self.storageReference = storageReference
        self.thumbnailReference = thumbnailReference
        self.createdAt = createdAt
    }
}

extension DocumentPageRecord {
    var type: AttachmentType {
        get { AttachmentType(rawValue: typeRaw) ?? .image }
        set { typeRaw = newValue.rawValue }
    }
}
