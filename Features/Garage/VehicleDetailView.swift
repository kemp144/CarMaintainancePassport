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
    @State private var showingDeleteConfirmation = false
    @State private var exportURL: URL?

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VehicleHeroCard(vehicle: vehicle)

                    quickActions

                    HStack(spacing: 12) {
                        StatCard(title: "Total Spent", value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode), footnote: "All recorded entries")
                        StatCard(title: "This Year", value: AppFormatters.currency(vehicle.spentThisYear, code: vehicle.currencyCode), footnote: vehicle.highestSpendingCategory()?.title)
                    }

                    HStack(spacing: 12) {
                        StatCard(title: "Entries", value: "\(vehicle.serviceEntries.count)", footnote: vehicle.latestService.map { AppFormatters.mediumDate.string(from: $0.date) } ?? "No services yet")
                        StatCard(title: "Documents", value: "\(vehicle.attachments.count)", footnote: vehicle.nextActiveReminder()?.title ?? "No active reminder")
                    }

                    if !vehicle.sortedServices.isEmpty {
                        SurfaceCard {
                            PremiumSectionHeader(title: "Recent Service", subtitle: "Latest maintenance and repairs", trailingTitle: "See all") {}
                            ForEach(vehicle.sortedServices.prefix(3)) { entry in
                                NavigationLink {
                                    ServiceDetailView(entry: entry)
                                } label: {
                                    HStack {
                                        Label(entry.displayTitle, systemImage: entry.serviceType.icon)
                                            .foregroundStyle(AppTheme.primaryText)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(AppFormatters.currency(entry.price, code: entry.currencyCode))
                                                .foregroundStyle(AppTheme.accentSecondary)
                                            Text(AppFormatters.mediumDate.string(from: entry.date))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        EmptyStateCard(icon: "wrench.and.screwdriver.fill", title: "No service history yet", message: "Log the first service entry to start the passport timeline and cost overview.", actionTitle: "Add Service") {
                            showingServiceForm = true
                        }
                    }

                    SurfaceCard {
                        PremiumSectionHeader(title: "Reminders", subtitle: "What is due next")
                        if vehicle.sortedReminders.isEmpty {
                            Text("No reminders yet. Add one for inspections, seasonal tires or the next oil change.")
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

                    SurfaceCard {
                        PremiumSectionHeader(title: "Documents", subtitle: "Receipts and files linked to this vehicle")
                        if vehicle.sortedAttachments.isEmpty {
                            Text("No documents yet.")
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(vehicle.sortedAttachments.prefix(4)) { attachment in
                                    AttachmentThumbnailView(attachment: attachment)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(vehicle.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if appState.showOnlyCurrentVehicle {
                appState.selectedVehicleID = vehicle.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Vehicle") {
                        showingEdit = true
                    }
                    Button("Delete Vehicle", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
        SurfaceCard {
            HStack(spacing: 12) {
                quickActionButton(title: "Add Service", icon: "plus.circle.fill") {
                    showingServiceForm = true
                }
                quickActionButton(title: "Reminder", icon: "bell.badge.fill") {
                    showingReminderForm = true
                }
            }

            HStack(spacing: 12) {
                quickActionButton(title: "Document", icon: "doc.badge.plus") {
                    showingDocumentComposer = true
                }
                quickActionButton(title: "Export PDF", icon: "square.and.arrow.up.on.square.fill") {
                    exportTapped()
                }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline.weight(.medium))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
    }

    private func exportTapped() {
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