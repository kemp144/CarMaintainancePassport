import Foundation
import SwiftData

@MainActor
enum AppDataMaintenanceService {
    static func storedReferences(for vehicle: Vehicle) -> [String] {
        let documentPageReferences = vehicle.documents.flatMap { document in
            document.sortedPages.flatMap { [$0.storageReference, $0.thumbnailReference].compactMap { $0 } }
        }
        let legacyAttachmentReferences = vehicle.attachments.flatMap { [$0.storageReference, $0.thumbnailReference].compactMap { $0 } }
        let fuelReceiptReferences = vehicle.fuelEntries.flatMap { [$0.receiptStorageReference, $0.receiptThumbnailReference].compactMap { $0 } }

        return Array(
            Set(
                [vehicle.coverImageReference].compactMap { $0 }
                    + legacyAttachmentReferences
                    + documentPageReferences
                    + fuelReceiptReferences
            )
        )
    }

    static func notificationIdentifiers(for reminders: [ReminderItem]) -> [String] {
        Array(Set(reminders.compactMap(\.notificationIdentifier)))
    }

    static func deleteVehicle(_ vehicle: Vehicle, in modelContext: ModelContext) async throws {
        let storedReferences = storedReferences(for: vehicle)
        let notificationIDs = notificationIdentifiers(for: vehicle.reminders)

        modelContext.delete(vehicle)
        try modelContext.save()

        VehicleManualMileageStore.setManualMileage(nil, for: vehicle)
        cancelNotifications(identifiers: notificationIDs)
        await deleteStoredReferences(storedReferences)
    }

    static func deleteServiceEntry(_ entry: ServiceEntry, in modelContext: ModelContext) async throws {
        let storedReferences = entry.attachments.flatMap { [$0.storageReference, $0.thumbnailReference].compactMap { $0 } }

        if let vehicle = entry.vehicle {
            modelContext.delete(entry)
            VehicleMileageResolver.recalculateCurrentMileage(for: vehicle)
        } else {
            modelContext.delete(entry)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        await deleteStoredReferences(storedReferences)
    }

    static func deleteFuelEntry(_ entry: FuelEntry, in modelContext: ModelContext) async throws {
        let storedReferences = [entry.receiptStorageReference, entry.receiptThumbnailReference].compactMap { $0 }

        if let vehicle = entry.vehicle {
            modelContext.delete(entry)
            VehicleMileageResolver.recalculateCurrentMileage(for: vehicle)
        } else {
            modelContext.delete(entry)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        await deleteStoredReferences(storedReferences)
    }

    static func resetAllData(vehicles: [Vehicle], in modelContext: ModelContext) async throws {
        let storedReferences = vehicles.flatMap(storedReferences(for:))
        let notificationIDs = vehicles.flatMap { notificationIdentifiers(for: $0.reminders) }

        for vehicle in vehicles {
            modelContext.delete(vehicle)
        }
        try modelContext.save()

        for vehicle in vehicles {
            VehicleManualMileageStore.setManualMileage(nil, for: vehicle)
        }
        cancelNotifications(identifiers: notificationIDs)
        await deleteStoredReferences(storedReferences)
    }

    static func rescheduleReminderNotifications(in modelContext: ModelContext) async throws {
        let reminders = try modelContext.fetch(FetchDescriptor<ReminderItem>())

        for reminder in reminders {
            NotificationService.shared.cancel(identifier: reminder.notificationIdentifier)

            guard reminder.isEnabled, reminder.dateDue != nil, let vehicleName = reminder.vehicle?.title else {
                reminder.notificationIdentifier = nil
                continue
            }

            let outcome = await NotificationService.shared.schedule(for: reminder, vehicleName: vehicleName)
            reminder.notificationIdentifier = outcome.identifier
        }

        try modelContext.save()
    }

    private static func cancelNotifications(identifiers: [String]) {
        for identifier in Set(identifiers) {
            NotificationService.shared.cancel(identifier: identifier)
        }
    }

    private static func deleteStoredReferences(_ references: [String]) async {
        for reference in Set(references) {
            await AttachmentStorageService.shared.delete(reference: reference)
        }
    }
}
