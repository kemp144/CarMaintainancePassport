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

    func deleteDocument(_ document: DocumentRecord, in modelContext: ModelContext) async throws {
        let linkedServiceEntry = document.serviceEntry
        let linkedVehicle = document.vehicle
        let storedReferences = document.sortedPages.flatMap { page -> [String?] in
            [page.storageReference, page.thumbnailReference]
        }

        document.serviceEntry = nil
        linkedVehicle?.updatedAt = .now
        linkedServiceEntry?.updatedAt = .now

        for page in document.sortedPages {
            modelContext.delete(page)
        }

        modelContext.delete(document)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        for reference in storedReferences {
            await AttachmentStorageService.shared.delete(reference: reference)
        }
    }

    func deleteLegacyAttachment(_ attachment: AttachmentRecord, in modelContext: ModelContext) async throws {
        let linkedServiceEntry = attachment.serviceEntry
        let linkedVehicle = attachment.vehicle
        let storedReferences = [attachment.storageReference, attachment.thumbnailReference]

        attachment.serviceEntry = nil
        linkedVehicle?.updatedAt = .now
        linkedServiceEntry?.updatedAt = .now

        modelContext.delete(attachment)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        for reference in storedReferences {
            await AttachmentStorageService.shared.delete(reference: reference)
        }
    }

    func deletePage(_ page: DocumentPageRecord, in modelContext: ModelContext) async throws {
        guard let document = page.document else { return }

        let remaining = document.sortedPages.filter { $0.id != page.id }
        if remaining.isEmpty {
            try await deleteDocument(document, in: modelContext)
            return
        }

        let linkedVehicle = document.vehicle
        let linkedServiceEntry = document.serviceEntry
        let storedReferences = [page.storageReference, page.thumbnailReference]

        modelContext.delete(page)

        for (index, remainingPage) in remaining.enumerated() {
            remainingPage.orderIndex = index
        }

        document.updatedAt = .now
        linkedVehicle?.updatedAt = .now
        linkedServiceEntry?.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        for reference in storedReferences {
            await AttachmentStorageService.shared.delete(reference: reference)
        }
    }
}
