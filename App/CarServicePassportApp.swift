import SwiftData
import SwiftUI

@main
struct CarServicePassportApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("settings.autoBackup") private var autoBackupEnabled = false
    @AppStorage("dataRecovery.pendingNotice") private var pendingRecoveryNotice = ""
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var paywallCoordinator = PaywallCoordinator()
    @StateObject private var appState = AppState()

    private let modelContainer = Self.makeModelContainer()

    init() {
        UnitSettings.registerDefaultValues()
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
            }
            .sheet(item: $paywallCoordinator.reason) { reason in
                PaywallView(reason: reason)
                    .environmentObject(entitlementStore)
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background, autoBackupEnabled {
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
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

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
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        do {
            let context = modelContainer.mainContext
            let vehicles = try context.fetch(FetchDescriptor<Vehicle>())
            let services = try context.fetch(FetchDescriptor<ServiceEntry>())
            let reminders = try context.fetch(FetchDescriptor<ReminderItem>())
            let attachments = try context.fetch(FetchDescriptor<AttachmentRecord>())
            let documents = try context.fetch(FetchDescriptor<DocumentRecord>())
            try BackupExportService.shared.saveToDocuments(
                vehicles: vehicles,
                services: services,
                reminders: reminders,
                attachments: attachments,
                documents: documents
            )
        } catch {
            // silent — auto backup failure should not interrupt the user
        }
    }
}
