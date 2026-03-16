import Foundation

struct DraftAttachment: Identifiable {
    let id = UUID()
    let type: AttachmentType
    let filename: String
    let imageData: Data?
    let sourceURL: URL?
}