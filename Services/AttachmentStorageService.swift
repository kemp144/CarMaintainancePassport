import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

actor AttachmentStorageService {
    static let shared = AttachmentStorageService()

    private let fileManager = FileManager.default

    private var rootDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("AttachmentVault", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func fileURL(for reference: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("AttachmentVault", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent(reference)
    }

    static func data(for reference: String?) -> Data? {
        guard let reference else { return nil }
        return try? Data(contentsOf: fileURL(for: reference))
    }

    static func restoreFileData(_ data: Data, reference: String) throws {
        let url = fileURL(for: reference)
        let folder = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try data.write(to: url, options: .atomic)
    }

    func saveImageData(_ data: Data, filename: String) throws -> (storageReference: String, thumbnailReference: String?) {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let normalized = image.preparingForDisplay() ?? image
        let fullSize = normalized.scaled(maxDimension: 2200)
        let thumbnail = normalized.scaled(maxDimension: 480)

        let storageName = uniqueFilename(from: filename, extensionOverride: "jpg")
        let thumbnailName = uniqueFilename(from: filename + "-thumb", extensionOverride: "jpg")

        try fullSize.jpegData(compressionQuality: 0.84)?.write(to: rootDirectory.appendingPathComponent(storageName))
        try thumbnail.jpegData(compressionQuality: 0.76)?.write(to: rootDirectory.appendingPathComponent(thumbnailName))

        return (storageName, thumbnailName)
    }

    func importPDF(from url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let targetName = uniqueFilename(from: url.lastPathComponent, extensionOverride: url.pathExtension.isEmpty ? "pdf" : url.pathExtension)
        let targetURL = rootDirectory.appendingPathComponent(targetName)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: url, to: targetURL)
        return targetName
    }

    func delete(reference: String?) {
        guard let reference else { return }
        let url = rootDirectory.appendingPathComponent(reference)
        try? fileManager.removeItem(at: url)
    }

    func url(for reference: String) -> URL {
        Self.fileURL(for: reference)
    }

    private func uniqueFilename(from filename: String, extensionOverride: String? = nil) -> String {
        let base = filename.replacingOccurrences(of: " ", with: "-")
        let sanitized = base.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_" )).inverted).joined()
        let ext = extensionOverride ?? URL(fileURLWithPath: filename).pathExtension
        let stem = URL(fileURLWithPath: sanitized).deletingPathExtension().lastPathComponent
        return "\(UUID().uuidString)-\(stem).\(ext)"
    }
}

private extension UIImage {
    func scaled(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }
        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
