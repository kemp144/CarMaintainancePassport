import Foundation
import UIKit

struct DocumentDraftPage: Identifiable {
    let id = UUID()
    let type: AttachmentType
    let filename: String
    let imageData: Data?
    let sourceURL: URL?
    let previewImage: UIImage?

    init(
        type: AttachmentType = .image,
        filename: String,
        imageData: Data?,
        sourceURL: URL?
    ) {
        self.type = type
        self.filename = filename
        self.imageData = imageData
        self.sourceURL = sourceURL
        self.previewImage = imageData.flatMap(UIImage.init(data:))
    }
}
