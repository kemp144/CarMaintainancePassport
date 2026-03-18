import UIKit
import SwiftData
import SwiftUI

enum DocumentSelection: Identifiable {
    case modern(DocumentRecord)
    case legacy(AttachmentRecord)

    var id: String {
        switch self {
        case .modern(let document):
            return "modern-\(document.id.uuidString)"
        case .legacy(let attachment):
            return "legacy-\(attachment.id.uuidString)"
        }
    }
}

struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let selection: DocumentSelection

    @State private var previewURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var isEditingPages = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        detailHeader
                        pageSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if case .modern(let document) = selection, document.pageCount > 1 {
                        Button(isEditingPages ? "Done" : "Edit") {
                            isEditingPages.toggle()
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this document?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await deleteDocument() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the document and all of its stored files.")
            }
            .sheet(item: Binding(
                get: {
                    previewURL.map(PreviewURL.init(url:))
                },
                set: { value in previewURL = value?.url }
            )) { item in
                QuickLookPreviewSheet(url: item.url)
            }
        }
    }

    @ViewBuilder
    private var detailHeader: some View {
        let snapshot = snapshotInfo

        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 52, height: 52)

                        Image(systemName: snapshot.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(snapshot.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(2)

                        Text(snapshot.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    infoChip(snapshot.category)
                    infoChip("\(snapshot.pageCount) \(snapshot.pageCount == 1 ? "file" : "files")")
                    infoChip(AppFormatters.mediumDate.string(from: snapshot.date))
                }

                if let service = snapshot.serviceTitle {
                    Label(service, systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                if !snapshot.notes.isEmpty {
                    Text(snapshot.notes)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var pageSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Attachments")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .tracking(0.8)
                    Spacer()
                }

                VStack(spacing: 12) {
                    ForEach(snapshotInfo.pages) { page in
                        pageCard(page)
                    }
                }
            }
        }
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppTheme.surfaceSecondary))
    }

    private func pageCard(_ page: DocumentDetailPageSnapshot) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 80, height: 80)

                if page.type == .image, let reference = page.previewReference {
                    if let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: page.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                } else {
                    Image(systemName: page.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(page.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if isEditingPages, case .modern = selection {
                Button(role: .destructive) {
                    Task { await deletePage(page.pageRecord) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(Circle())
                }
            } else {
                Button {
                    previewURL = page.previewURL
                } label: {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.surfaceSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.surfaceSecondary.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            previewURL = page.previewURL
        }
    }

    @MainActor
    private func deleteDocument() async {
        switch selection {
        case .modern(let document):
            await DocumentVaultStorageService.shared.deleteDocument(document, in: modelContext)
        case .legacy(let attachment):
            await AttachmentStorageService.shared.delete(reference: attachment.storageReference)
            await AttachmentStorageService.shared.delete(reference: attachment.thumbnailReference)
            modelContext.delete(attachment)
            attachment.vehicle?.updatedAt = .now
            attachment.serviceEntry?.updatedAt = .now
            try? modelContext.save()
        }

        Haptics.success()
        dismiss()
    }

    @MainActor
    private func deletePage(_ page: DocumentPageRecord?) async {
        guard let page else { return }
        let document = page.document
        await DocumentVaultStorageService.shared.deletePage(page, in: modelContext)
        if document?.pages.isEmpty ?? true {
            dismiss()
        }
        Haptics.success()
    }

    private var snapshotInfo: DocumentDetailSnapshot {
        switch selection {
        case .modern(let document):
            return DocumentDetailSnapshot(
                title: document.title,
                subtitle: document.vehicle?.title ?? "Document",
                category: document.category.title,
                date: document.documentDate,
                notes: document.notes,
                pageCount: document.pageCount,
                type: document.sortedPages.first?.type ?? .image,
                serviceTitle: document.serviceEntry?.displayTitle,
                pages: document.sortedPages.enumerated().map { index, page in
                    DocumentDetailPageSnapshot(
                        id: page.id,
                        pageRecord: page,
                        title: page.filename,
                        subtitle: page.type.title,
                        type: page.type,
                        previewReference: page.thumbnailReference ?? page.storageReference,
                        previewURL: AttachmentStorageService.fileURL(for: page.storageReference)
                    )
                }
            )
        case .legacy(let attachment):
            return DocumentDetailSnapshot(
                title: attachment.filename,
                subtitle: attachment.vehicle?.title ?? "Document",
                category: attachment.vaultCategory?.title ?? attachment.type.title,
                date: attachment.createdAt,
                notes: attachment.metadata ?? "",
                pageCount: 1,
                type: attachment.type,
                serviceTitle: attachment.serviceEntry?.displayTitle,
                pages: [
                    DocumentDetailPageSnapshot(
                        id: attachment.id,
                        pageRecord: nil,
                        title: attachment.filename,
                        subtitle: attachment.type.title,
                        type: attachment.type,
                        previewReference: attachment.thumbnailReference ?? attachment.storageReference,
                        previewURL: AttachmentStorageService.fileURL(for: attachment.storageReference)
                    )
                ]
            )
        }
    }
}

private struct DocumentDetailSnapshot {
    let title: String
    let subtitle: String
    let category: String
    let date: Date
    let notes: String
    let pageCount: Int
    let type: AttachmentType
    let serviceTitle: String?
    let pages: [DocumentDetailPageSnapshot]
}

private struct DocumentDetailPageSnapshot: Identifiable {
    let id: UUID
    let pageRecord: DocumentPageRecord?
    let title: String
    let subtitle: String
    let type: AttachmentType
    let previewReference: String?
    let previewURL: URL
}
