import SwiftData
import SwiftUI

struct SettingsView: View {
    private struct BackupFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private let settingsRowHorizontalPadding: CGFloat = 14
    private let settingsRowVerticalPadding: CGFloat = 11
    private let settingsRowSpacing: CGFloat = 12
    private let settingsInfoIconWidth: CGFloat = 12

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @EnvironmentObject private var appState: AppState

    @AppStorage("settings.defaultCurrency") private var defaultCurrency = CurrencyPreset.suggested().rawValue
    @AppStorage(UnitSettings.useSystemDefaultKey) private var useSystemDefaultUnits = true
    @AppStorage(UnitSettings.distanceUnitKey) private var distanceUnitRaw = UnitSettings.suggestedProfile().distanceUnit.rawValue
    @AppStorage(UnitSettings.fuelVolumeUnitKey) private var fuelVolumeUnitRaw = UnitSettings.suggestedProfile().fuelVolumeUnit.rawValue
    @AppStorage(UnitSettings.consumptionUnitKey) private var consumptionUnitRaw = UnitSettings.suggestedProfile().consumptionUnit.rawValue

    @Query private var vehicles: [Vehicle]
    @Query private var services: [ServiceEntry]
    @Query private var reminders: [ReminderItem]
    @Query private var attachments: [AttachmentRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var fuelEntries: [FuelEntry]

    @State private var showingResetConfirmation = false
    @State private var showingResetFinalConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var backupFeedback: BackupFeedback?
    @State private var isRunningBackupAction = false

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    headerSection

                    VStack(spacing: 10) {
                        generalSection
                        unitsSection
                        proSection
                        backupSection
                        notificationsSection
                        privacySection
                        dangerZoneSection
                        supportSection
                        #if DEBUG
                        developerSection
                        #endif
                        aboutSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 104)
        }
        .navigationBarHidden(true)
        .confirmationDialog("Reset all data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Continue", role: .destructive) {
                showingResetFinalConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all vehicles, service entries, fuel logs, reminders, and documents. This cannot be undone.")
        }
        .alert("Are you sure?", isPresented: $showingResetFinalConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Task { await resetAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All app data will be permanently erased. Consider waiting until a recent backup exists first.")
        }
        .confirmationDialog("Restore latest backup?", isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
            Button("Restore Latest Backup") {
                Task { await restoreLatestBackup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This imports any missing records from the newest backup and reschedules reminder notifications.")
        }
        .alert(item: $backupFeedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Preferences, data, and app info")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.pageEdge)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(AppTheme.heroGradient)
    }

    private var generalSection: some View {
        settingsGroupCard(title: "General", subtitle: "Core app preferences") {
            VStack(spacing: 0) {
                settingsMenuRow(
                    title: "Currency",
                    subtitle: "Used for totals and exports.",
                    value: defaultCurrency
                ) {
                    Picker("Default currency", selection: $defaultCurrency) {
                        ForEach(CurrencyPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                }

                if vehicles.count > 1 {
                    settingsDivider()

                    settingsToggleRow(
                        title: "Show current vehicle only",
                        subtitle: "Filters shared views to the selected vehicle.",
                        isOn: $appState.showOnlyCurrentVehicle
                    )
                }
            }
        }
    }

    private var unitsSection: some View {
        settingsGroupCard(title: "Units", subtitle: "Automatic defaults keep this simple") {
            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Use automatic defaults",
                    subtitle: "Detects regional unit defaults.",
                    isOn: $useSystemDefaultUnits
                )

                settingsDivider()

                settingsInfoRow(
                    title: "Detected profile",
                    value: UnitSettings.suggestedProfile().summary,
                    accent: AppTheme.secondaryText
                )

                if useSystemDefaultUnits {
                    settingsCompactNote("Manual unit selectors are hidden while automatic defaults is on.")
                } else {
                    settingsDivider()

                    settingsMenuRow(
                        title: "Distance unit",
                        subtitle: nil,
                        value: UnitSettings.currentDistanceUnit.title
                    ) {
                        Picker("Distance unit", selection: distanceUnitBinding) {
                            ForEach(DistanceUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                    }

                    settingsDivider()

                    settingsMenuRow(
                        title: "Fuel volume unit",
                        subtitle: nil,
                        value: UnitSettings.currentFuelVolumeUnit.title
                    ) {
                        Picker("Fuel volume unit", selection: fuelVolumeUnitBinding) {
                            ForEach(FuelVolumeUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                    }

                    settingsDivider()

                    settingsMenuRow(
                        title: "Consumption unit",
                        subtitle: nil,
                        value: UnitSettings.currentConsumptionUnit.title
                    ) {
                        Picker("Consumption unit", selection: consumptionUnitBinding) {
                            ForEach(ConsumptionUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                    }
                }

                settingsCompactNote("Units affect fuel tracking, reminders, service intervals, and analytics.")
            }
        }
    }

    private var proSection: some View {
        SurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.15))

                        Image(systemName: entitlementStore.hasProAccess ? "checkmark.seal.fill" : "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(entitlementStore.hasProAccess ? AppTheme.success : AppTheme.accent)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Pro")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if entitlementStore.hasProAccess {
                                Text("Unlocked")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.success)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule(style: .continuous).fill(AppTheme.success.opacity(0.14)))
                            } else {
                                Text("Premium")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                            }
                        }

                        Text(entitlementStore.hasProAccess ? "All premium features are active on this device." : "Unlock unlimited vehicles, fuel insights, premium exports, and smarter reminders.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                if entitlementStore.hasProAccess {
                    settingsCompactNote("Premium features are ready to use whenever you need them.")
                } else {
                    HStack(spacing: 10) {
                        Button {
                            paywallCoordinator.present(.settings)
                        } label: {
                            Text("Upgrade to Pro")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            Task {
                                await entitlementStore.restorePurchases()
                            }
                        } label: {
                            Text("Restore")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
    }

    private var backupSection: some View {
        settingsGroupCard(title: "Backup", subtitle: backupSectionSubtitle) {
            VStack(spacing: 0) {
                if let lastDate = BackupExportService.shared.lastBackupDate() {
                    settingsInfoRow(
                        title: "Last backup",
                        value: AppFormatters.mediumDate.string(from: lastDate)
                    )
                    settingsDivider()
                }

                settingsInfoRow(
                    title: "Storage",
                    value: BackupExportService.shared.isUsingICloud ? "iCloud Drive" : "On device"
                )

                settingsDivider()

                settingsActionRow(
                    title: isRunningBackupAction ? "Creating backup..." : "Create backup now",
                    subtitle: "Saves a fresh snapshot of your current records.",
                    icon: "externaldrive.badge.plus"
                ) {
                    Task { await createBackupNow() }
                }

                settingsDivider()

                settingsActionRow(
                    title: isRunningBackupAction ? "Working..." : "Restore latest backup",
                    subtitle: "Imports missing records from your newest backup.",
                    icon: "arrow.clockwise.circle"
                ) {
                    guard !isRunningBackupAction else { return }
                    guard BackupExportService.shared.lastBackupDate() != nil else {
                        backupFeedback = BackupFeedback(
                            title: "No Backup Found",
                            message: "There isn’t a restorable backup yet."
                        )
                        return
                    }
                    showingRestoreConfirmation = true
                }
            }
        }
    }

    private var backupSectionSubtitle: String {
        BackupExportService.shared.isUsingICloud
            ? "Backup snapshots are saved to iCloud Drive automatically when you leave the app."
            : "Backup snapshots stay on this device and are removed if the app is deleted."
    }


    private var notificationsSection: some View {
        settingsGroupCard(title: "Notifications", subtitle: "Reminder permissions") {
            VStack(spacing: 0) {
                settingsActionRow(
                    title: "Open notification settings",
                    subtitle: "Enable permissions for reminders that need alerts.",
                    icon: "bell.badge"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var privacySection: some View {
        settingsGroupCard(title: "Privacy", subtitle: "Local-first by design") {
            VStack(spacing: 0) {
                settingsInfoRow(title: "Account", value: "Not required")
                settingsDivider()
                settingsInfoRow(
                    title: "Storage",
                    value: BackupExportService.shared.isUsingICloud ? "On device + iCloud backup snapshots" : "On device"
                )
                settingsDivider()
                settingsInfoRow(title: "VIN lookup", value: "Only when requested")
                settingsDivider()
                settingsInfoRow(title: "Ads", value: "None")
            }
        }
    }

    private var supportSection: some View {
        settingsGroupCard(title: "Support", subtitle: "Help and feedback") {
            VStack(spacing: 0) {
                settingsInfoRow(title: "Help", value: "Use the App Store support link for contact details.")
            }
        }
    }

    #if DEBUG
    private var developerSection: some View {
        settingsGroupCard(title: "Developer", subtitle: "Debug tools for local builds") {
            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Debug Pro Override",
                    subtitle: "Force premium access during development.",
                    isOn: Binding(get: {
                        entitlementStore.debugProOverride
                    }, set: { value in
                        entitlementStore.setDebugOverride(value)
                    })
                )

                settingsDivider()

                settingsActionRow(
                    title: "Generate full demo garage",
                    subtitle: "Replaces current data with a fully loaded demo set.",
                    icon: "wand.and.stars"
                ) {
                    PreviewData.generateFullDemoGarage(in: modelContext)
                    selectDemoVehicle(withVIN: PreviewData.fullDemoPrimaryVIN)
                    appState.refreshDataViews()
                    Haptics.success()
                }

                settingsDivider()

                settingsActionRow(
                    title: "Generate partial demo garage",
                    subtitle: "Replaces current data with a mixed-completeness demo set.",
                    icon: "wand.and.stars"
                ) {
                    PreviewData.generatePartialDemoGarage(in: modelContext)
                    selectDemoVehicle(withVIN: PreviewData.partialDemoPrimaryVIN)
                    appState.refreshDataViews()
                    Haptics.success()
                }
            }
        }
    }
    #endif

    private var aboutSection: some View {
        settingsGroupCard(title: "About", subtitle: "Build and library stats") {
            VStack(spacing: 0) {
                settingsInfoRow(title: "Version", value: appVersion)
                settingsDivider()
                settingsInfoRow(title: "Vehicles", value: "\(vehicles.count)")
                settingsDivider()
                settingsInfoRow(title: "Entries", value: "\(services.count)")
            }
        }
    }

    private var dangerZoneSection: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Danger Zone")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.red)

                    Text("Irreversible actions")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.15))

                            Image(systemName: "trash.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                        .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reset all data")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)

                            Text("Delete all vehicles, entries, and documents.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resetAllData() async {
        do {
            try await AppDataMaintenanceService.resetAllData(vehicles: vehicles, in: modelContext)
            appState.refreshDataViews()
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    @MainActor
    private func createBackupNow() async {
        guard !isRunningBackupAction else { return }
        isRunningBackupAction = true
        defer { isRunningBackupAction = false }

        do {
            try BackupExportService.shared.saveBackup(
                vehicles: vehicles,
                services: services,
                reminders: reminders,
                attachments: attachments,
                documents: documents,
                fuelEntries: fuelEntries
            )
            backupFeedback = BackupFeedback(
                title: "Backup Created",
                message: BackupExportService.shared.isUsingICloud
                    ? "A new backup snapshot was saved to iCloud Drive."
                    : "A new backup snapshot was saved on this device."
            )
            Haptics.success()
        } catch let error as BackupExportService.BackupError {
            backupFeedback = BackupFeedback(
                title: "No Data Yet",
                message: error.localizedDescription
            )
            Haptics.error()
        } catch {
            backupFeedback = BackupFeedback(
                title: "Backup Failed",
                message: "The backup couldn’t be created. Please try again."
            )
            Haptics.error()
        }
    }

    @MainActor
    private func restoreLatestBackup() async {
        guard !isRunningBackupAction else { return }
        isRunningBackupAction = true
        defer { isRunningBackupAction = false }

        do {
            let result = try BackupExportService.shared.importLatestBackup(into: modelContext)
            try await AppDataMaintenanceService.rescheduleReminderNotifications(in: modelContext)
            appState.refreshDataViews()
            backupFeedback = BackupFeedback(
                title: "Backup Restored",
                message: restoreSummary(for: result)
            )
            Haptics.success()
        } catch let error as BackupExportService.ImportError {
            backupFeedback = BackupFeedback(
                title: "Restore Failed",
                message: error.localizedDescription
            )
            Haptics.error()
        } catch {
            backupFeedback = BackupFeedback(
                title: "Restore Failed",
                message: "The latest backup couldn’t be restored. Please try again."
            )
            Haptics.error()
        }
    }

    private func restoreSummary(for result: BackupExportService.ImportResult) -> String {
        let importedRecords = result.vehiclesImported
            + result.servicesImported
            + result.remindersImported
            + result.attachmentsImported
            + result.documentsImported
            + result.fuelEntriesImported

        guard importedRecords > 0 else {
            return "No new records were imported because this backup was already fully present."
        }

        return "Imported \(result.vehiclesImported) vehicles, \(result.servicesImported) services, \(result.remindersImported) reminders, \(result.documentsImported) documents, and \(result.fuelEntriesImported) fuel entries."
    }

    private func selectDemoVehicle(withVIN vin: String) {
        let descriptor = FetchDescriptor<Vehicle>()
        guard let refreshedVehicles = try? modelContext.fetch(descriptor) else { return }
        appState.selectedVehicleID = refreshedVehicles.first(where: { $0.vin == vin })?.id
    }

    private func settingsGroupCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                content()
            }
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .overlay(AppTheme.separator)
            .padding(.leading, settingsRowHorizontalPadding)
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        settingsAlignedRow {
            settingsRowLabel(title: title, subtitle: subtitle)
        } trailing: {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
    }

    private func settingsMenuRow<Content: View>(
        title: String,
        subtitle: String?,
        value: String,
        @ViewBuilder menu: () -> Content
    ) -> some View {
        settingsAlignedRow {
            settingsRowLabel(title: title, subtitle: subtitle)
        } trailing: {
            Menu {
                menu()
            } label: {
                settingsValuePill(value)
            }
        }
    }

    private func settingsActionRow(
        title: String,
        subtitle: String? = nil,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceSecondary)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    private func settingsInfoRow(
        title: String,
        value: String,
        accent: Color = AppTheme.primaryText
    ) -> some View {
        settingsAlignedRow {
            settingsRowLabel(title: title, titleColor: AppTheme.secondaryText)
        } trailing: {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.trailing)
        }
    }

    private func settingsCompactNote(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: settingsInfoIconWidth, alignment: .center)
                .padding(.top, 1)

            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, settingsRowHorizontalPadding)
        .padding(.vertical, 10)
    }

    private func settingsProgressRow(title: String, subtitle: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func settingsValuePill(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.surfaceSecondary)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }
        )
    }

    private func settingsAlignedRow<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: settingsRowSpacing) {
            leading()
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, settingsRowHorizontalPadding)
        .padding(.vertical, settingsRowVerticalPadding)
    }

    private func settingsRowLabel(
        title: String,
        subtitle: String? = nil,
        titleColor: Color = AppTheme.primaryText
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(titleColor)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var distanceUnitBinding: Binding<DistanceUnit> {
        Binding(
            get: {
                DistanceUnit(rawValue: distanceUnitRaw) ?? UnitSettings.suggestedProfile().distanceUnit
            },
            set: { distanceUnitRaw = $0.rawValue }
        )
    }

    private var fuelVolumeUnitBinding: Binding<FuelVolumeUnit> {
        Binding(
            get: {
                FuelVolumeUnit(rawValue: fuelVolumeUnitRaw) ?? UnitSettings.suggestedProfile().fuelVolumeUnit
            },
            set: { fuelVolumeUnitRaw = $0.rawValue }
        )
    }

    private var consumptionUnitBinding: Binding<ConsumptionUnit> {
        Binding(
            get: {
                ConsumptionUnit(rawValue: consumptionUnitRaw) ?? UnitSettings.suggestedProfile().consumptionUnit
            },
            set: { consumptionUnitRaw = $0.rawValue }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

}
