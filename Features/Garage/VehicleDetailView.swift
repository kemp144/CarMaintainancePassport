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
                            let height = max(186, 186 + (minY > 0 ? minY : 0))
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
                                        .font(.system(size: 42))
                                        .foregroundStyle(AppTheme.tertiaryText.opacity(0.42))
                                }
                            }
                            .frame(width: proxy.size.width, height: height)
                            .clipped()
                            .offset(y: offset)
                        }
                        .frame(height: 186)
                    }

                    VStack(spacing: 14) {
                        // Vehicle Info Card
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(vehicle.make) \(vehicle.model)")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.86)
                                    .padding(.bottom, 4)

                                Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .padding(.bottom, 6)

                                Text(ownershipSnapshotText)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                    .padding(.bottom, 10)

                                HStack(spacing: 8) {
                                    if !vehicle.licensePlate.isEmpty {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.surfaceSecondary.opacity(0.75)))
                                    }
                                    if !vehicle.vin.isEmpty {
                                        Text("VIN: \(vehicle.vin)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.surfaceSecondary.opacity(0.75)))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .offset(y: -18)
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.bottom, -18)

                        // Stats
                        HStack(spacing: 12) {
                            summaryActionCard(
                                title: "Services",
                                value: "\(vehicle.serviceEntries.count)",
                                icon: "doc.text.fill",
                                helperText: "View history"
                            ) {
                                openServiceHistory()
                            }

                            summaryActionCard(
                                title: "Total Cost",
                                value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode),
                                icon: "dollarsign.circle.fill",
                                helperText: "See insights",
                                trailingBadge: entitlementStore.canSeeAnalytics() ? nil : "Pro"
                            ) {
                                openAnalytics()
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)

                        vehicleSummarySection
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)

                        quickActions
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)
                            .padding(.top, 10)

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
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(reminderRowTitle(for: reminder))
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.primaryText)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.86)
                                                Text(reminderRowSubtitle(for: reminder))
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.secondaryText)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            Spacer()
                                            ReminderBadge(status: reminder.status(for: vehicle))
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, 6)

                        // Fuel section
                        fuelSection.padding(.horizontal, AppTheme.Spacing.pageEdge)

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
                                    Text("View history")
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
                                                        Text(AppFormatters.mileage(entry.mileage))
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
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, 4)

                        Spacer().frame(height: 120)
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
                .padding(.horizontal, AppTheme.Spacing.pageEdge)
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
    private var quickActions: some View {
        LazyVGrid(columns: quickActionColumns, spacing: 10) {
            quickActionButton(title: "Add Service", icon: "wrench.and.screwdriver.fill", priority: .primary) {
                showingServiceForm = true
            }
            quickActionButton(title: "Log Fuel", icon: "fuelpump.fill", priority: .secondary) {
                showingFuelTracking = true
            }
            quickActionButton(title: "Reminder", icon: "bell.fill", priority: .tertiary) {
                showingReminderForm = true
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
                quickActionLabel(title: "Export", icon: "square.and.arrow.up.fill", priority: .tertiary)
            }
        }
    }

    private var fuelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Fuel Log")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if !entitlementStore.canUseDetailedFuelTracking() {
                    Text("Pro")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                }

                Spacer()
                Button {
                    showingFuelTracking = true
                } label: {
                    Text(entitlementStore.canUseDetailedFuelTracking() ? "See all" : "Open log")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(spacing: 14) {
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
                                    showingFuelTracking = true
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.accent)
                            }
                            Spacer()
                        }
                    }
                } else {
                    let fuelAnalysis = FuelAnalyticsService.analysis(for: vehicle.fuelEntries)

                    SurfaceCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fuel Snapshot")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(entitlementStore.canUseDetailedFuelTracking() ? "Detailed overview" : "Basic totals and recent activity")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                                Spacer()
                                Image(systemName: "fuelpump.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(8)
                                    .background(Circle().fill(AppTheme.surfaceSecondary))
                            }

                            HStack {
                                statPill(title: "Total Fuel", value: AppFormatters.fuelVolume(fuelAnalysis.insights.totalLiters))
                                Spacer()
                                statPill(title: "Fuel Cost", value: AppFormatters.currency(fuelAnalysis.insights.totalCost, code: vehicle.currencyCode))
                            }

                            Divider().background(AppTheme.separator)

                            if let latest = fuelAnalysis.insights.lastFillUp {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Last fill-up")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.tertiaryText)
                                        Text(AppFormatters.mediumDate.string(from: latest.date))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                    Spacer()
                                    Text(latest.liters.map { AppFormatters.fuelVolume($0) } ?? "—")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                            }

                            if entitlementStore.canUseDetailedFuelTracking() {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Last valid tank")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.tertiaryText)
                                        Text(
                                            fuelAnalysis.insights.lastValidConsumption.value
                                                .map { AppFormatters.consumption($0) }
                                            ?? "Not enough data yet"
                                        )
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    }

                                    Spacer()

                                    if let note = fuelAnalysis.insights.lastValidConsumption.note {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            } else {
                                Divider().background(AppTheme.separator)

                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text("Detailed Fuel Tracking")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppTheme.primaryText)

                                            Text("Pro")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(AppTheme.accent)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                                        }

                                        Text("Consumption, charts, filters, OCR receipts, export, and advanced analytics.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }

                                    Spacer(minLength: 10)

                                    Button("Upgrade") {
                                        paywallCoordinator.present(.fuelTracking)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                }
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

    private enum QuickActionPriority {
        case primary
        case secondary
        case tertiary
    }

    private func quickActionLabel(title: String, icon: String, priority: QuickActionPriority, isLocked: Bool = false) -> some View {
        let background: Color
        let foreground: Color
        let iconColor: Color

        switch priority {
        case .primary:
            background = AppTheme.accent.opacity(0.16)
            foreground = AppTheme.primaryText
            iconColor = AppTheme.accent
        case .secondary:
            background = AppTheme.surfaceSecondary
            foreground = AppTheme.primaryText
            iconColor = AppTheme.accent
        case .tertiary:
            background = AppTheme.surfaceSecondary.opacity(0.75)
            foreground = AppTheme.secondaryText
            iconColor = AppTheme.secondaryText
        }

        return VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .offset(x: 8, y: -4)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .foregroundStyle(foreground)
        }
        .opacity(isLocked ? 0.6 : 1.0)
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
        )
    }

    private var vehicleSummarySection: some View {
        HStack(alignment: .top, spacing: 12) {
            nextDueSummaryCard

            VStack(spacing: 8) {
                summaryActionTile(title: "Last service", value: lastServiceText, icon: "wrench.and.screwdriver.fill", highlight: false, compact: true) {
                    if let service = vehicle.latestService {
                        selectedServiceEntry = service
                    } else {
                        showingServiceForm = true
                    }
                }

                summaryActionTile(title: "Documents", value: documentsSummaryText, icon: "doc.fill", highlight: vehicle.documentsCount > 0, compact: true) {
                    openDocuments()
                }
            }
            .frame(maxWidth: 124)
        }
    }

    private var nextDueSummaryCard: some View {
        Button {
            if let reminder = nextDueReminder {
                selectedReminder = reminder
            } else {
                showingReminderForm = true
            }
        } label: {
            SurfaceCard(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(nextDueAccentColor)

                        Text("Next due")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)

                        Spacer(minLength: 0)

                        if let reminder = nextDueReminder {
                            let status = reminder.status(for: vehicle)
                            if status != .upcoming {
                                ReminderBadge(status: status)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text(nextDuePrimaryText)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(nextDueAccentColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if let nextDueSecondaryText {
                        Text(nextDueSecondaryText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private func summaryActionTile(title: String, value: String, icon: String, highlight: Bool, compact: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SurfaceCard(padding: compact ? 8 : 10) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: compact ? 10 : 11, weight: .semibold))
                            .foregroundStyle(highlight ? AppTheme.accent : AppTheme.secondaryText)
                        Text(title)
                            .font(.system(size: compact ? 10 : 10.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: compact ? 8.5 : 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text(value)
                        .font(.system(size: compact ? 12 : 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: compact ? 48 : 60, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private var nextDueReminder: ReminderItem? {
        vehicle.nextDueReminder
    }

    private var nextDuePrimaryText: String {
        guard let reminder = nextDueReminder else { return "No active reminders" }

        if reminder.status(for: vehicle) == .disabled {
            return "Reminder paused"
        }

        if let dateDue = reminder.dateDue {
            let days = daysUntil(dateDue)
            if days < 0 {
                return "Overdue by \(abs(days)) \(abs(days) == 1 ? "day" : "days")"
            }
            if days == 0 {
                return "Due today"
            }
            return "Due in \(days) \(days == 1 ? "day" : "days")"
        }

        if let mileageDue = reminder.mileageDue {
            if vehicle.currentMileage >= mileageDue {
                return "Over by \(AppFormatters.mileage(vehicle.currentMileage - mileageDue))"
            }
            return "Due at \(AppFormatters.mileage(mileageDue))"
        }

        return reminder.title
    }

    private var nextDueSecondaryText: String? {
        guard let reminder = nextDueReminder else {
            return "Add a reminder for service, tires, or registration."
        }

        if reminder.status(for: vehicle) == .disabled {
            return "Tap to review this reminder."
        }

        if let dateDue = reminder.dateDue {
            return AppFormatters.mediumDate.string(from: dateDue)
        }

        if let mileageDue = reminder.mileageDue {
            let remaining = mileageDue - vehicle.currentMileage
            if remaining <= 0 {
                return "Over by \(AppFormatters.mileage(abs(remaining)))"
            }
            return "\(AppFormatters.mileage(remaining)) remaining"
        }

        return reminder.notes.isEmpty ? "Custom reminder" : reminder.notes
    }

    private var nextDueAccentColor: Color {
        guard let reminder = nextDueReminder else { return AppTheme.secondaryText }

        switch reminder.status(for: vehicle) {
        case .disabled:
            return AppTheme.secondaryText
        case .overdue:
            return Color.red
        case .dueSoon:
            if let dateDue = reminder.dateDue {
                return daysUntil(dateDue) <= 7 ? Color.red : Color.orange
            }
            return Color.orange
        case .upcoming:
            if let dateDue = reminder.dateDue {
                let days = daysUntil(dateDue)
                if days <= 7 { return Color.red }
                if days <= 30 { return Color.orange }
            }
            return AppTheme.secondaryText
        }
    }

    private var lastServiceText: String {
        guard let service = vehicle.latestService else { return "No service yet" }
        return AppFormatters.mediumDate.string(from: service.date)
    }

    private var documentsSummaryText: String {
        let count = vehicle.documentsCount
        return count == 1 ? "1 document" : "\(count) documents"
    }

    private var ownershipSnapshotText: String {
        let total = AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode)
        let serviceCount = vehicle.serviceEntries.count
        let serviceText = serviceCount == 1 ? "1 service" : "\(serviceCount) services"

        if let lastDate = vehicle.latestServiceDate {
            return "\(total) total · \(serviceText) · Last service \(AppFormatters.monthYear.string(from: lastDate))"
        }

        return "\(total) total · \(serviceText) · No service history yet"
    }

    private func reminderRowTitle(for reminder: ReminderItem) -> String {
        let baseTitle: String
        if reminder.type == .custom {
            baseTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            baseTitle = reminder.type.title
        }
        return "\(baseTitle) · \(vehicle.model)"
    }

    private func reminderRowSubtitle(for reminder: ReminderItem) -> String {
        if let dateDue = reminder.dateDue {
            return AppFormatters.mediumDate.string(from: dateDue)
        }
        if let mileageDue = reminder.mileageDue {
            return "Due at \(AppFormatters.mileage(mileageDue))"
        }
        return reminder.notes.isEmpty ? "Custom reminder" : reminder.notes
    }

    private func daysUntil(_ dateDue: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let dueDate = calendar.startOfDay(for: dateDue)
        return calendar.dateComponents([.day], from: start, to: dueDate).day ?? 0
    }

    private func quickActionButton(title: String, icon: String, priority: QuickActionPriority = .tertiary, isLocked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, icon: icon, priority: priority, isLocked: isLocked)
        }
        .buttonStyle(.plain)
    }

    private func summaryActionCard(title: String, value: String, icon: String, helperText: String, trailingBadge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SurfaceCard(padding: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.accent)
                        Text(title)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        Text(helperText)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if let trailingBadge {
                            Text(trailingBadge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
