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

    @AppStorage("settings.autoBackup") private var autoBackupEnabled = false

    @State private var backupURL: URL?
    @State private var showingImportPicker = false
    @State private var importResult: BackupExportService.ImportResult?
    @State private var importError: String?
    @State private var showingImportResult = false
    @State private var isImporting = false

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Settings")
                                .font(.system(size: 30, weight: .bold)) // text-3xl
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text("Preferences and app info")
                                .font(.system(size: 16)) // text-base
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48) // pt-12
                .padding(.bottom, 32) // pb-8
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
                        VStack(alignment: .leading, spacing: 12) {
                            if entitlementStore.hasProAccess {
                                Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(AppTheme.success)
                            } else {
                                Text("Pro adds unlimited vehicles, smarter mileage reminders, OCR scanning, and resale-ready exports.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)

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

                            VStack(alignment: .leading, spacing: 8) {
                                settingsProRow(title: "Unlimited vehicles", icon: "car.2.fill")
                                settingsProRow(title: "Mileage reminders", icon: "speedometer")
                                settingsProRow(title: "OCR and advanced export", icon: "doc.viewfinder")
                            }
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

                        Button("Save Backup to Files") {
                            saveBackupToDocuments()
                        }
                        .foregroundStyle(AppTheme.accent)

                        Toggle("Auto Backup on Background", isOn: $autoBackupEnabled)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Backups are saved locally in Files. Enable auto backup to save your library when the app moves to the background.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Backup")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        if isImporting {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Importing…")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        } else {
                            Button("Import from JSON Backup") {
                                if entitlementStore.canImportData() {
                                    showingImportPicker = true
                                } else {
                                    paywallCoordinator.present(.importData)
                                }
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                        Text("Import a previously exported backup. Existing records with the same ID are skipped to avoid duplicates.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Import")
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
                        Text("Permission is requested only when you enable reminders that need notifications.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    } header: {
                        Text("Notifications")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .listRowBackground(AppTheme.surface)

                    Section {
                        Text("Car Service Passport is local-first. No account, no ads, and no backend dependency are required.")
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
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importBackup(from: url)
            }
        }
        .alert(
            importError != nil ? "Import Failed" : "Import Complete",
            isPresented: $showingImportResult
        ) {
            Button("OK", role: .cancel) {
                importError = nil
                importResult = nil
            }
        } message: {
            if let err = importError {
                Text(err)
            } else if let r = importResult {
                Text("Imported \(r.vehiclesImported) vehicle(s), \(r.servicesImported) service(s), and \(r.remindersImported) reminder(s).")
            }
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

    private func saveBackupToDocuments() {
        do {
            try BackupExportService.shared.saveToDocuments(vehicles: vehicles, services: services, reminders: reminders, attachments: attachments)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    private func importBackup(from url: URL) {
        isImporting = true
        Task {
            do {
                let result = try await MainActor.run {
                    try BackupExportService.shared.importJSON(from: url, into: modelContext)
                }
                importResult = result
                importError = nil
                Haptics.success()
            } catch {
                importError = error.localizedDescription
                Haptics.error()
            }
            isImporting = false
            showingImportResult = true
        }
    }

    private func settingsProRow(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}