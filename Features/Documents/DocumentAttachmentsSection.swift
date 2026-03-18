import UIKit
import SwiftUI

struct DocumentAttachmentsSection: View {
    @Binding var pages: [DocumentDraftPage]
    @Binding var previewPage: DocumentDraftPage?

    let onAddFiles: () -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    sectionLabel("Attachments")
                    Spacer()

                    Button {
                        onAddFiles()
                    } label: {
                        Label("Add files", systemImage: "doc.badge.plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                if pages.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text("No files added yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Add photos or PDFs to create a document for this vehicle. Multiple files can stay together in one document.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            attachmentRow(page, index: index)
                        }
                    }
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

    private func attachmentRow(_ page: DocumentDraftPage, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 76, height: 76)

                if let previewImage = page.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: page.type.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }

                Text("\(index + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.accentSecondary))
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(page.filename)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(page.type.title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    movePageUp(at: index)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index == 0 ? AppTheme.tertiaryText : AppTheme.primaryText)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(Circle())
                }
                .disabled(index == 0)

                Button {
                    movePageDown(at: index)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index == pages.count - 1 ? AppTheme.tertiaryText : AppTheme.primaryText)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(Circle())
                }
                .disabled(index == pages.count - 1)
            }

            Button(role: .destructive) {
                pages.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(AppTheme.surfaceSecondary.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            previewPage = page
        }
    }

    private func movePageUp(at index: Int) {
        guard index > 0 else { return }
        pages.swapAt(index, index - 1)
    }

    private func movePageDown(at index: Int) {
        guard index < pages.count - 1 else { return }
        pages.swapAt(index, index + 1)
    }
}
