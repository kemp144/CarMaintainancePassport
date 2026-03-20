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
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (Sticky-like)
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: "CBD5E1")) // text-slate-300
                                .frame(width: 40, height: 40) // w-10 h-10
                                .background(Circle().fill(AppTheme.surfaceSecondary)) // bg-slate-800
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayTitle)
                                .font(.system(size: 24, weight: .bold)) // text-2xl font-bold
                                .foregroundStyle(AppTheme.primaryText)
                            Text(entry.vehicle?.title ?? "Unknown vehicle")
                                .font(.system(size: 14)) // text-sm
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.leading, 16)

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                showingEditForm = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16)) // w-4 h-4
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(AppTheme.surfaceSecondary))
                            }
                            
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(AppTheme.surfaceSecondary))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 48) // pt-12 approx safe area
                    .padding(.bottom, 24) // pb-6
                }
                .background(AppTheme.elevatedBackground) // bg-slate-900

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Main Info Card
                        SurfaceCard(padding: 24) { // p-6
                            VStack(spacing: 16) { // space-y-4
                                // Date
                                HStack(spacing: 12) { // gap-3
                                    ZStack {
                                        Circle().fill(AppTheme.surfaceSecondary).frame(width: 40, height: 40)
                                        Image(systemName: "calendar").font(.system(size: 20)).foregroundStyle(AppTheme.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Date")
                                            .font(.system(size: 12)) // text-xs
                                            .foregroundStyle(AppTheme.secondaryText)
                                        Text(AppFormatters.mediumDate.string(from: entry.date))
                                            .font(.system(size: 16, weight: .medium)) // text-white font-medium
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                    Spacer()
                                }
                                
                                // Mileage
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(AppTheme.surfaceSecondary).frame(width: 40, height: 40)
                                        Image(systemName: "gauge.with.dots.needle.33percent").font(.system(size: 20)).foregroundStyle(AppTheme.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Mileage")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.secondaryText)
                                        Text(AppFormatters.mileage(entry.mileage))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                    Spacer()
                                }
                                
                                // Cost
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(AppTheme.surfaceSecondary).frame(width: 40, height: 40)
                                        Image(systemName: "dollarsign").font(.system(size: 20)).foregroundStyle(AppTheme.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Cost")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.secondaryText)
                                        Text(AppFormatters.currency(entry.price, code: entry.currencyCode))
                                            .font(.system(size: 20, weight: .medium)) // text-xl
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                    Spacer()
                                }
                            }
                        }

                        // Notes
                        if !entry.notes.isEmpty {
                            SurfaceCard(padding: 24) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 8) { // mb-2
                                        Text("Notes")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.secondaryText)
                                        Text(entry.notes)
                                            .font(.system(size: 16))
                                            .foregroundStyle(AppTheme.primaryText)
                                            .lineSpacing(4) // leading-relaxed roughly
                                    }
                                    Spacer()
                                }
                            }
                        }

                        // Attachments
                        if !entry.attachments.isEmpty {
                            SurfaceCard(padding: 24) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Attachments")
                                        .font(.system(size: 14)) // text-sm
                                        .foregroundStyle(AppTheme.secondaryText) // text-slate-400
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { // grid-cols-3
                                        ForEach(entry.attachments.sorted { $0.createdAt > $1.createdAt }) { attachment in
                                            Button {
                                                previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8) // rounded-lg
                                                        .fill(AppTheme.surfaceSecondary)
                                                        .aspectRatio(1, contentMode: .fit) // aspect-square
                                                    
                                                    Image(systemName: "doc.text.fill") // fallback icon
                                                        .font(.system(size: 32)) // w-8 h-8
                                                        .foregroundStyle(AppTheme.tertiaryText)
                                                    
                                                    // Add actual thumbnail on top if available
                                                    AttachmentThumbnailView(attachment: attachment)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 24) // px-6
                    .padding(.bottom, 60)
                }
            }
        }
        .navigationBarHidden(true)
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

    private func deleteEntry() {
        let vehicle = entry.vehicle
        for attachment in entry.attachments {
            Task {
                await AttachmentStorageService.shared.delete(reference: attachment.storageReference)
                await AttachmentStorageService.shared.delete(reference: attachment.thumbnailReference)
            }
        }
        modelContext.delete(entry)
        try? modelContext.save()
        if let vehicle {
            VehicleMileageResolver.recalculateCurrentMileage(for: vehicle)
            try? modelContext.save()
        }
        dismiss()
    }
}
