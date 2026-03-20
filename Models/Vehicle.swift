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

    @Relationship(deleteRule: .cascade, inverse: \DocumentRecord.vehicle)
    var documents: [DocumentRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \ReminderItem.vehicle)
    var reminders: [ReminderItem] = []

    @Relationship(deleteRule: .cascade, inverse: \FuelEntry.vehicle)
    var fuelEntries: [FuelEntry] = []

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

    var sortedDocuments: [DocumentRecord] {
        documents.sorted { $0.createdAt > $1.createdAt }
    }

    var documentsCount: Int {
        attachments.count + documents.count
    }

    var activeRemindersCount: Int {
        reminders.deduplicatedLinkedReminders().filter { $0.isEnabled }.count
    }

    var sortedReminders: [ReminderItem] {
        reminders
            .deduplicatedLinkedReminders()
            .sorted { ($0.dateDue ?? .distantFuture) < ($1.dateDue ?? .distantFuture) }
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

    var latestServiceDate: Date? {
        latestService?.date
    }

    var nextDueReminder: ReminderItem? {
        nextActiveReminder()
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

    /// The date of the entry that established the current mileage high-water mark.
    var latestMileageDate: Date? {
        VehicleMileageResolver.lastKnownMileageDate(for: self)
    }

    var sortedFuelEntries: [FuelEntry] {
        fuelEntries.sorted { $0.date > $1.date }
    }

    var totalFuelCost: Double {
        FuelAnalyticsService.summary(for: fuelEntries).totalCost
    }

    var totalFuelLiters: Double {
        FuelAnalyticsService.summary(for: fuelEntries).totalLiters
    }

    var resolvedCurrentMileage: Int? {
        VehicleMileageResolver.currentMileage(for: self)
    }

    var currentMileageDisplayString: String {
        VehicleMileageResolver.displayCurrentMileage(for: self)
    }
}

struct VehicleManualMileageSnapshot: Codable {
    let mileage: Int
    let updatedAt: Date
}

enum VehicleManualMileageStore {
    private static let storageKey = "vehicle.manualMileageSnapshots.v1"

    static func manualMileageSnapshot(for vehicle: Vehicle) -> VehicleManualMileageSnapshot? {
        loadSnapshots()[vehicle.id.uuidString]
    }

    static func manualMileage(for vehicle: Vehicle) -> Int? {
        manualMileageSnapshot(for: vehicle)?.mileage
    }

    static func setManualMileage(_ mileage: Int?, for vehicle: Vehicle, at updatedAt: Date = .now) {
        var snapshots = loadSnapshots()
        let key = vehicle.id.uuidString

        if let mileage {
            snapshots[key] = VehicleManualMileageSnapshot(mileage: mileage, updatedAt: updatedAt)
        } else {
            snapshots.removeValue(forKey: key)
        }

        saveSnapshots(snapshots)
    }

    static func seedLegacyManualMileageIfNeeded(for vehicle: Vehicle) {
        guard manualMileageSnapshot(for: vehicle) == nil else { return }
        guard vehicle.currentMileage > 0 else { return }

        let hasTimelineEntries = vehicle.fuelEntries.contains(where: { $0.mileage > 0 })
            || vehicle.serviceEntries.contains(where: { $0.mileage > 0 })
        guard !hasTimelineEntries else { return }

        setManualMileage(vehicle.currentMileage, for: vehicle, at: vehicle.updatedAt)
    }

    private static func loadSnapshots() -> [String: VehicleManualMileageSnapshot] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: VehicleManualMileageSnapshot].self, from: data)
        else {
            return [:]
        }

        return decoded
    }

    private static func saveSnapshots(_ snapshots: [String: VehicleManualMileageSnapshot]) {
        guard let encoded = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}

enum VehicleMileageResolver {
    struct MileageEvent {
        let mileage: Int
        let date: Date
        let updatedAt: Date
        let createdAt: Date
        let sourcePriority: Int
        let stableID: String
    }

    static func currentMileage(for vehicle: Vehicle) -> Int? {
        latestMileageEvent(for: vehicle)?.mileage ?? VehicleManualMileageStore.manualMileage(for: vehicle)
    }

    static func displayCurrentMileage(for vehicle: Vehicle) -> String {
        currentMileage(for: vehicle).map(AppFormatters.mileage) ?? "Mileage not set"
    }

    static func lastKnownMileageDate(for vehicle: Vehicle) -> Date? {
        latestMileageEvent(for: vehicle)?.date
    }

    static func latestMileageEvent(for vehicle: Vehicle) -> MileageEvent? {
        VehicleManualMileageStore.seedLegacyManualMileageIfNeeded(for: vehicle)
        return mileageEvents(for: vehicle).max(by: isEarlier(_:than:))
    }

    static func recalculateCurrentMileage(for vehicle: Vehicle, updateTimestamp: Date? = .now) {
        VehicleManualMileageStore.seedLegacyManualMileageIfNeeded(for: vehicle)

        if let mileage = currentMileage(for: vehicle) {
            vehicle.currentMileage = mileage
        } else {
            vehicle.currentMileage = 0
        }

        if let updateTimestamp {
            vehicle.updatedAt = updateTimestamp
        }
    }

    private static func mileageEvents(for vehicle: Vehicle) -> [MileageEvent] {
        let fuelEvents = vehicle.fuelEntries.compactMap { entry -> MileageEvent? in
            guard entry.mileage > 0 else { return nil }
            return MileageEvent(
                mileage: entry.mileage,
                date: Calendar.current.startOfDay(for: entry.date),
                updatedAt: entry.updatedAt,
                createdAt: entry.createdAt,
                sourcePriority: 0,
                stableID: "fuel-\(entry.id.uuidString)"
            )
        }

        let serviceEvents = vehicle.serviceEntries.compactMap { entry -> MileageEvent? in
            guard entry.mileage > 0 else { return nil }
            return MileageEvent(
                mileage: entry.mileage,
                date: Calendar.current.startOfDay(for: entry.date),
                updatedAt: entry.updatedAt,
                createdAt: entry.createdAt,
                sourcePriority: 1,
                stableID: "service-\(entry.id.uuidString)"
            )
        }

        let manualEvent = VehicleManualMileageStore.manualMileageSnapshot(for: vehicle).map { snapshot in
            MileageEvent(
                mileage: snapshot.mileage,
                date: Calendar.current.startOfDay(for: snapshot.updatedAt),
                updatedAt: snapshot.updatedAt,
                createdAt: snapshot.updatedAt,
                sourcePriority: 2,
                stableID: "manual-\(vehicle.id.uuidString)"
            )
        }

        return fuelEvents + serviceEvents + (manualEvent.map { [$0] } ?? [])
    }

    private static func isEarlier(_ lhs: MileageEvent, than rhs: MileageEvent) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        if lhs.sourcePriority != rhs.sourcePriority { return lhs.sourcePriority < rhs.sourcePriority }
        return lhs.stableID < rhs.stableID
    }
}
