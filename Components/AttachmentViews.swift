import QuickLook
import SwiftUI

struct AttachmentThumbnailView: View {
    let attachment: AttachmentRecord
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surfaceSecondary)

            Group {
                if attachment.type == .image, let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: attachment.type.icon)
                            .font(.title2.weight(.semibold))
                        Text(attachment.filename)
                            .font(.caption.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(attachment.type.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(AppTheme.accentSecondary))
                .padding(10)
        }
        .frame(height: 128)
        .task {
            guard attachment.type == .image else { return }
            let reference = attachment.thumbnailReference ?? attachment.storageReference
            image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path)
        }
    }
}

struct QuickLookPreviewSheet: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}