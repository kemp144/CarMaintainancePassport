import UIKit
import SwiftUI

struct DocumentThumbnailView: View {
    let previewReference: String?
    let fallbackType: AttachmentType
    let pageCount: Int

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceSecondary)

            if pageCount > 1 {
                multiPageBackground
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: fallbackType.icon)
                        .font(.system(size: 20, weight: .semibold))
                    Text(fallbackType.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .foregroundStyle(AppTheme.primaryText)
                .padding(12)
            }

            if pageCount > 1 {
                Text("\(pageCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.accentSecondary))
                    .padding(8)
            } else if fallbackType == .pdf {
                Text("PDF")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.accentSecondary))
                    .padding(8)
            }
        }
        .frame(width: 56, height: 56)
        .task(id: previewReference) {
            guard let previewReference else {
                image = nil
                return
            }
            image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: previewReference).path)
        }
    }

    private var multiPageBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceSecondary.opacity(0.92))
                .frame(width: 50, height: 50)
                .offset(x: -6, y: -5)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceSecondary.opacity(0.82))
                .frame(width: 52, height: 52)
                .offset(x: -3, y: -2)
        }
    }
}
