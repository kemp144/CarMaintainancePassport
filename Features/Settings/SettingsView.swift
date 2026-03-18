import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @EnvironmentObject private var appState: AppState

    @AppStorage("settings.defaultCurrency") private var defaultCurrency = CurrencyPreset.eur.rawValue

    @Query private var vehicles: [Vehicle]
    @Query private var services: [ServiceEntry]
    @Query private var reminders: [ReminderItem]
    @Query private var attachments: [AttachmentRecord]

    @State private var backupURL: URL?

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text("Preferences and app info")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .background(AppTheme.heroGradient)

                List {
                    Section {
                        Picker("Default currency", selection: $defaultCurrency) {
                            ForEach(CurrencyPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset.rawValue)
                            }
                        }
                        .foregroundStyle(AppTheme.primaryText)
                        Toggle("Show only global selected vehicle", isOn: $appState.showOnlyCurrentVehicle)
                            .foregroundStyle(AppTheme.primaryText)
                    } header: {
                        Text("Preferences")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        if entitlementStore.hasProAccess {
                            Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.success)
                        } else {
                            Button("Upgrade to Pro") {
                                paywallCoordinator.present(.settings)
                            }
                            .foregroundStyle(AppTheme.accent)
                            Button("Restore Purchases") {
                                Task {
                                    await entitlementStore.restorePurchases()
                                }
                            }
                            .foregroundStyle(AppTheme.accent)
                        }

                        #if DEBUG
                        Toggle("Debug Pro Override", isOn: Binding(get: {
                            entitlementStore.debugProOverride
                        }, set: { value in
                            entitlementStore.setDebugOverride(value)
                        }))
                        .foregroundStyle(AppTheme.primaryText)
                        
                        Button("Generate Demo Garage") {
                            PreviewData.generateDemoGarage(in: modelContext)
                            Haptics.success()
                        }
                        .foregroundStyle(AppTheme.accent)
                        #endif
                    } header: {
                        Text("Pro")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        Button("Export JSON Backup") {
                            exportBackup()
                        }
                        .foregroundStyle(AppTheme.accent)
                        Text("Create a local JSON snapshot for personal backup. iCloud sync can be added later without changing your records.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Backup")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        Button("Open Notification Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .foregroundStyle(AppTheme.accent)
                        Text("Permission is requested only when you enable date-based reminders.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Notifications")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        Text("Car Service Passport is local-first. No account, no ads and no backend dependency are required in V1.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primaryText)
                    } header: {
                        Text("Privacy")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        Text("Feedback and support options can be added here before release.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Support")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        LabeledContent("Version", value: appVersion)
                            .foregroundStyle(AppTheme.primaryText)
                        LabeledContent("Vehicles", value: "\(vehicles.count)")
                            .foregroundStyle(AppTheme.primaryText)
                        LabeledContent("Entries", value: "\(services.count)")
                            .foregroundStyle(AppTheme.primaryText)
                    } header: {
                        Text("About")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationBarHidden(true)
        .sheet(item: Binding(get: {
            backupURL.map(PreviewURL.init(url:))
        }, set: { value in
            backupURL = value?.url
        })) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func exportBackup() {
        do {
            backupURL = try BackupExportService.shared.exportJSON(vehicles: vehicles, services: services, reminders: reminders, attachments: attachments)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}