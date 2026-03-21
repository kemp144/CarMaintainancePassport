import SwiftData
import SwiftUI

@main
struct CarServicePassportApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("dataRecovery.pendingNotice") private var pendingRecoveryNotice = ""
    @AppStorage("backup.hasOfferedRestore") private var hasOfferedRestore = false
    @AppStorage("backup.autoICloudEnabled") private var autoICloudBackupEnabled = false
    @State private var pendingRestoreURL: URL?
    @AppStorage("reminder.linkedServiceRepair.v1") private var didRepairLinkedServiceReminders = false
    @AppStorage("reminder.linkedServiceCleanup.v1") private var didCleanupLinkedServiceReminders = false
    @AppStorage("vehicle.mileageTimelineRepair.v1") private var didRepairVehicleMileageTimeline = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var paywallCoordinator = PaywallCoordinator()
    @StateObject private var appState = AppState()

    private let modelContainer = Self.makeModelContainer()

    init() {
        UnitSettings.registerDefaultValues()
        CurrencyPreset.registerDefaultValue()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    RootTabView()
                } else {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(entitlementStore)
            .environmentObject(paywallCoordinator)
            .environmentObject(appState)
            .modelContainer(modelContainer)
            .task {
                await entitlementStore.prepare()
                await repairVehicleMileageTimelineIfNeeded()
                await repairLinkedServiceRemindersIfNeeded()
                await cleanupDuplicateLinkedServiceRemindersIfNeeded()
                await checkForBackupRestoreIfNeeded()
            }
            .sheet(item: $paywallCoordinator.reason, onDismiss: {
                paywallCoordinator.dismiss()
            }) { reason in
                PaywallView(reason: reason)
                    .environmentObject(entitlementStore)
                    .environmentObject(paywallCoordinator)
            }
            .alert(
                "Storage Recovered",
                isPresented: Binding(
                    get: { !pendingRecoveryNotice.isEmpty },
                    set: { isPresented in
                        if !isPresented {
                            pendingRecoveryNotice = ""
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    pendingRecoveryNotice = ""
                }
            } message: {
                Text(pendingRecoveryNotice)
            }
            .alert("Restore Your Data?", isPresented: Binding(
                get: { pendingRestoreURL != nil },
                set: { if !$0 { pendingRestoreURL = nil } }
            )) {
                Button("Restore") {
                    Task { await performRestore() }
                }
                Button("Skip", role: .cancel) {
                    hasOfferedRestore = true
                    pendingRestoreURL = nil
                }
            } message: {
                if let url = pendingRestoreURL,
                   let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    Text("A backup from \(AppFormatters.mediumDate.string(from: date)) was found. Restore your vehicles, services, fuel history, reminders, and documents on this device now?")
                } else {
                    Text("A previous backup was found. Restore your vehicles, services, fuel history, reminders, and documents on this device now?")
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    performAutoBackup()
                }
            }
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            ServiceEntry.self,
            AttachmentRecord.self,
            DocumentRecord.self,
            DocumentPageRecord.self,
            ReminderItem.self,
            FuelEntry.self
        ])

        let storeURL = defaultStoreURL()
        // Keep the app database local. iCloud is used only for exported backup files,
        // not for SwiftData/CloudKit sync, because the current schema is not CloudKit-safe.
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            recoverIncompatibleStore(at: storeURL, error: error)

            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Failed to create model container after recovery attempt: \(error)")
            }
        }
    }

    private static func defaultStoreURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        if !FileManager.default.fileExists(atPath: applicationSupportURL.path) {
            try? FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        }
        return applicationSupportURL.appendingPathComponent("default.store")
    }

    private static func recoverIncompatibleStore(at storeURL: URL, error: Error) {
        let fileManager = FileManager.default
        let applicationSupportURL = storeURL.deletingLastPathComponent()
        let recoveryRootURL = applicationSupportURL.appendingPathComponent("Recovered Stores", isDirectory: true)
        let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let recoveryDirectoryURL = recoveryRootURL.appendingPathComponent(timestamp, isDirectory: true)
        let sidecarURLs = [storeURL, storeURL.appendingPathExtension("wal"), storeURL.appendingPathExtension("shm")]

        if sidecarURLs.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
            try? fileManager.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)

            for url in sidecarURLs where fileManager.fileExists(atPath: url.path) {
                let destinationURL = recoveryDirectoryURL.appendingPathComponent(url.lastPathComponent)

                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.moveItem(at: url, to: destinationURL)
                } catch {
                    try? fileManager.removeItem(at: url)
                }
            }
        }

        UserDefaults.standard.set(
            "An older local database couldn’t be opened after the latest model update. The app created a fresh local store and archived the previous files in Recovered Stores.",
            forKey: "dataRecovery.pendingNotice"
        )

        #if DEBUG
        print("[SwiftDataRecovery] Recovered incompatible store at \(storeURL.path): \(error)")
        #endif
    }

    private func performAutoBackup() {
        guard entitlementStore.canUseAutomaticICloudBackup() else { return }
        guard autoICloudBackupEnabled else { return }
        guard BackupExportService.shared.locationAvailable(.iCloud) else { return }

        do {
            let ctx = modelContainer.mainContext
            try BackupExportService.shared.saveBackup(
                vehicles:    try ctx.fetch(FetchDescriptor<Vehicle>()),
                services:    try ctx.fetch(FetchDescriptor<ServiceEntry>()),
                reminders:   try ctx.fetch(FetchDescriptor<ReminderItem>()),
                attachments: try ctx.fetch(FetchDescriptor<AttachmentRecord>()),
                documents:   try ctx.fetch(FetchDescriptor<DocumentRecord>()),
                fuelEntries: try ctx.fetch(FetchDescriptor<FuelEntry>()),
                preferredLocation: .iCloud
            )
        } catch {
            // Silent — backup failure must never interrupt the user experience.
        }
    }

    @MainActor
    private func checkForBackupRestoreIfNeeded() async {
        guard !hasOfferedRestore else { return }
        let restoreLocations: [BackupExportService.BackupLocation] = entitlementStore.canUseICloudBackupRestore()
            ? [.iCloud, .local]
            : [.local]
        guard let backupURL = BackupExportService.shared.findLatestBackup(locations: restoreLocations) else { return }
        let vehicles = (try? modelContainer.mainContext.fetch(FetchDescriptor<Vehicle>())) ?? []
        guard vehicles.isEmpty else {
            // Data already exists — no restore needed.
            hasOfferedRestore = true
            return
        }
        pendingRestoreURL = backupURL
    }

    @MainActor
    private func performRestore() async {
        guard let url = pendingRestoreURL else { return }
        hasOfferedRestore = true
        pendingRestoreURL = nil
        do {
            _ = try await AppDataMaintenanceService.replaceLocalData(with: url, in: modelContainer.mainContext)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    @MainActor
    private func repairVehicleMileageTimelineIfNeeded() async {
        guard !didRepairVehicleMileageTimeline else { return }

        do {
            let context = modelContainer.mainContext
            let vehicles = try context.fetch(FetchDescriptor<Vehicle>())

            for vehicle in vehicles {
                VehicleMileageResolver.recalculateCurrentMileage(for: vehicle, updateTimestamp: nil)
            }

            try? context.save()
            didRepairVehicleMileageTimeline = true
        } catch {
            // If repair fails, we try again on next launch.
        }
    }

    @MainActor
    private func repairLinkedServiceRemindersIfNeeded() async {
        guard !didRepairLinkedServiceReminders else { return }

        do {
            let context = modelContainer.mainContext
            let services = try context.fetch(FetchDescriptor<ServiceEntry>())
            let reminders = try context.fetch(FetchDescriptor<ReminderItem>())
            let calendar = Calendar.current

            for service in services {
                let expectedTitle = "\(service.displayTitle) due"
                let repairedDate = calendar.date(byAdding: .month, value: 12, to: service.date)

                for reminder in reminders {
                    let reminderTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let titleMatches = reminderTitle == expectedTitle
                    let serviceMatches = reminder.serviceEntry?.id == service.id || reminder.linkedServiceEntryID == service.id
                    let vehicleMatches = reminder.vehicle?.id == service.vehicle?.id

                    guard vehicleMatches, titleMatches || serviceMatches else { continue }

                    reminder.linkedServiceEntryID = service.id
                    reminder.linkedServiceDate = service.date
                    reminder.linkedServiceMileage = service.mileage

                    if let repairedDate {
                        reminder.dateDue = repairedDate
                    }

                    reminder.updatedAt = .now

                    if reminder.isEnabled, reminder.dateDue != nil, let vehicle = reminder.vehicle {
                        NotificationService.shared.cancel(identifier: reminder.notificationIdentifier)
                        reminder.notificationIdentifier = (await NotificationService.shared.schedule(for: reminder, vehicleName: vehicle.title)).identifier
                    }
                }
            }

            try? context.save()
            didRepairLinkedServiceReminders = true
        } catch {
            // If repair fails, we just try again on next launch.
        }
    }

    @MainActor
    private func cleanupDuplicateLinkedServiceRemindersIfNeeded() async {
        guard !didCleanupLinkedServiceReminders else { return }

        do {
            let context = modelContainer.mainContext
            let reminders = try context.fetch(FetchDescriptor<ReminderItem>())
            let grouped = Dictionary(grouping: reminders) { $0.deduplicationKey }

            for (_, items) in grouped where items.count > 1 {
                let sorted = items.sorted {
                    if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                    if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                    return $0.id.uuidString < $1.id.uuidString
                }

                for duplicate in sorted.dropFirst() {
                    context.delete(duplicate)
                }
            }

            try? context.save()
            didCleanupLinkedServiceReminders = true
        } catch {
            // If cleanup fails, we can try again on next launch.
        }
    }
}
