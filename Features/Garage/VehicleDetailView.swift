import SwiftUI

struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @EnvironmentObject private var appState: AppState

    let vehicle: Vehicle

    @State private var showingEdit = false
    @State private var showingServiceForm = false
    @State private var showingOCRServiceForm = false
    @State private var showingReminderForm = false
    @State private var showingDocumentComposer = false
    @State private var showingDocuments = false
    @State private var selectedReminder: ReminderItem?
    @State private var selectedServiceEntry: ServiceEntry?
    @State private var pendingServiceDraft: ScannedReceiptDraft?
    @State private var showingAnalytics = false
    @State private var showingFuelTracking = false
    @State private var showingDeleteConfirmation = false
    @State private var exportURL: URL?

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header Image
                    ZStack(alignment: .top) {
                        GeometryReader { proxy in
                            let minY = proxy.frame(in: .global).minY
                            let height = max(224, 224 + (minY > 0 ? minY : 0))
                            let offset = minY > 0 ? -minY : 0
                            
                            ZStack {
                                if let reference = vehicle.coverImageReference,
                                   let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    LinearGradient(colors: [AppTheme.surfaceSecondary, AppTheme.surface], startPoint: .top, endPoint: .bottom)
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(AppTheme.tertiaryText.opacity(0.42))
                                }
                            }
                            .frame(width: proxy.size.width, height: height)
                            .clipped()
                            .offset(y: offset)
                        }
                        .frame(height: 224)
                    }

                    VStack(spacing: 18) {
                        // Vehicle Info Card
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(vehicle.make) \(vehicle.model)")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .padding(.bottom, 2)

                                Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .padding(.bottom, 10)

                                HStack(spacing: 8) {
                                    if !vehicle.licensePlate.isEmpty {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Color(hex: "CBD5E1"))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.surfaceSecondary))
                                    }
                                    if !vehicle.vin.isEmpty {
                                        Text("VIN: \(vehicle.vin)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.surfaceSecondary))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .offset(y: -24)
                        .padding(.horizontal, 24)
                        .padding(.bottom, -24)

                        // Stats
                        HStack(spacing: 12) {
                            summaryActionCard(
                                title: "Services",
                                value: "\(vehicle.serviceEntries.count)",
                                icon: "doc.text.fill",
                                helperText: "Open history"
                            ) {
                                openServiceHistory()
                            }

                            summaryActionCard(
                                title: "Total Cost",
                                value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode),
                                icon: "dollarsign.circle.fill",
                                helperText: "View insights",
                                trailingBadge: entitlementStore.canSeeAnalytics() ? nil : "Pro"
                            ) {
                                openAnalytics()
                            }
                        }
                        .padding(.horizontal, 24)

                        vehicleSummarySection
                            .padding(.horizontal, 24)

                        quickActions
                            .padding(.horizontal, 24)
                            .padding(.top, 2)

                        // Reminders
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Reminders")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            SurfaceCard {
                                if vehicle.sortedReminders.isEmpty {
                                    Text("No reminders yet.")
                                        .foregroundStyle(AppTheme.secondaryText)
                                } else {
                                    ForEach(vehicle.sortedReminders.prefix(3)) { reminder in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(reminder.title)
                                                    .foregroundStyle(AppTheme.primaryText)
                                                Text(reminder.dateDue.map(AppFormatters.mediumDate.string) ?? reminder.mileageDue.map(AppFormatters.mileage) ?? "Custom")
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.secondaryText)
                                            }
                                            Spacer()
                                            ReminderBadge(status: reminder.status(for: vehicle))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Fuel section
                        fuelSection.padding(.horizontal, 24)

                        // Service History
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center) {
                                Text("Service History")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                Button {
                                    openServiceHistory()
                                } label: {
                                    Text("See all")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }

                            Text("\(vehicle.serviceEntries.count) \(vehicle.serviceEntries.count == 1 ? "record" : "records") keep your ownership history easy to review.")
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.secondaryText)

                            if vehicle.sortedServices.isEmpty {
                                SurfaceCard(padding: 32) { // p-8
                                    VStack(spacing: 0) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 48)) // w-12 h-12
                                            .foregroundStyle(AppTheme.tertiaryText)
                                            .padding(.bottom, 12) // mb-3
                                        Text("No service records yet")
                                            .font(.system(size: 16))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .padding(.bottom, 16) // mb-4
                                        Button("Add First Service") {
                                            showingServiceForm = true
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .frame(maxWidth: 200)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(vehicle.sortedServices.prefix(3)) { entry in
                                        NavigationLink {
                                            ServiceDetailView(entry: entry)
                                        } label: {
                                            SurfaceCard(padding: 14) {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    HStack(alignment: .top) {
                                                        VStack(alignment: .leading, spacing: 5) {
                                                            Text(entry.displayTitle)
                                                                .font(.system(size: 15, weight: .semibold))
                                                                .foregroundStyle(AppTheme.primaryText)
                                                            HStack(spacing: 6) {
                                                                Image(systemName: "calendar")
                                                                    .font(.system(size: 12))
                                                                Text(AppFormatters.mediumDate.string(from: entry.date))
                                                                    .font(.system(size: 13.5, weight: .medium))
                                                            }
                                                            .foregroundStyle(AppTheme.secondaryText)
                                                        }
                                                        Spacer()
                                                        Text(AppFormatters.currency(entry.price, code: entry.currencyCode))
                                                            .font(.system(size: 15, weight: .semibold))
                                                            .foregroundStyle(AppTheme.primaryText)
                                                    }
                                                    .padding(.bottom, 8)

                                                    HStack(spacing: 6) {
                                                        Image(systemName: "gauge.with.dots.needle.33percent")
                                                            .font(.system(size: 12))
                                                        Text("\(entry.mileage) km")
                                                            .font(.system(size: 13.5, weight: .medium))
                                                    }
                                                    .foregroundStyle(AppTheme.secondaryText)

                                                    if !entry.notes.isEmpty {
                                                        Text(entry.notes)
                                                            .font(.system(size: 13.5))
                                                            .foregroundStyle(AppTheme.tertiaryText)
                                                            .lineLimit(1)
                                                            .padding(.top, 5)
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                        Spacer().frame(height: 176)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            // Floating Navigation Bar
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40) // w-10 h-10
                            .background(.ultraThinMaterial, in: Circle())
                            .background(Circle().fill(AppTheme.elevatedBackground.opacity(0.8)))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            showingEdit = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40) // w-10 h-10
                                .background(.ultraThinMaterial, in: Circle())
                                .background(Circle().fill(AppTheme.elevatedBackground.opacity(0.8)))
                        }
                        
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40) // w-10 h-10
                                .background(.ultraThinMaterial, in: Circle())
                                .background(Circle().fill(AppTheme.elevatedBackground.opacity(0.8)))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48) // top-12 roughly matches safe area top + some padding
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            appState.selectedVehicleID = vehicle.id
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                VehicleFormView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingServiceForm) {
            NavigationStack {
                ServiceEntryFormView(vehicle: vehicle)
            }
        }
        .sheet(item: $selectedServiceEntry) { entry in
            NavigationStack {
                ServiceDetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showingOCRServiceForm) {
            NavigationStack {
                ServiceEntryFormView(vehicle: vehicle, autoStartOCR: true)
            }
        }
        .sheet(isPresented: $showingReminderForm) {
            NavigationStack {
                ReminderFormView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingDocuments) {
            NavigationStack {
                DocumentsView()
            }
        }
        .sheet(item: $selectedReminder) { reminder in
            NavigationStack {
                ReminderFormView(vehicle: vehicle, reminder: reminder)
            }
        }
        .sheet(item: $pendingServiceDraft) { draft in
            NavigationStack {
                ServiceEntryFormView(vehicle: vehicle, ocrDraft: draft)
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            NavigationStack {
                VehicleAnalyticsView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingFuelTracking) {
            NavigationStack {
                FuelTrackingView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                VehicleFormView(vehicle: vehicle)
            }
        }
        .sheet(item: Binding(get: {
            exportURL.map(PreviewURL.init(url:))
        }, set: { item in
            exportURL = item?.url
        })) { item in
            ActivityView(activityItems: [item.url])
        }
        .confirmationDialog("Delete this vehicle?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteVehicle()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private let quickActionColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private let summaryActionColumns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3)

    private var quickActions: some View {
        LazyVGrid(columns: quickActionColumns, spacing: 10) {
            quickActionButton(title: "Reminder", icon: "bell.fill") {
                showingReminderForm = true
            }
            quickActionButton(title: "Fuel", icon: "fuelpump.fill") {
                if entitlementStore.canUseFuelTracking() {
                    showingFuelTracking = true
                } else {
                    paywallCoordinator.present(.fuelTracking)
                }
            }
            quickActionButton(title: "Add Service", icon: "wrench.and.screwdriver.fill") {
                showingServiceForm = true
            }
            Menu {
                Button {
                    exportPDF()
                } label: {
                    Label("Service Passport (PDF)", systemImage: "doc.richtext.fill")
                }
                Button {
                    exportResaleReport()
                } label: {
                    Label("Resale Report (PDF)", systemImage: "tag.fill")
                }
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV Data", systemImage: "tablecells.fill")
                }
            } label: {
                quickActionLabel(title: "Export", icon: "square.and.arrow.up.fill")
            }
        }
    }

    private var fuelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Fuel Log")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button {
                    if entitlementStore.canUseFuelTracking() {
                        showingFuelTracking = true
                    } else {
                        paywallCoordinator.present(.fuelTracking)
                    }
                } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if vehicle.fuelEntries.isEmpty {
                SurfaceCard(padding: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "fuelpump")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.tertiaryText)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No fuel entries yet")
                                .foregroundStyle(AppTheme.secondaryText)
                            Button("Start tracking") {
                                if entitlementStore.canUseFuelTracking() {
                                    showingFuelTracking = true
                                } else {
                                    paywallCoordinator.present(.fuelTracking)
                                }
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                    }
                }
            } else {
                SurfaceCard(padding: 16) {
                    VStack(spacing: 12) {
                        HStack {
                            statPill(title: "Total Liters", value: String(format: "%.1f L", vehicle.totalFuelLiters))
                            Spacer()
                            statPill(title: "Fuel Cost", value: AppFormatters.currency(vehicle.totalFuelCost, code: vehicle.currencyCode))
                        }
                        Divider().background(AppTheme.separator)
                        if let latest = vehicle.sortedFuelEntries.first {
                            HStack {
                                Image(systemName: "fuelpump.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .font(.system(size: 14))
                                Text("Last fill-up: \(AppFormatters.mediumDate.string(from: latest.date))")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Spacer()
                                Text(String(format: "%.2f L", latest.liters))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func quickActionLabel(title: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(AppTheme.primaryText)
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
        )
    }

    private var vehicleSummarySection: some View {
        LazyVGrid(columns: summaryActionColumns, spacing: 10) {
            summaryActionTile(title: "Next due", value: nextDueText, icon: "bell.badge.fill", highlight: nextDueIsUrgent) {
                if let reminder = vehicle.nextDueReminder {
                    selectedReminder = reminder
                } else {
                    showingReminderForm = true
                }
            }

            summaryActionTile(title: "Last service", value: lastServiceText, icon: "wrench.and.screwdriver.fill", highlight: false) {
                if let service = vehicle.latestService {
                    selectedServiceEntry = service
                } else {
                    showingServiceForm = true
                }
            }

            summaryActionTile(title: "Docs", value: documentsSummaryText, icon: "doc.fill", highlight: vehicle.documentsCount > 0) {
                openDocuments()
            }
        }
    }

    private func summaryActionTile(title: String, value: String, icon: String, highlight: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SurfaceCard(padding: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(highlight ? AppTheme.accent : AppTheme.secondaryText)
                        Text(title)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text(value)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.84)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 60, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private var nextDueText: String {
        guard let reminder = vehicle.nextDueReminder else { return "No active reminders" }

        switch reminder.status(for: vehicle) {
        case .overdue:
            if let dateDue = reminder.dateDue {
                return "Overdue • \(AppFormatters.mediumDate.string(from: dateDue))"
            }
            if let mileageDue = reminder.mileageDue {
                return "Overdue • \(AppFormatters.mileage(mileageDue))"
            }
            return "Overdue • \(reminder.title)"
        case .dueSoon:
            if let dateDue = reminder.dateDue {
                return "Due soon • \(AppFormatters.mediumDate.string(from: dateDue))"
            }
            if let mileageDue = reminder.mileageDue {
                return "Due soon • \(AppFormatters.mileage(mileageDue))"
            }
            return "Due soon • \(reminder.title)"
        case .upcoming:
            if let dateDue = reminder.dateDue {
                return "\(AppFormatters.mediumDate.string(from: dateDue))"
            }
            if let mileageDue = reminder.mileageDue {
                return "\(AppFormatters.mileage(mileageDue))"
            }
            return reminder.title
        case .disabled:
            return "Reminder paused"
        }
    }

    private var nextDueIsUrgent: Bool {
        guard let reminder = vehicle.nextDueReminder else { return false }
        return reminder.status(for: vehicle) != .upcoming
    }

    private var lastServiceText: String {
        guard let service = vehicle.latestService else { return "No service yet" }
        return AppFormatters.mediumDate.string(from: service.date)
    }

    private var documentsSummaryText: String {
        let count = vehicle.documentsCount
        return count == 1 ? "1 file" : "\(count) files"
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func summaryActionCard(title: String, value: String, icon: String, helperText: String, trailingBadge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SurfaceCard(padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.accent)
                        Text(title)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        if let trailingBadge {
                            Text(trailingBadge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AppTheme.surfaceSecondary))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(helperText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func openDocuments() {
        appState.selectedVehicleID = vehicle.id
        showingDocuments = true
    }

    private func openServiceHistory() {
        appState.selectedVehicleID = vehicle.id
        appState.timelineCategory = "All"
        appState.selectedTab = .timeline
        dismiss()
    }

    private func openAnalytics() {
        if entitlementStore.canSeeAnalytics() {
            showingAnalytics = true
        } else {
            paywallCoordinator.present(.analytics)
        }
    }

    private func exportPDF() {
        do {
            exportURL = try PDFExportService.shared.exportPassport(for: vehicle)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    private func exportResaleReport() {
        guard entitlementStore.canExportPDF() else {
            paywallCoordinator.present(.exportPDF)
            return
        }
        do {
            exportURL = try PDFExportService.shared.exportResaleReport(for: vehicle)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    private func exportCSV() {
        guard entitlementStore.canExportPDF() else {
            paywallCoordinator.present(.exportPDF)
            return
        }

        do {
            exportURL = try PDFExportService.shared.exportCSV(for: vehicle)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    private func deleteVehicle() {
        for attachment in vehicle.attachments {
            Task {
                await AttachmentStorageService.shared.delete(reference: attachment.storageReference)
                await AttachmentStorageService.shared.delete(reference: attachment.thumbnailReference)
            }
        }
        modelContext.delete(vehicle)
        try? modelContext.save()
        dismiss()
    }
}
