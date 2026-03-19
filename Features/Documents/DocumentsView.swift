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

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Digital glovebox")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("\(documentsCount) saved")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                HStack(spacing: 12) {
                    SummaryStatTile(title: "Documents", value: "\(documentsCount)", icon: "doc.fill")
                    SummaryStatTile(title: "Files", value: "\(pagesCount)", icon: "square.stack.3d.up.fill")
                    SummaryStatTile(title: "Linked", value: "\(linkedCount)", icon: "link")
                }

                if let savedDocumentLimit, !entitlementStore.canUseUnlimitedDocuments() {
                    HStack(spacing: 8) {
                        Text("\(savedDocumentCount) of \(savedDocumentLimit) saved items used")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hasReachedFreeDocumentLimit ? AppTheme.accent : AppTheme.secondaryText)

                        if hasReachedFreeDocumentLimit {
                            Text("Pro")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule(style: .continuous).fill(AppTheme.accent.opacity(0.14)))
                        }
                    }
                }

                Text("Store receipts, PDFs, and service paperwork with the right car.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
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

                    Text("Pro adds unlimited storage and OCR receipt capture.")
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

                                EmptyStateCard(
                                    icon: "doc.on.doc.fill",
                                    title: "Keep paperwork together",
                                    message: entitlementStore.canUseDocumentOCR()
                                        ? "Scan a receipt, or add photos and PDFs."
                                        : "Add photos and PDFs to keep receipts and records together.",
                                    actionTitle: "Add Files",
                                    verticalPadding: 28
                                ) {
                                    presentAddFiles()
                                }
                                .disabled(vehicles.isEmpty)
                            }
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
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
                            .padding(.bottom, 24)
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
            HStack(spacing: 14) {
                DocumentThumbnailView(
                    previewReference: item.thumbnailReference ?? item.previewReference,
                    fallbackType: item.type,
                    pageCount: item.pageCount
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let category = item.categoryTitle {
                            Text(category)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                            Text("•")
                                .foregroundStyle(AppTheme.tertiaryText)
                        }

                        Text(item.vehicleTitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Text("\(item.type.title) • \(AppFormatters.mediumDate.string(from: item.createdAt))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)

                    if let serviceTitle = item.serviceTitle {
                        Label(serviceTitle, systemImage: "link")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accentSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(item.pageCount) \(item.pageCount == 1 ? "file" : "files")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.surfaceSecondary))

                    Menu {
                        Button(role: .destructive) {
                            deleteTarget = item.selection
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(width: 28, height: 28)
                    }
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
