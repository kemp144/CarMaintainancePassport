import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentAddFilesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelection: (DocumentDraftSeed) -> Void

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingReceiptScanner = false
    @State private var showingPDFImporter = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        actionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Add Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .height(430)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingReceiptScanner) {
            OCRImagePickerSheet { image in
                guard let image else { return }
                handleImageSelection(
                    image,
                    filenamePrefix: "Receipt",
                    title: "Receipt",
                    category: .receipts,
                    compressionQuality: 0.86
                )
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                handleImageSelection(
                    image,
                    filenamePrefix: "Photo",
                    title: "New Document",
                    category: .general,
                    compressionQuality: 0.84
                )
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }

            let pages = urls.enumerated().map { index, url in
                DocumentDraftPage(
                    type: .pdf,
                    filename: url.lastPathComponent.isEmpty ? "Document \(index + 1).pdf" : url.lastPathComponent,
                    imageData: nil,
                    sourceURL: url
                )
            }

            let title: String
            if urls.count == 1 {
                let stem = urls.first?.deletingPathExtension().lastPathComponent ?? ""
                title = stem.isEmpty ? "PDF Document" : stem
            } else {
                title = "PDF Document"
            }

            complete(
                DocumentDraftSeed(
                    pages: pages,
                    title: title,
                    category: .general
                )
            )
        }
        .onChange(of: selectedPhotoItems) {
            Task {
                let pages = await loadSelectedPhotos(selectedPhotoItems, prefix: "Photo")
                selectedPhotoItems = []
                guard !pages.isEmpty else { return }
                complete(
                    DocumentDraftSeed(
                        pages: pages,
                        title: "New Document",
                        category: .general
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 48, height: 48)

                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add files")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Add photos or PDFs to create a document for this vehicle.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                Text("Multiple files can stay together in one document.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Choose a source")

                VStack(spacing: 10) {
                    Button {
                        showingReceiptScanner = true
                    } label: {
                        actionRow(
                            title: "Scan Receipt (OCR)",
                            subtitle: "Capture a receipt and keep OCR-ready text with the document.",
                            systemImage: "doc.viewfinder"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingPDFImporter = true
                    } label: {
                        actionRow(
                            title: "Import PDF",
                            subtitle: "Bring in an existing PDF from Files.",
                            systemImage: "doc.badge.plus"
                        )
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                        actionRow(
                            title: "Add Photos",
                            subtitle: "Select one or more photos from your library.",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingCamera = true
                    } label: {
                        actionRow(
                            title: "Take Photo",
                            subtitle: "Use the camera to capture a paper copy.",
                            systemImage: "camera.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(0.8)
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @MainActor
    private func complete(_ seed: DocumentDraftSeed) {
        dismiss()
        onSelection(seed)
    }

    @MainActor
    private func handleImageSelection(
        _ image: UIImage,
        filenamePrefix: String,
        title: String,
        category: DocumentVaultCategory,
        compressionQuality: CGFloat
    ) {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return }

        let page = DocumentDraftPage(
            type: .image,
            filename: "\(filenamePrefix) \(AppFormatters.receiptFilename.string(from: .now))",
            imageData: data,
            sourceURL: nil
        )
        complete(
            DocumentDraftSeed(
                pages: [page],
                title: title,
                category: category
            )
        )
    }

    @MainActor
    private func loadSelectedPhotos(_ items: [PhotosPickerItem], prefix: String) async -> [DocumentDraftPage] {
        var pages: [DocumentDraftPage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let filename = "\(prefix) \(pages.count + 1)"
                pages.append(DocumentDraftPage(type: .image, filename: filename, imageData: data, sourceURL: nil))
            }
        }

        return pages
    }
}
