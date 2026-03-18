import Foundation

struct DraftAttachment: Identifiable {
    let id = UUID()
    let type: AttachmentType
    let filename: String
    let imageData: Data?
    let sourceURL: URL?
    let isReceipt: Bool

    init(
        type: AttachmentType,
        filename: String,
        imageData: Data?,
        sourceURL: URL?,
        isReceipt: Bool = false
    ) {
        self.type = type
        self.filename = filename
        self.imageData = imageData
        self.sourceURL = sourceURL
        self.isReceipt = isReceipt
    }
}