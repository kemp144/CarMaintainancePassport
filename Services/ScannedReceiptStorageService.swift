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
        let stored = try await AttachmentStorageService.shared.saveImageData(imageData, filename: filename)
        do {
            let attachment = AttachmentRecord(
                vehicle: vehicle,
                serviceEntry: serviceEntry,
                type: .image,
                vaultCategory: category,
                filename: filename,
                storageReference: stored.storageReference,
                thumbnailReference: stored.thumbnailReference
            )
            modelContext.insert(attachment)
            vehicle.updatedAt = .now
            try modelContext.save()
        } catch {
            await AttachmentStorageService.shared.delete(reference: stored.storageReference)
            await AttachmentStorageService.shared.delete(reference: stored.thumbnailReference)
            throw error
        }
    }
}
