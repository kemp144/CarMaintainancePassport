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

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    
    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showingComposer = false
    @State private var previewURL: URL?
    @State private var deleteTarget: AttachmentRecord?
    @State private var pendingServiceDraft: ScannedReceiptDraft?
    @State private var pendingServiceVehicle: Vehicle?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var filteredAttachments: [AttachmentRecord] {
        attachments.filter { attachment in
            var matchesVehicle = true
            if appState.showOnlyCurrentVehicle, let globalID = appState.selectedVehicleID {
                matchesVehicle = (attachment.vehicle?.id == globalID)
            } else if let localID = appState.selectedVehicleID {
                matchesVehicle = (attachment.vehicle?.id == localID)
            }
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

    private var vaultSummary: some View {
        let documentsCount = filteredAttachments.count
        let imagesCount = filteredAttachments.filter { $0.type == .image }.count
        let pdfCount = filteredAttachments.filter { $0.type == .pdf }.count

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Digital glovebox")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("\(documentsCount) saved")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                HStack(spacing: 12) {
                    documentStat(title: "Photos", value: "\(imagesCount)", icon: "photo.on.rectangle")
                    documentStat(title: "PDFs", value: "\(pdfCount)", icon: "doc.richtext")
                    documentStat(title: "Linked", value: String(filteredAttachments.filter { $0.serviceEntry != nil }.count), icon: "link")
                }

                Text("Store receipts, registration, insurance, and warranties where they belong. OCR and deeper document workflows are part of Pro.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func documentStat(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VehicleFilterScrollView(vehicles: vehicles)

                if filteredAttachments.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            vaultSummary

                            EmptyStateCard(
                                icon: "doc.on.doc.fill",
                                title: "Your digital glovebox",
                                message: "Save receipts, warranties, registration, and insurance files so the right paper is always attached to the right car.",
                                actionTitle: "Add Document"
                            ) {
                                if entitlementStore.canUseDocumentVault() {
                                    showingComposer = true
                                } else {
                                    paywallCoordinator.present(.documentVault)
                                }
                            }
                            .disabled(vehicles.isEmpty)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    List {
                        ForEach(filteredAttachments) { attachment in
                            documentRow(for: attachment)
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
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "File or vehicle")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
                    if entitlementStore.canUseDocumentVault() {
                        showingComposer = true
                    } else {
                        paywallCoordinator.present(.documentVault)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vehicles.isEmpty)
            }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                DocumentComposerSheet(preselectedVehicle: appState.selectedVehicleID != nil ? vehicles.first(where: { $0.id == appState.selectedVehicleID }) : nil) { vehicle, draft in
                    pendingServiceVehicle = vehicle
                    pendingServiceDraft = draft
                }
            }
        }
        .sheet(item: $pendingServiceDraft, onDismiss: {
            pendingServiceVehicle = nil
        }) { draft in
            if let vehicle = pendingServiceVehicle {
                NavigationStack {
                    ServiceEntryFormView(vehicle: vehicle, autoStartOCR: false, ocrDraft: draft)
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
            CompactAttachmentThumbnailView(attachment: attachment)

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.filename)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = attachment.vaultCategory {
                        Text(category.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text("•")
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    Text(attachment.vehicle?.title ?? "Unknown vehicle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Text("\(attachment.type.title) • \(AppFormatters.mediumDate.string(from: attachment.createdAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
                } label: {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.surfaceSecondary))
                }
                .buttonStyle(.borderless)

                Button {
                    deleteTarget = attachment
                } label: {
                    Text("Delete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.surfaceSecondary))
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTarget = attachment
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct DocumentComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    let preselectedVehicle: Vehicle?
    let onCreateServiceDraft: (Vehicle, ScannedReceiptDraft) -> Void

    @State private var selectedVehicleID: UUID?
    @State private var selectedServiceID: UUID?
    @State private var selectedVaultCategory: DocumentVaultCategory = .general
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var draftAttachments: [DraftAttachment] = []
    @State private var showingImporter = false
    @State private var showingCamera = false
    @State private var showingOCRScanner = false
    @State private var showingOCRFailureDialog = false
    @State private var showingOCRChoiceDialog = false
    @State private var scannedReceiptDraft: ScannedReceiptDraft?
    @State private var pendingReceiptImageData: Data?
    @State private var pendingReceiptFilename: String?

    init(preselectedVehicle: Vehicle? = nil, onCreateServiceDraft: @escaping (Vehicle, ScannedReceiptDraft) -> Void) {
        self.preselectedVehicle = preselectedVehicle
        self.onCreateServiceDraft = onCreateServiceDraft
        _selectedVehicleID = State(initialValue: preselectedVehicle?.id)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Form {
                Section {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.title).tag(Optional(vehicle.id))
                        }
                    }

                    if let selectedVehicle {
                        Picker("Category", selection: $selectedVaultCategory) {
                            ForEach(DocumentVaultCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        
                        Picker("Linked service", selection: $selectedServiceID) {
                            Text("Vehicle document").tag(Optional<UUID>.none)
                            ForEach(selectedVehicle.sortedServices) { service in
                                Text("\(service.displayTitle) • \(AppFormatters.mediumDate.string(from: service.date))").tag(Optional(service.id))
                            }
                        }
                    }
                } header: {
                    Text("Destination").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)

                Section {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                    }

                    Button {
                        if entitlementStore.canUseOCR() {
                            showingOCRScanner = true
                        } else {
                            paywallCoordinator.present(.ocrScan)
                        }
                    } label: {
                        Label("Scan receipt", systemImage: "doc.viewfinder")
                    }

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
                } header: {
                    Text("Files").foregroundStyle(AppTheme.secondaryText)
                }
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.primaryText)
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
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    draftAttachments.append(DraftAttachment(type: .image, filename: "Photo \(draftAttachments.count + 1)", imageData: data, sourceURL: nil))
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingOCRScanner) {
            OCRImagePickerSheet { image in
                guard let image else { return }
                guard let imageData = image.jpegData(compressionQuality: 0.86) else {
                    showingOCRFailureDialog = true
                    return
                }
                pendingReceiptImageData = imageData
                pendingReceiptFilename = "Receipt \(AppFormatters.receiptFilename.string(from: .now))"

                Task {
                    do {
                        let result = try await OCRService.shared.scan(image: image)
                        scannedReceiptDraft = ScannedReceiptDraft(
                            imageData: imageData,
                            filename: pendingReceiptFilename ?? "Receipt",
                            result: result
                        )
                        showingOCRChoiceDialog = true
                    } catch {
                        showingOCRFailureDialog = true
                    }
                }
            }
        }
        .confirmationDialog("What should we do with this receipt?", isPresented: $showingOCRChoiceDialog, titleVisibility: .visible) {
            Button("Create Service Draft") {
                guard let vehicle = selectedVehicle, let draft = scannedReceiptDraft else { return }
                dismiss()
                onCreateServiceDraft(vehicle, draft)
            }
            Button("Save as Document") {
                Task { await saveScannedReceipt() }
            }
            Button("Scan Again") {
                showingOCRScanner = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use the scanned receipt to prefill a service entry or keep it as a document in the vault.")
        }
        .alert("Could not extract receipt details", isPresented: $showingOCRFailureDialog) {
            Button("Save as Document") {
                Task { await saveScannedReceipt() }
            }
            Button("Scan Again") {
                showingOCRScanner = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The receipt image is still available. You can store it in Documents or try OCR again.")
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
                        vaultCategory: selectedVaultCategory,
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
                        vaultCategory: selectedVaultCategory,
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

    private func saveScannedReceipt() async {
        guard let selectedVehicle, let imageData = pendingReceiptImageData ?? scannedReceiptDraft?.imageData else { return }
        let filename = pendingReceiptFilename ?? scannedReceiptDraft?.filename ?? "Receipt"

        do {
            try await ScannedReceiptStorageService.shared.saveReceipt(
                imageData: imageData,
                filename: filename,
                vehicle: selectedVehicle,
                in: modelContext
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }
}