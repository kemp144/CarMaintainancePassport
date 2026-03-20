import Foundation
import SwiftData

@Model
final class ReminderItem {
    @Attribute(.unique) var id: UUID

    var vehicle: Vehicle?

    var serviceEntry: ServiceEntry?
    var linkedServiceEntryID: UUID?
    var linkedServiceDate: Date?
    var linkedServiceMileage: Int?

    var typeRaw: String
    var title: String
    var notes: String
    var dateDue: Date?
    var mileageDue: Int?
    var notificationTimingRaw: String
    var isEnabled: Bool
    var notificationIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        linkedServiceEntryID: UUID? = nil,
        linkedServiceDate: Date? = nil,
        linkedServiceMileage: Int? = nil,
        type: ReminderType,
        title: String,
        notes: String = "",
        dateDue: Date? = nil,
        mileageDue: Int? = nil,
        notificationTiming: NotificationTiming = .sevenDaysBefore,
        isEnabled: Bool = true,
        notificationIdentifier: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.vehicle = vehicle
        self.serviceEntry = serviceEntry
        self.linkedServiceEntryID = linkedServiceEntryID
        self.linkedServiceDate = linkedServiceDate
        self.linkedServiceMileage = linkedServiceMileage
        self.typeRaw = type.rawValue
        self.title = title
        self.notes = notes
        self.dateDue = dateDue
        self.mileageDue = mileageDue
        self.notificationTimingRaw = notificationTiming.rawValue
        self.isEnabled = isEnabled
        self.notificationIdentifier = notificationIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ReminderItem {
    var type: ReminderType {
        get { ReminderType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var notificationTiming: NotificationTiming {
        get { NotificationTiming(rawValue: notificationTimingRaw) ?? .sevenDaysBefore }
        set { notificationTimingRaw = newValue.rawValue }
    }

    func status(for vehicle: Vehicle, referenceDate: Date = .now) -> ReminderStatus {
        guard isEnabled else { return .disabled }

        if let dateDue {
            if dateDue < referenceDate.startOfDay {
                return .overdue
            }

            let dueSoonThreshold = Calendar.current.date(byAdding: .day, value: 14, to: referenceDate) ?? referenceDate
            if dateDue <= dueSoonThreshold {
                return .dueSoon
            }
        }

        if let mileageDue {
            if vehicle.currentMileage >= mileageDue {
                return .overdue
            }

            if mileageDue - vehicle.currentMileage <= 1_000 {
                return .dueSoon
            }
        }

        return .upcoming
    }

    var deduplicationKey: String {
        guard let linkedServiceKey = linkedServiceEntryID?.uuidString ?? serviceEntry?.id.uuidString else {
            return id.uuidString
        }

        let vehicleKey = vehicle?.id.uuidString ?? "no-vehicle"
        return "\(vehicleKey)|\(linkedServiceKey)|\(typeRaw)"
    }
}

extension Array where Element == ReminderItem {
    func deduplicatedLinkedReminders() -> [ReminderItem] {
        var seen: [String: ReminderItem] = [:]

        for reminder in self {
            let key = reminder.deduplicationKey
            if let current = seen[key] {
                if reminder.updatedAt > current.updatedAt {
                    seen[key] = reminder
                }
            } else {
                seen[key] = reminder
            }
        }

        return seen.values.sorted {
            let lhsDate = $0.dateDue ?? .distantFuture
            let rhsDate = $1.dateDue ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
