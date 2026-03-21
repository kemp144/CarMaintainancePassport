import Foundation
import SwiftData

@MainActor
enum AppDataMaintenanceService {
    enum RestoreError: LocalizedError {
        case rollbackFailed(restoreError: Error, rollbackError: Error)

        var errorDescription: String? {
            switch self {
            case .rollbackFailed(let restoreError, let rollbackError):
                return "Restore failed, and the safety rollback also failed. Restore error: \(restoreError.localizedDescription). Rollback error: \(rollbackError.localizedDescription)."
            }
        }
    }

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

    static func replaceLocalData(with backupURL: URL, in modelContext: ModelContext) async throws -> BackupExportService.ImportResult {
        let existingVehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())
        let existingServices = try modelContext.fetch(FetchDescriptor<ServiceEntry>())
        let existingReminders = try modelContext.fetch(FetchDescriptor<ReminderItem>())
        let existingAttachments = try modelContext.fetch(FetchDescriptor<AttachmentRecord>())
        let existingDocuments = try modelContext.fetch(FetchDescriptor<DocumentRecord>())
        let existingFuelEntries = try modelContext.fetch(FetchDescriptor<FuelEntry>())

        let hasExistingData = !existingVehicles.isEmpty
            || !existingServices.isEmpty
            || !existingReminders.isEmpty
            || !existingAttachments.isEmpty
            || !existingDocuments.isEmpty
            || !existingFuelEntries.isEmpty

        let safetySnapshotURL = hasExistingData
            ? try BackupExportService.shared.saveBackup(
                vehicles: existingVehicles,
                services: existingServices,
                reminders: existingReminders,
                attachments: existingAttachments,
                documents: existingDocuments,
                fuelEntries: existingFuelEntries,
                preferredLocation: .local,
                isSafetySnapshot: true
            )
            : nil

        cancelNotifications(identifiers: notificationIdentifiers(for: existingReminders))
        try clearAllCurrentData(in: modelContext)

        do {
            let result = try BackupExportService.shared.importJSON(from: backupURL, into: modelContext)
            try await rescheduleReminderNotifications(in: modelContext)
            return result
        } catch {
            let restoreError = error
            modelContext.rollback()

            do {
                try clearAllCurrentData(in: modelContext)

                if let safetySnapshotURL {
                    _ = try BackupExportService.shared.importJSON(from: safetySnapshotURL, into: modelContext)
                    try await rescheduleReminderNotifications(in: modelContext)
                }
            } catch let rollbackError {
                throw RestoreError.rollbackFailed(restoreError: restoreError, rollbackError: rollbackError)
            }

            throw restoreError
        }
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

    private static func clearAllCurrentData(in modelContext: ModelContext) throws {
        let vehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())

        for vehicle in vehicles {
            modelContext.delete(vehicle)
        }

        try modelContext.save()

        for vehicle in vehicles {
            VehicleManualMileageStore.setManualMileage(nil, for: vehicle)
        }
    }

    private static func deleteStoredReferences(_ references: [String]) async {
        for reference in Set(references) {
            await AttachmentStorageService.shared.delete(reference: reference)
        }
    }
}
