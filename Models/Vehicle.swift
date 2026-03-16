import Foundation
import SwiftData

@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var make: String
    var model: String
    var year: Int
    var licensePlate: String
    var currentMileage: Int
    var purchaseDate: Date?
    var purchasePrice: Double?
    var currencyCode: String
    var vin: String
    var notes: String
    var coverImageReference: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ServiceEntry.vehicle)
    var serviceEntries: [ServiceEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \AttachmentRecord.vehicle)
    var attachments: [AttachmentRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \ReminderItem.vehicle)
    var reminders: [ReminderItem] = []

    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        licensePlate: String = "",
        currentMileage: Int = 0,
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        currencyCode: String = "EUR",
        vin: String = "",
        notes: String = "",
        coverImageReference: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.licensePlate = licensePlate
        self.currentMileage = currentMileage
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.currencyCode = currencyCode
        self.vin = vin
        self.notes = notes
        self.coverImageReference = coverImageReference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Vehicle {
    var title: String {
        "\(make) \(model)"
    }

    var subtitle: String {
        let plate = licensePlate.isEmpty ? "No plate" : licensePlate
        return "\(year) • \(plate)"
    }

    var sortedServices: [ServiceEntry] {
        serviceEntries.sorted { $0.date > $1.date }
    }

    var sortedAttachments: [AttachmentRecord] {
        attachments.sorted { $0.createdAt > $1.createdAt }
    }

    var sortedReminders: [ReminderItem] {
        reminders.sorted { ($0.dateDue ?? .distantFuture) < ($1.dateDue ?? .distantFuture) }
    }

    var totalSpent: Double {
        serviceEntries.reduce(0) { $0 + $1.price }
    }

    var spentThisYear: Double {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: .now)) ?? .distantPast
        return serviceEntries.filter { $0.date >= start }.reduce(0) { $0 + $1.price }
    }

    var spentLast12Months: Double {
        let threshold = Calendar.current.date(byAdding: .month, value: -12, to: .now) ?? .distantPast
        return serviceEntries.filter { $0.date >= threshold }.reduce(0) { $0 + $1.price }
    }

    var latestService: ServiceEntry? {
        sortedServices.first
    }

    func highestSpendingCategory() -> EntryCategory? {
        let grouped = Dictionary(grouping: serviceEntries, by: \.category)
        return grouped.max(by: { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.price } < rhs.value.reduce(0) { $0 + $1.price }
        })?.key
    }

    func nextActiveReminder(using referenceDate: Date = .now) -> ReminderItem? {
        sortedReminders.first { reminder in
            reminder.status(for: self, referenceDate: referenceDate) != .disabled
        }
    }
}