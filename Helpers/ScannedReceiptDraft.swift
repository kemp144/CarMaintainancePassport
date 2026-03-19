import Foundation

struct ScannedReceiptDraft: Identifiable {
    let id = UUID()
    let imageData: Data
    let filename: String
    let result: OCRService.OCRResult

    var suggestedServiceType: ServiceType? {
        result.suggestedServiceType
    }

    var suggestedCategory: EntryCategory? {
        result.suggestedCategory
    }

    var hasUsefulData: Bool {
        result.date != nil || result.price != nil || result.mileage != nil || result.workshopName != nil || result.vendorName != nil
    }
}
