import SwiftData
import Foundation

@MainActor
final class ScannedReceiptStorageService {
    static let shared = ScannedReceiptStorageService()

    private init() {}

    func saveReceipt(
        imageData: Data,
        filename: String,
        vehicle: Vehicle,
        serviceEntry: ServiceEntry? = nil,
        category: DocumentVaultCategory = .receipts,
        in modelContext: ModelContext
    ) async throws {
        let page = DocumentDraftPage(
            type: .image,
            filename: filename,
            imageData: imageData,
            sourceURL: nil
        )

        _ = try await DocumentVaultStorageService.shared.saveDocument(
            pages: [page],
            title: URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent.isEmpty ? category.title : URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent,
            category: category,
            documentDate: serviceEntry?.date ?? .now,
            notes: "",
            vehicle: vehicle,
            serviceEntry: serviceEntry,
            in: modelContext
        )
    }
}
