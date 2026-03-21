import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentAddFilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator

    let onDocumentSeed: (DocumentDraftSeed) -> Void

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingPDFImporter = false

    init(onDocumentSeed: @escaping (DocumentDraftSeed) -> Void) {
        self.onDocumentSeed = onDocumentSeed
    }

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
        .presentationDetents([.medium, .height(500)])
        .presentationDragIndicator(.visible)
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

            completeDocument(
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
                completeDocument(
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
                        Text("Save photos, PDFs, and paperwork for this vehicle.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }
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
                        showingPDFImporter = true
                    } label: {
                        actionRow(
                            title: "Import PDF",
                            subtitle: "Save a PDF document for this vehicle.",
                            systemImage: "doc.badge.plus"
                        )
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                        actionRow(
                            title: "Add Photos",
                            subtitle: "Save one or more photos as a document.",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingCamera = true
                    } label: {
                        actionRow(
                            title: "Take Photo",
                            subtitle: "Capture a document photo for this vehicle.",
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
    private func completeDocument(_ seed: DocumentDraftSeed) {
        dismiss()
        onDocumentSeed(seed)
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
        completeDocument(
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

