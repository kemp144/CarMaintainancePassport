import SwiftData
import SwiftUI

@main
struct CarServicePassportApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("settings.autoBackup") private var autoBackupEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var paywallCoordinator = PaywallCoordinator()
    @StateObject private var appState = AppState()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            ServiceEntry.self,
            AttachmentRecord.self,
            DocumentRecord.self,
            DocumentPageRecord.self,
            ReminderItem.self,
            FuelEntry.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background, autoBackupEnabled {
                    performAutoBackup()
                }
            }
        }
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
