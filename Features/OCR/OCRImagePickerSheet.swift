import PhotosUI
import SwiftUI

/// A sheet that lets the user pick an image (camera or library) for OCR scanning.
struct OCRImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onImageSelected: (UIImage?) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                VStack(spacing: 20) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.accent)

                    VStack(spacing: 8) {
                        Text("Scan Receipt (OCR)")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Take a photo or pick one from your library.\nWe'll extract the date, cost, mileage, and workshop name.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.accent))
                                .foregroundStyle(.white)
                                .font(.headline)
                        }

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.surfaceSecondary))
                                .foregroundStyle(AppTheme.primaryText)
                                .font(.headline)
                        }

                        Button("Cancel") {
                            dismiss()
                            onImageSelected(nil)
                        }
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                dismiss()
                onImageSelected(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItem) {
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    dismiss()
                    onImageSelected(image)
                }
            }
        }
    }
}
