import SwiftData
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                NavigationStack {
                    GarageView()
                }
                .tag(AppTab.garage)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    TimelineView()
                }
                .tag(AppTab.timeline)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    RemindersView()
                }
                .tag(AppTab.reminders)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    SettingsView()
                }
                .tag(AppTab.settings)
                .toolbar(.hidden, for: .tabBar)
            }

            CustomTabBar(selectedTab: $appState.selectedTab)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(tab: .garage, icon: "car.fill", title: "Garage", selectedTab: $selectedTab)
            TabBarItem(tab: .timeline, icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "Timeline", selectedTab: $selectedTab)
            TabBarItem(tab: .reminders, icon: "bell.fill", title: "Reminders", selectedTab: $selectedTab)
            TabBarItem(tab: .settings, icon: "gearshape.fill", title: "Settings", selectedTab: $selectedTab)
        }
        .frame(height: 80)
        .background(
            Rectangle()
                .fill(AppTheme.elevatedBackground.opacity(0.95))
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.separator),
            alignment: .top
        )
    }
}

struct TabBarItem: View {
    let tab: AppTab
    let icon: String
    let title: String
    @Binding var selectedTab: AppTab

    var isSelected: Bool {
        selectedTab == tab
    }

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: 48, height: 4)
                        .offset(y: -14)
                } else {
                    Color.clear
                        .frame(width: 48, height: 4)
                        .offset(y: -14)
                }

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("App Root") {
    RootTabView()
        .environmentObject(EntitlementStore())
        .environmentObject(PaywallCoordinator())
        .modelContainer(PreviewData.makeContainer())
}