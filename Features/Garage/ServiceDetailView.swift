import SwiftUI

struct ServiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditForm = false
    @State private var showingReminderForm = false
    @State private var showingDeleteConfirmation = false
    @State private var previewURL: URL?

    let entry: ServiceEntry

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SurfaceCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(entry.displayTitle, systemImage: entry.serviceType.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(entry.vehicle?.title ?? "Unknown vehicle")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Text(AppFormatters.currency(entry.price, code: entry.currencyCode))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accentSecondary)
                        }

                        Divider().overlay(AppTheme.separator)

                        detailRow(title: "Date", value: AppFormatters.mediumDate.string(from: entry.date))
                        detailRow(title: "Mileage", value: AppFormatters.mileage(entry.mileage))
                        detailRow(title: "Category", value: entry.category.title)
                        detailRow(title: "Workshop", value: entry.workshopName.isEmpty ? "Not recorded" : entry.workshopName)
                        detailRow(title: "Notes", value: entry.notes.isEmpty ? "No notes" : entry.notes)
                    }

                    if !entry.attachments.isEmpty {
                        SurfaceCard {
                            PremiumSectionHeader(title: "Attachments", subtitle: "Receipts, images and supporting documents")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(entry.attachments.sorted { $0.createdAt > $1.createdAt }) { attachment in
                                    Button {
                                        previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
                                    } label: {
                                        AttachmentThumbnailView(attachment: attachment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditForm = true
                }
                Menu {
                    Button("Create Reminder") {
                        showingReminderForm = true
                    }
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                ServiceEntryFormView(vehicle: entry.vehicle, entry: entry)
            }
        }
        .sheet(isPresented: $showingReminderForm) {
            if let vehicle = entry.vehicle {
                NavigationStack {
                    ReminderFormView(vehicle: vehicle, linkedService: entry)
                }
            }
        }
        .sheet(item: Binding(get: {
            previewURL.map(PreviewURL.init(url:))
        }, set: { value in
            previewURL = value?.url
        })) { item in
            QuickLookPreviewSheet(url: item.url)
        }
        .confirmationDialog("Delete this service entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private func deleteEntry() {
        if let vehicle = entry.vehicle {
            vehicle.updatedAt = .now
        }
        for attachment in entry.attachments {
            Task {
                await AttachmentStorageService.shared.delete(reference: attachment.storageReference)
                await AttachmentStorageService.shared.delete(reference: attachment.thumbnailReference)
            }
        }
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}