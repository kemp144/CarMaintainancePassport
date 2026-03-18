import Foundation
import UIKit
import Vision

struct OCRService {
    static let shared = OCRService()

    struct OCRResult {
        var date: Date?
        var price: Double?
        var mileage: Int?
        var workshopName: String?
        var suggestedServiceType: ServiceType?
        var suggestedCategory: EntryCategory?
        var rawText: String
    }

    enum OCRError: LocalizedError {
        case invalidImage
        case processingFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Could not process image"
            case .processingFailed: return "Text recognition failed"
            }
        }
    }

    func scan(image: UIImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let lines = try OCRService.recognizedLines(from: image)
            return OCRService.parseLines(lines)
        }.value
    }

    func scan(images: [UIImage]) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let orderedLines = try images.enumerated().map { index, image in
                (index, try OCRService.recognizedLines(from: image))
            }
            let combinedLines = orderedLines
                .sorted { $0.0 < $1.0 }
                .flatMap { $0.1 }
            return OCRService.parseLines(combinedLines)
        }.value
    }

    // MARK: - Parsing

    private static func recognizedLines(from image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "de-DE", "fr-FR", "hr-HR"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    static func parseLines(_ lines: [String]) -> OCRResult {
        let rawText = lines.joined(separator: "\n")
        var date: Date?
        var price: Double?
        var mileage: Int?
        var workshopName: String?
        var suggestedServiceType: ServiceType?
        let lowercasedText = rawText.lowercased()

        if lowercasedText.contains("oil") || lowercasedText.contains("engine oil") {
            suggestedServiceType = .oilChange
        } else if lowercasedText.contains("tyre") || lowercasedText.contains("tire") {
            suggestedServiceType = .tires
        } else if lowercasedText.contains("battery") {
            suggestedServiceType = .battery
        } else if lowercasedText.contains("brake") {
            suggestedServiceType = .brakes
        } else if lowercasedText.contains("inspection") || lowercasedText.contains("technical") || lowercasedText.contains("mot") {
            suggestedServiceType = .inspection
        } else if lowercasedText.contains("registration") {
            suggestedServiceType = .registration
        } else if lowercasedText.contains("insurance") || lowercasedText.contains("policy") {
            suggestedServiceType = .insurance
        }

        // Date formatters
        let dateFormats = ["dd.MM.yyyy", "d.M.yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd.MM.yy"]
        let dateFormatters: [DateFormatter] = dateFormats.map {
            let f = DateFormatter()
            f.dateFormat = $0
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }

        // Regex patterns
        let dateRegex = try? NSRegularExpression(pattern: #"(\d{1,2}[./]\d{1,2}[./]\d{2,4}|\d{4}-\d{2}-\d{2})"#)
        let mileageRegex = try? NSRegularExpression(pattern: #"(\d{4,7})\s*(?:km|KM|Km)"#)
        // Price: 1-6 digits, optional comma/dot, 2 digits, optional currency around it
        let priceRegex = try? NSRegularExpression(
            pattern: #"(?:[€$£CHF ]*)((?:\d{1,3}[. ]?)?\d{1,3}[.,]\d{2})(?:\s*[€$£]|\s*EUR|\s*USD|\s*CHF)?"#
        )

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            // Date
            if date == nil, let match = dateRegex?.firstMatch(in: line, range: range) {
                let dateStr = nsLine.substring(with: match.range(at: 1))
                let normalized = dateStr.replacingOccurrences(of: "/", with: ".")
                for formatter in dateFormatters {
                    if let parsed = formatter.date(from: normalized) {
                        date = parsed
                        break
                    }
                }
            }

            // Mileage
            if mileage == nil, let match = mileageRegex?.firstMatch(in: line, range: range) {
                let numStr = nsLine.substring(with: match.range(at: 1)).replacingOccurrences(of: " ", with: "")
                mileage = Int(numStr)
            }

            // Price (keep largest value found, as total cost)
            if let matches = priceRegex?.matches(in: line, range: range) {
                for match in matches {
                    let numStr = nsLine.substring(with: match.range(at: 1))
                        .replacingOccurrences(of: ",", with: ".")
                        .replacingOccurrences(of: " ", with: "")
                    if let value = Double(numStr), value > 1 && value < 99_999 && value > (price ?? 0) {
                        price = value
                    }
                }
            }
        }

        // Workshop name: first line containing a known business indicator
        let businessIndicators = ["service", "auto", "car", "werk", "gmbh", "d.o.o", "ltd", "llc",
                                   "workshop", "garage", "motor", "repair", "tire", "reifen"]
        for line in lines.prefix(12) {
            let lower = line.lowercased()
            let isNumeric = line.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
            if !isNumeric, businessIndicators.contains(where: { lower.contains($0) }) {
                workshopName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return OCRResult(
            date: date,
            price: price,
            mileage: mileage,
            workshopName: workshopName,
            suggestedServiceType: suggestedServiceType,
            suggestedCategory: suggestedServiceType?.defaultCategory,
            rawText: rawText
        )
    }
}
