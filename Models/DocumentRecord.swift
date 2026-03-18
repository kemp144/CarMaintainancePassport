import Foundation
import SwiftData

@Model
final class DocumentRecord {
    @Attribute(.unique) var id: UUID

    var vehicle: Vehicle?
    var serviceEntry: ServiceEntry?

    var title: String
    var categoryRaw: String
    var documentDate: Date
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DocumentPageRecord.document)
    var pages: [DocumentPageRecord] = []

    init(
        id: UUID = UUID(),
        vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        title: String,
        category: DocumentVaultCategory = .general,
        documentDate: Date = .now,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.serviceEntry = serviceEntry
        self.title = title
        self.categoryRaw = category.rawValue
        self.documentDate = documentDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension DocumentRecord {
    var category: DocumentVaultCategory {
        get { DocumentVaultCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    var sortedPages: [DocumentPageRecord] {
        pages.sorted { $0.orderIndex < $1.orderIndex }
    }

    var pageCount: Int {
        pages.count
    }
}
