import SwiftData
import SwiftUI

@main
struct CarServicePassportApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var paywallCoordinator = PaywallCoordinator()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            ServiceEntry.self,
            AttachmentRecord.self,
            ReminderItem.self
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
            .modelContainer(modelContainer)
            .task {
                await entitlementStore.prepare()
            }
            .sheet(item: $paywallCoordinator.reason) { reason in
                PaywallView(reason: reason)
                    .environmentObject(entitlementStore)
            }
        }
    }
}