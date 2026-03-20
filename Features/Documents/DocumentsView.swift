import SwiftData
import SwiftUI

struct DocumentsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case images = "Images"
        case pdfs = "PDFs"

        var id: String { rawValue }
    }

    @Query(sort: \DocumentRecord.createdAt, order: .reverse) private var documents: [DocumentRecord]
    @Query(sort: \AttachmentRecord.createdAt, order: .reverse) private var attachments: [AttachmentRecord]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator

    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showingAddFilesSheet = false
    @State private var pendingDraftSeed: DocumentDraftSeed?
    @State private var pendingReceiptDraft: ScannedReceiptDraft?
    @State private var selectedDocument: DocumentSelection?
    @State private var deleteTarget: DocumentSelection?
    @State private var pendingServiceDraft: ScannedReceiptDraft?
    @State private var pendingServiceVehicle: Vehicle?
    @State private var deleteErrorMessage: String?
    @State private var isDeletingDocument = false

    private var documentItems: [DocumentListItem] {
        let modern = documents.map(DocumentListItem.init(document:))
        let legacy = attachments.map(DocumentListItem.init(attachment:))
        let combined = modern + legacy

        return combined
            .filter { item in
                var matchesVehicle = true
                if appState.showOnlyCurrentVehicle, let globalID = appState.selectedVehicleID {
                    matchesVehicle = (item.vehicle?.id == globalID)
                } else if let localID = appState.selectedVehicleID {
                    matchesVehicle = (item.vehicle?.id == localID)
                }

                let matchesFilter: Bool = {
                    switch filter {
                    case .all: return true
                    case .images: return item.type == .image
                    case .pdfs: return item.type == .pdf
                    }
                }()

                let matchesSearch = searchText.isEmpty || item.searchBlob.localizedCaseInsensitiveContains(searchText)
                return matchesVehicle && matchesFilter && matchesSearch
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var savedDocumentCount: Int {
        documents.count + attachments.count
    }

    private var savedDocumentLimit: Int? {
        entitlementStore.maxSavedDocuments
    }

    private var hasReachedFreeDocumentLimit: Bool {
        !entitlementStore.canAddSavedDocuments(existingCount: savedDocumentCount)
    }

    private var vaultSummary: some View {
        let documentsCount = documentItems.count
        let pagesCount = documentItems.reduce(0) { $0 + $1.pageCount }
        let linkedCount = documentItems.filter { $0.serviceTitle != nil }.count

        let typeLabel1 = filter == .all ? "Documents" : (filter == .images ? "Photo documents" : "PDF documents")
        let typeLabel2 = filter == .all ? "Attachments" : (filter == .images ? "Photos" : "PDFs")
        
        let tabDescription: String
        switch filter {
        case .all: tabDescription = "Showing all documents"
        case .images: tabDescription = "Showing photos only"
        case .pdfs: tabDescription = "Showing PDFs only"
        }

        return SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Tab-specific stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Digital glovebox")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(tabDescription)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    HStack(spacing: 12) {
                        SummaryStatTile(title: typeLabel1, value: "\(documentsCount)", icon: "doc.fill")
                        SummaryStatTile(title: typeLabel2, value: "\(pagesCount)", icon: "paperclip")
                        SummaryStatTile(title: "Linked", value: "\(linkedCount)", icon: "link")
                    }
                }

                // Global free plan info & Supporting copy
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(AppTheme.separator).padding(.vertical, 4)

                    if entitlementStore.canUseUnlimitedDocuments() {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                            Text("Pro active: Unlimited document storage")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                    } else if let savedDocumentLimit = savedDocumentLimit {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Free plan")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(AppTheme.tertiaryText)

                            Text("\(savedDocumentCount)/\(savedDocumentLimit) document slots used")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(hasReachedFreeDocumentLimit ? AppTheme.accent : AppTheme.secondaryText)
                            
                            Spacer()
                        }

                        Text("Each saved document can include one or more photos or PDFs.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }

                    Text("Keep receipts, PDFs, and service paperwork organized with the right vehicle.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var documentTopControls: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                Button {
                    filter = f
                } label: {
                    FilterPill(title: f.rawValue, isSelected: filter == f, compact: true)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                presentAddFiles()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(vehicles.isEmpty || hasReachedFreeDocumentLimit ? AppTheme.tertiaryText : AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.accent.opacity(vehicles.isEmpty || hasReachedFreeDocumentLimit ? 0.05 : 0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(vehicles.isEmpty || hasReachedFreeDocumentLimit)
        }
    }

    private var documentLimitCard: some View {
        SurfaceCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Need more document space?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Pro")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                    }

                    Text("Explore Pro for unlimited storage and OCR receipt capture.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 12)

                Button("Upgrade") {
                    paywallCoordinator.present(.documentVault)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var emptyStateCard: some View {
        let title: String
        let message: String
        let actionTitle: String
        
        switch filter {
        case .all:
            title = "Keep paperwork together"
            message = "Store receipts, service records, and vehicle documents in one place."
            actionTitle = "Add Files"
        case .images:
            title = "No photo documents yet"
            message = "Add photos of receipts, inspections, or service paperwork for this vehicle."
            actionTitle = "Add Photos"
        case .pdfs:
            title = "No PDF documents yet"
            message = "Import invoices, reports, and paperwork as PDFs for this vehicle."
            actionTitle = "Add PDFs"
        }

        return EmptyStateCard(
            icon: filter == .images ? "photo.on.rectangle.angled" : (filter == .pdfs ? "doc.richtext.fill" : "doc.on.doc.fill"),
            title: title,
            message: message,
            actionTitle: actionTitle,
            verticalPadding: 28
        ) {
            presentAddFiles()
        }
        .disabled(vehicles.isEmpty)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VehicleFilterScrollView(vehicles: vehicles)

                VStack(spacing: 12) {
                    documentTopControls
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)

                    if documentItems.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                vaultSummary

                                if hasReachedFreeDocumentLimit {
                                    documentLimitCard
                                }

                                emptyStateCard
                            }
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)
                            .padding(.top, 8)
                            .padding(.bottom, 120) // Ensure spacing above search bar
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                vaultSummary

                                if hasReachedFreeDocumentLimit {
                                    documentLimitCard
                                }

                                LazyVStack(spacing: 12) {
                                    ForEach(documentItems) { item in
                                        documentRow(for: item)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)
                            .padding(.top, 8)
                            .padding(.bottom, 120) // Ensure spacing above search bar
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "File, title or vehicle")
        .sheet(isPresented: $showingAddFilesSheet) {
            DocumentAddFilesSheet(
                allowReceiptScan: entitlementStore.canUseDocumentOCR(),
                onDocumentSeed: { seed in
                    pendingDraftSeed = seed
                },
                onReceiptScanned: { draft in
                    pendingReceiptDraft = draft
                }
            )
        }
        .sheet(item: $pendingDraftSeed, onDismiss: {
            pendingDraftSeed = nil
        }) { seed in
            NavigationStack {
                CreateDocumentView(
                    preselectedVehicle: currentVehicle,
                    draftSeed: seed
                )
            }
        }
        .sheet(item: $pendingReceiptDraft, onDismiss: {
            pendingReceiptDraft = nil
        }) { draft in
            NavigationStack {
                ReceiptReviewView(
                    vehicle: currentVehicle,
                    draft: draft
                ) { updatedDraft in
                    if let vehicle = currentVehicle {
                        pendingServiceVehicle = vehicle
                        pendingServiceDraft = updatedDraft
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedDocument) { selection in
            DocumentDetailView(selection: selection)
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
        .confirmationDialog("Delete this document?", isPresented: Binding(get: {
            deleteTarget != nil
        }, set: { newValue in
            if !newValue { deleteTarget = nil }
        }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let target = deleteTarget else { return }
                Task { await deleteDocument(target) }
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text("This removes the document and its attached files. Linked service entries will stay unchanged.")
        }
        .alert("Couldn’t delete document", isPresented: Binding(get: {
            deleteErrorMessage != nil
        }, set: { newValue in
            if !newValue { deleteErrorMessage = nil }
        })) {
            Button("OK", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "Please try again.")
        }
    }

    private var currentVehicle: Vehicle? {
        if let globalID = appState.selectedVehicleID {
            return vehicles.first(where: { $0.id == globalID })
        }
        return vehicles.first
    }

    private func documentRow(for item: DocumentListItem) -> some View {
        SurfaceCard(padding: 14) {
            HStack(alignment: .top, spacing: 14) {
                DocumentThumbnailView(
                    previewReference: item.thumbnailReference ?? item.previewReference,
                    fallbackType: item.type,
                    pageCount: item.pageCount
                )
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 6) {
                        Text(item.type.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.primaryText)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                            
                        Text(item.vehicleTitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(AppFormatters.mediumDate.string(from: item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.tertiaryText)

                    if let serviceTitle = item.serviceTitle {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 9, weight: .bold))
                            Text(serviceTitle)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Menu {
                    Button(role: .destructive) {
                        deleteTarget = item.selection
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: 32, height: 32, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDocument = item.selection
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTarget = item.selection
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @MainActor
    private func deleteDocument(_ target: DocumentSelection) async {
        guard !isDeletingDocument else { return }

        isDeletingDocument = true
        defer {
            isDeletingDocument = false
            self.deleteTarget = nil
        }

        do {
            switch target {
            case .modern(let document):
                try await DocumentVaultStorageService.shared.deleteDocument(document, in: modelContext)
            case .legacy(let attachment):
                try await DocumentVaultStorageService.shared.deleteLegacyAttachment(attachment, in: modelContext)
            }

            Haptics.success()
        } catch {
            deleteErrorMessage = "Please try again."
        }
    }

    private func presentAddFiles() {
        guard entitlementStore.canUseDocumentVault() else {
            paywallCoordinator.present(.documentVault)
            return
        }

        guard entitlementStore.canAddSavedDocuments(existingCount: savedDocumentCount) else {
            paywallCoordinator.present(.documentVault)
            return
        }

        guard !vehicles.isEmpty else { return }
        showingAddFilesSheet = true
    }
}

private struct DocumentListItem: Identifiable {
    enum Source {
        case modern(DocumentRecord)
        case legacy(AttachmentRecord)
    }

    let source: Source

    init(document: DocumentRecord) {
        source = .modern(document)
    }

    init(attachment: AttachmentRecord) {
        source = .legacy(attachment)
    }

    var id: String {
        switch source {
        case .modern(let document):
            return "modern-\(document.id.uuidString)"
        case .legacy(let attachment):
            return "legacy-\(attachment.id.uuidString)"
        }
    }

    var selection: DocumentSelection {
        switch source {
        case .modern(let document):
            return .modern(document)
        case .legacy(let attachment):
            return .legacy(attachment)
        }
    }

    var title: String {
        switch source {
        case .modern(let document):
            let cleaned = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty || ["Receipt", "New Document", "Document"].contains(cleaned) {
                return document.serviceEntry?.displayTitle ?? document.category.title
            }
            return cleaned
        case .legacy(let attachment):
            return attachment.filename
        }
    }

    var vehicle: Vehicle? {
        switch source {
        case .modern(let document):
            return document.vehicle
        case .legacy(let attachment):
            return attachment.vehicle
        }
    }

    var vehicleTitle: String {
        vehicle?.title ?? "Unknown vehicle"
    }

    var categoryTitle: String? {
        switch source {
        case .modern(let document):
            return document.category.title
        case .legacy(let attachment):
            return attachment.vaultCategory?.title
        }
    }

    var serviceTitle: String? {
        switch source {
        case .modern(let document):
            return document.serviceEntry?.displayTitle
        case .legacy(let attachment):
            return attachment.serviceEntry?.displayTitle
        }
    }

    var pageCount: Int {
        switch source {
        case .modern(let document):
            return max(1, document.pageCount)
        case .legacy:
            return 1
        }
    }

    var type: AttachmentType {
        switch source {
        case .modern(let document):
            return document.sortedPages.first?.type ?? .image
        case .legacy(let attachment):
            return attachment.type
        }
    }

    var createdAt: Date {
        switch source {
        case .modern(let document):
            return document.createdAt
        case .legacy(let attachment):
            return attachment.createdAt
        }
    }

    var previewReference: String? {
        switch source {
        case .modern(let document):
            return document.sortedPages.first?.storageReference
        case .legacy(let attachment):
            return attachment.storageReference
        }
    }

    var thumbnailReference: String? {
        switch source {
        case .modern(let document):
            return document.sortedPages.first?.thumbnailReference
        case .legacy(let attachment):
            return attachment.thumbnailReference
        }
    }

    var searchBlob: String {
        switch source {
        case .modern(let document):
            return [
                document.title,
                document.notes,
                document.category.title,
                document.vehicle?.title ?? "",
                document.serviceEntry?.displayTitle ?? ""
            ].joined(separator: " ")
        case .legacy(let attachment):
            return [
                attachment.filename,
                attachment.metadata ?? "",
                attachment.vaultCategory?.title ?? "",
                attachment.vehicle?.title ?? "",
                attachment.serviceEntry?.displayTitle ?? ""
            ].joined(separator: " ")
        }
    }
}
