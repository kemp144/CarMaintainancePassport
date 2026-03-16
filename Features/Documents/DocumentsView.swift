import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case images = "Images"
        case pdfs = "PDFs"

        var id: String { rawValue }
    }

    @Query(sort: \AttachmentRecord.createdAt, order: .reverse) private var attachments: [AttachmentRecord]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var selectedVehicleID: UUID?
    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showingComposer = false
    @State private var previewURL: URL?
    @State private var deleteTarget: AttachmentRecord?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var filteredAttachments: [AttachmentRecord] {
        attachments.filter { attachment in
            let matchesVehicle = selectedVehicleID == nil || attachment.vehicle?.id == selectedVehicleID
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .images: return attachment.type == .image
                case .pdfs: return attachment.type == .pdf
                }
            }()
            let matchesSearch = searchText.isEmpty || attachment.filename.localizedCaseInsensitiveContains(searchText) || (attachment.vehicle?.title.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesVehicle && matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            if filteredAttachments.isEmpty {
                ScrollView(showsIndicators: false) {
                    ContentUnavailableView {
                        Label("No documents yet", systemImage: "doc.on.doc.fill")
                    } description: {
                        Text("Store receipt photos, PDFs and ownership files so they stay attached to the right vehicle.")
                    } actions: {
                        Button("Add Document") {
                            showingComposer = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentSecondary)
                        .disabled(vehicles.isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach(filteredAttachments) { attachment in
                        Button {
                            previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
                        } label: {
                            documentRow(for: attachment)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTarget = attachment
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "File or vehicle")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("All Vehicles").tag(Optional<UUID>.none)
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.title).tag(Optional(vehicle.id))
                        }
                    }
                } label: {
                    Image(systemName: "car")
                }

                Menu {
                    Picker("Type", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }

                Button {
                    showingComposer = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vehicles.isEmpty)
            }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                DocumentComposerSheet(preselectedVehicle: vehicles.first(where: { $0.id == selectedVehicleID }))
            }
        }
        .sheet(item: Binding(get: {
            previewURL.map(PreviewURL.init(url:))
        }, set: { value in
            previewURL = value?.url
        })) { item in
            QuickLookPreviewSheet(url: item.url)
        }
        .confirmationDialog("Delete this document?", isPresented: Binding(get: {
            deleteTarget != nil
        }, set: { newValue in
            if !newValue { deleteTarget = nil }
        }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteAttachment()
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        }
    }

    private func deleteAttachment() {
        guard let deleteTarget else { return }
        Task {
            await AttachmentStorageService.shared.delete(reference: deleteTarget.storageReference)
            await AttachmentStorageService.shared.delete(reference: deleteTarget.thumbnailReference)
        }
        let context = deleteTarget.modelContext
        context?.delete(deleteTarget)
        try? context?.save()
        self.deleteTarget = nil
    }

    private func documentRow(for attachment: AttachmentRecord) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: attachment.type.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.filename)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(attachment.vehicle?.title ?? "Unknown vehicle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Text("\(attachment.type.title) • \(AppFormatters.mediumDate.string(from: attachment.createdAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer()
        }
    }
}

struct DocumentComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    let preselectedVehicle: Vehicle?

    @State private var selectedVehicleID: UUID?
    @State private var selectedServiceID: UUID?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var draftAttachments: [DraftAttachment] = []
    @State private var showingImporter = false

    init(preselectedVehicle: Vehicle? = nil) {
        self.preselectedVehicle = preselectedVehicle
        _selectedVehicleID = State(initialValue: preselectedVehicle?.id)
    }

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            Form {
                Section("Destination") {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.title).tag(Optional(vehicle.id))
                        }
                    }

                    if let selectedVehicle {
                        Picker("Linked service", selection: $selectedServiceID) {
                            Text("Vehicle document").tag(Optional<UUID>.none)
                            ForEach(selectedVehicle.sortedServices) { service in
                                Text("\(service.displayTitle) • \(AppFormatters.mediumDate.string(from: service.date))").tag(Optional(service.id))
                            }
                        }
                    }
                }

                Section("Files") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                        Label("Add photos", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import PDFs", systemImage: "doc.badge.plus")
                    }

                    ForEach(draftAttachments) { draft in
                        Label(draft.filename, systemImage: draft.type.icon)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Add Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveDocuments() }
                }
                .disabled(selectedVehicle == nil || draftAttachments.isEmpty)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                draftAttachments.append(contentsOf: urls.map { DraftAttachment(type: .pdf, filename: $0.lastPathComponent, imageData: nil, sourceURL: $0) })
            }
        }
        .onChange(of: selectedPhotos) {
            Task {
                for item in selectedPhotos {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        draftAttachments.append(DraftAttachment(type: .image, filename: "Photo \(draftAttachments.count + 1)", imageData: data, sourceURL: nil))
                    }
                }
                selectedPhotos = []
            }
        }
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleID }) ?? preselectedVehicle
    }

    private var linkedService: ServiceEntry? {
        selectedVehicle?.sortedServices.first(where: { $0.id == selectedServiceID })
    }

    private func saveDocuments() async {
        guard let selectedVehicle else { return }

        do {
            for draft in draftAttachments {
                switch draft.type {
                case .image:
                    guard let data = draft.imageData else { continue }
                    let stored = try await AttachmentStorageService.shared.saveImageData(data, filename: draft.filename)
                    let attachment = AttachmentRecord(
                        vehicle: selectedVehicle,
                        serviceEntry: linkedService,
                        type: .image,
                        filename: draft.filename,
                        storageReference: stored.storageReference,
                        thumbnailReference: stored.thumbnailReference
                    )
                    modelContext.insert(attachment)
                case .pdf:
                    guard let sourceURL = draft.sourceURL else { continue }
                    let reference = try await AttachmentStorageService.shared.importPDF(from: sourceURL)
                    let attachment = AttachmentRecord(
                        vehicle: selectedVehicle,
                        serviceEntry: linkedService,
                        type: .pdf,
                        filename: draft.filename,
                        storageReference: reference
                    )
                    modelContext.insert(attachment)
                }
            }

            selectedVehicle.updatedAt = .now
            try? modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }
}