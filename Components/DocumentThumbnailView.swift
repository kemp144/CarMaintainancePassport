import UIKit
import SwiftUI

struct DocumentThumbnailView: View {
    let previewReference: String?
    let fallbackType: AttachmentType
    let pageCount: Int

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceSecondary)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: fallbackType.icon)
                        .font(.system(size: 20, weight: .medium))
                }
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if pageCount > 1 {
                Text("\(pageCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(4)
            } else if fallbackType == .pdf {
                Text("PDF")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(4)
            }
        }
        .frame(width: 60, height: 60)
        .task(id: previewReference) {
            guard let previewReference else {
                image = nil
                return
            }
            image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: previewReference).path)
        }
    }
}
