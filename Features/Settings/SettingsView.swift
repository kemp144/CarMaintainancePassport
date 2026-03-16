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
        ZStack {
            PremiumScreenBackground()

            List {
                Section("Preferences") {
                    Picker("Default currency", selection: $defaultCurrency) {
                        ForEach(CurrencyPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                    Toggle("Show only global selected vehicle", isOn: $appState.showOnlyCurrentVehicle)
                }

                Section("Pro") {
                    if entitlementStore.hasProAccess {
                        Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Button("Upgrade to Pro") {
                            paywallCoordinator.present(.settings)
                        }
                        Button("Restore Purchases") {
                            Task {
                                await entitlementStore.restorePurchases()
                            }
                        }
                    }

                    #if DEBUG
                    Toggle("Debug Pro Override", isOn: Binding(get: {
                        entitlementStore.debugProOverride
                    }, set: { value in
                        entitlementStore.setDebugOverride(value)
                    }))
                    
                    Button("Generate Demo Garage") {
                        PreviewData.generateDemoGarage(in: modelContext)
                        Haptics.success()
                    }
                    #endif
                }

                Section("Backup") {
                    Button("Export JSON Backup") {
                        exportBackup()
                    }
                    Text("Create a local JSON snapshot for personal backup. iCloud sync can be added later without changing your records.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("Notifications") {
                    Button("Open Notification Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Text("Permission is requested only when you enable date-based reminders.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("Privacy") {
                    Text("Car Service Passport is local-first. No account, no ads and no backend dependency are required in V1.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryText)
                }

                Section("Support") {
                    Text("Feedback and support options can be added here before release.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Vehicles", value: "\(vehicles.count)")
                    LabeledContent("Entries", value: "\(services.count)")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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