import Foundation
import SwiftData

@MainActor
final class DocumentVaultStorageService {
    static let shared = DocumentVaultStorageService()

    private init() {}

    func saveDocument(
        pages: [DocumentDraftPage],
        title: String,
        category: DocumentVaultCategory,
        documentDate: Date,
        notes: String,
        vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        in modelContext: ModelContext
    ) async throws -> DocumentRecord {
        guard !pages.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = DocumentRecord(
            vehicle: vehicle,
            serviceEntry: serviceEntry,
            title: cleanedTitle.isEmpty ? category.title : cleanedTitle,
            category: category,
            documentDate: documentDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(document)

        var storedReferences: [String] = []
        do {
            var storedPageIndex = 0
            for draftPage in pages {
                let stored: (storageReference: String, thumbnailReference: String?)
                switch draftPage.type {
                case .image:
                    guard let data = draftPage.imageData else { continue }
                    stored = try await AttachmentStorageService.shared.saveImageData(data, filename: draftPage.filename)
                case .pdf:
                    guard let sourceURL = draftPage.sourceURL else { continue }
                    stored = (try await AttachmentStorageService.shared.importPDF(from: sourceURL), nil)
                }

                storedReferences.append(stored.storageReference)
                if let thumbnailReference = stored.thumbnailReference {
                    storedReferences.append(thumbnailReference)
                }

                let page = DocumentPageRecord(
                    document: document,
                    orderIndex: storedPageIndex,
                    type: draftPage.type,
                    filename: draftPage.filename,
                    storageReference: stored.storageReference,
                    thumbnailReference: stored.thumbnailReference
                )
                modelContext.insert(page)
                document.pages.append(page)
                storedPageIndex += 1
            }

            guard !document.pages.isEmpty else {
                modelContext.delete(document)
                throw CocoaError(.fileWriteUnknown)
            }

            vehicle.updatedAt = .now
            serviceEntry?.updatedAt = .now
            document.updatedAt = .now
            try modelContext.save()
            return document
        } catch {
            for reference in storedReferences {
                await AttachmentStorageService.shared.delete(reference: reference)
            }
            for page in document.pages {
                modelContext.delete(page)
            }
            modelContext.delete(document)
            throw error
        }
    }

    func deleteDocument(_ document: DocumentRecord, in modelContext: ModelContext) async {
        for page in document.sortedPages {
            await AttachmentStorageService.shared.delete(reference: page.storageReference)
            await AttachmentStorageService.shared.delete(reference: page.thumbnailReference)
            modelContext.delete(page)
        }

        modelContext.delete(document)
        document.vehicle?.updatedAt = .now
        document.serviceEntry?.updatedAt = .now
        try? modelContext.save()
    }

    func deletePage(_ page: DocumentPageRecord, in modelContext: ModelContext) async {
        guard let document = page.document else { return }

        await AttachmentStorageService.shared.delete(reference: page.storageReference)
        await AttachmentStorageService.shared.delete(reference: page.thumbnailReference)
        modelContext.delete(page)

        let remaining = document.sortedPages.filter { $0.id != page.id }
        if remaining.isEmpty {
            modelContext.delete(document)
            document.vehicle?.updatedAt = .now
            document.serviceEntry?.updatedAt = .now
            try? modelContext.save()
            return
        }

        for (index, remainingPage) in remaining.enumerated() {
            remainingPage.orderIndex = index
        }

        document.updatedAt = .now
        document.vehicle?.updatedAt = .now
        document.serviceEntry?.updatedAt = .now
        try? modelContext.save()
    }
}
