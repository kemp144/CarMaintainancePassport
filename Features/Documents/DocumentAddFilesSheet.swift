import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentAddFilesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allowReceiptScan: Bool
    let onDocumentSeed: (DocumentDraftSeed) -> Void
    let onReceiptScanned: ((ScannedReceiptDraft) -> Void)?

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingReceiptScanner = false
    @State private var showingPDFImporter = false
    @State private var isScanningReceipt = false
    @State private var showingReceiptScanError = false
    @State private var receiptScanTask: Task<Void, Never>?

    init(
        allowReceiptScan: Bool = true,
        onDocumentSeed: @escaping (DocumentDraftSeed) -> Void,
        onReceiptScanned: ((ScannedReceiptDraft) -> Void)? = nil
    ) {
        self.allowReceiptScan = allowReceiptScan
        self.onDocumentSeed = onDocumentSeed
        self.onReceiptScanned = onReceiptScanned
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

                if isScanningReceipt {
                    ReceiptScanLoadingOverlay()
                        .transition(.opacity)
                        .zIndex(1)
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
        .onDisappear {
            receiptScanTask?.cancel()
        }
        .sheet(isPresented: $showingReceiptScanner) {
            OCRImagePickerSheet { image in
                guard let image else { return }
                startReceiptScan(with: image)
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
        .alert("Could not scan the receipt", isPresented: $showingReceiptScanError) {
            Button("Try Again") {
                showingReceiptScanner = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The receipt image is still available. You can try the scan again or add files manually.")
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
                        Text(allowReceiptScan ? "Add photos, PDFs, or a receipt scan for this vehicle." : "Add photos or PDFs for this vehicle.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                Text(allowReceiptScan ? "Multiple files can stay together in one document." : "You can keep multiple photos or PDFs together in one document.")
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
                    if allowReceiptScan {
                        Button {
                            showingReceiptScanner = true
                        } label: {
                            actionRow(
                                title: "Scan Receipt",
                                subtitle: "Create a service draft from a receipt.",
                                systemImage: "doc.viewfinder"
                            )
                        }
                        .buttonStyle(.plain)
                    }

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
    private func completeReceipt(_ draft: ScannedReceiptDraft) {
        dismiss()
        onReceiptScanned?(draft)
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
    private func startReceiptScan(with image: UIImage) {
        guard allowReceiptScan else { return }
        guard !isScanningReceipt else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.86) else { return }

        isScanningReceipt = true
        showingReceiptScanError = false
        receiptScanTask?.cancel()

        receiptScanTask = Task { @MainActor in
            defer {
                isScanningReceipt = false
                receiptScanTask = nil
            }

            do {
                let result = try await OCRService.shared.scan(image: image)
                guard !Task.isCancelled else { return }
                let draft = ScannedReceiptDraft(
                    imageData: imageData,
                    filename: "Receipt \(AppFormatters.receiptFilename.string(from: .now))",
                    result: result
                )
                completeReceipt(draft)
            } catch {
                guard !Task.isCancelled else { return }
                showingReceiptScanError = true
            }
        }
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

private struct ReceiptScanLoadingOverlay: View {
    var body: some View {
        VStack {
            Spacer()

            SurfaceCard {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.1)

                    Text("Scanning receipt...")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Finding the date, amount, workshop, and other details.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.opacity(0.92).ignoresSafeArea())
    }
}
