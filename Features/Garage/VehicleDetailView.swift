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
    @State private var showingReminderForm = false
    @State private var showingDocumentComposer = false
    @State private var showingAnalytics = false
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
                                    Image(systemName: "calendar")
                                        .font(.system(size: 64))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                            }
                            .frame(width: proxy.size.width, height: height)
                            .clipped()
                            .offset(y: offset)
                        }
                        .frame(height: 224)
                    }

                    VStack(spacing: 24) {
                        // Vehicle Info Card
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(vehicle.make) \(vehicle.model)")
                                    .font(.system(size: 24, weight: .bold)) // text-2xl font-bold
                                    .foregroundStyle(AppTheme.primaryText)
                                    .padding(.bottom, 8) // mb-2
                                
                                Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                                    .font(.system(size: 16)) // text-base
                                    .foregroundStyle(AppTheme.secondaryText) // text-slate-400
                                    .padding(.bottom, 16) // mb-4
                                
                                HStack(spacing: 12) { // gap-3
                                    if !vehicle.licensePlate.isEmpty {
                                        Text(vehicle.licensePlate)
                                            .font(.system(size: 12, design: .monospaced)) // text-xs font-mono
                                            .foregroundStyle(Color(hex: "CBD5E1")) // text-slate-300
                                            .padding(.horizontal, 12) // px-3
                                            .padding(.vertical, 6) // py-1.5
                                            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceSecondary))
                                    }
                                    if !vehicle.vin.isEmpty {
                                        Text("VIN: \(vehicle.vin)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(Color(hex: "CBD5E1"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceSecondary))
                                    }
                                }
                            }
                        }
                        .offset(y: -24)
                        .padding(.horizontal, 24)
                        .padding(.bottom, -24)

                        // Stats
                        HStack(spacing: 12) { // gap-3
                            Button {
                                appState.selectedVehicleID = vehicle.id
                                appState.timelineCategory = "All"
                                appState.selectedTab = .timeline
                                dismiss() // dismiss the current detail view so the root tab takes over properly, or just let the tab switch handle it
                            } label: {
                                SurfaceCard(padding: 16) {
                                    VStack(alignment: .leading, spacing: 8) { // mb-2
                                        HStack(spacing: 8) { // gap-2
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 16)) // w-4 h-4
                                                .foregroundStyle(AppTheme.accent) // text-orange-500
                                            Text("Services")
                                                .font(.system(size: 12)) // text-xs
                                                .foregroundStyle(AppTheme.secondaryText) // text-slate-400
                                        }
                                        Text("\(vehicle.serviceEntries.count)")
                                            .font(.system(size: 24, weight: .bold)) // text-2xl font-bold
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                if entitlementStore.canSeeAnalytics() {
                                    showingAnalytics = true
                                } else {
                                    paywallCoordinator.present(.analytics)
                                }
                            } label: {
                                SurfaceCard(padding: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(AppTheme.accent)
                                            Text("Total Cost")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        Text(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)

                        quickActions.padding(.horizontal, 24)

                        // Service History
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Service History")
                                    .font(.system(size: 18, weight: .semibold)) // text-lg font-semibold
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                Button {
                                    showingServiceForm = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16)) // w-4 h-4
                                        Text("Add Service")
                                            .font(.system(size: 14, weight: .medium)) // text-sm
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.accent))
                                }
                            }

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
                                        .frame(maxWidth: 200) // Keep it somewhat constrained to look nice
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                VStack(spacing: 12) { // space-y-3
                                    ForEach(vehicle.sortedServices.prefix(5)) { entry in
                                        NavigationLink {
                                            ServiceDetailView(entry: entry)
                                        } label: {
                                            SurfaceCard(padding: 16) {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    HStack(alignment: .top) {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(entry.displayTitle)
                                                                .font(.system(size: 16, weight: .semibold)) // font-semibold
                                                                .foregroundStyle(AppTheme.primaryText)
                                                            
                                                            HStack(spacing: 8) { // gap-2
                                                                Image(systemName: "calendar")
                                                                    .font(.system(size: 14)) // w-3.5 h-3.5 approx
                                                                Text(AppFormatters.mediumDate.string(from: entry.date))
                                                            }
                                                            .font(.system(size: 14)) // text-sm
                                                            .foregroundStyle(AppTheme.secondaryText)
                                                        }
                                                        Spacer()
                                                        Text(AppFormatters.currency(entry.price, code: entry.currencyCode))
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundStyle(AppTheme.primaryText)
                                                    }
                                                    .padding(.bottom, 12) // mb-3
                                                    
                                                    HStack(spacing: 8) { // gap-2
                                                        Image(systemName: "gauge.with.dots.needle.33percent")
                                                            .font(.system(size: 14)) // w-3.5 h-3.5
                                                        Text("\(entry.mileage) km")
                                                    }
                                                    .font(.system(size: 14)) // text-sm
                                                    .foregroundStyle(AppTheme.secondaryText)
                                                    
                                                    if !entry.notes.isEmpty {
                                                        Text(entry.notes)
                                                            .font(.system(size: 14)) // text-sm
                                                            .foregroundStyle(AppTheme.tertiaryText)
                                                            .lineLimit(1)
                                                            .padding(.top, 8) // mt-2
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
                        
                        // Reminders
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Reminders")
                                .font(.headline.weight(.semibold))
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

                        // Documents
                        if !vehicle.sortedAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Documents")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                SurfaceCard {
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(vehicle.sortedAttachments.prefix(4)) { attachment in
                                            AttachmentThumbnailView(attachment: attachment)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer().frame(height: 100)
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
        .sheet(isPresented: $showingReminderForm) {
            NavigationStack {
                ReminderFormView(vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingDocumentComposer) {
            NavigationStack {
                DocumentComposerSheet(preselectedVehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            NavigationStack {
                VehicleAnalyticsView(vehicle: vehicle)
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

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(title: "Reminder", icon: "bell.fill") {
                showingReminderForm = true
            }
            quickActionButton(title: "Add Document", icon: "doc.fill") {
                if entitlementStore.canUseDocumentVault() {
                    showingDocumentComposer = true
                } else {
                    paywallCoordinator.present(.documentVault)
                }
            }
            Menu {
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF Passport", systemImage: "doc.richtext.fill")
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

    private func quickActionLabel(title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(AppTheme.primaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
        )
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func exportPDF() {
        guard entitlementStore.canExportPDF() else {
            paywallCoordinator.present(.exportPDF)
            return
        }

        do {
            exportURL = try PDFExportService.shared.exportPassport(for: vehicle)
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