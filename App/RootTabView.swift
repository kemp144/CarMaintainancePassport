import SwiftData
import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .garage

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                GarageView()
            }
            .tag(AppTab.garage)
            .tabItem {
                Label("Garage", systemImage: "car.fill")
            }

            NavigationStack {
                TimelineView()
            }
            .tag(AppTab.timeline)
            .tabItem {
                Label("Timeline", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            NavigationStack {
                RemindersView()
            }
            .tag(AppTab.reminders)
            .tabItem {
                Label("Reminders", systemImage: "bell.fill")
            }

            NavigationStack {
                DocumentsView()
            }
            .tag(AppTab.documents)
            .tabItem {
                Label("Documents", systemImage: "folder.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(AppTheme.accentSecondary)
    }
}

#Preview("App Root") {
    RootTabView()
        .environmentObject(EntitlementStore())
        .environmentObject(PaywallCoordinator())
        .modelContainer(PreviewData.makeContainer())
}