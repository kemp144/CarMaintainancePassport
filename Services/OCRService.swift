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
        var invoiceNumber: String?
        var subtotalAmount: Double?
        var salesTaxAmount: Double?
        var lineItems: [String]
        var vendorName: String?
        var dueDate: Date?

        init(
            date: Date? = nil,
            price: Double? = nil,
            mileage: Int? = nil,
            workshopName: String? = nil,
            suggestedServiceType: ServiceType? = nil,
            suggestedCategory: EntryCategory? = nil,
            rawText: String,
            invoiceNumber: String? = nil,
            subtotalAmount: Double? = nil,
            salesTaxAmount: Double? = nil,
            lineItems: [String] = [],
            vendorName: String? = nil,
            dueDate: Date? = nil
        ) {
            self.date = date
            self.price = price
            self.mileage = mileage
            self.workshopName = workshopName
            self.suggestedServiceType = suggestedServiceType
            self.suggestedCategory = suggestedCategory
            self.rawText = rawText
            self.invoiceNumber = invoiceNumber
            self.subtotalAmount = subtotalAmount
            self.salesTaxAmount = salesTaxAmount
            self.lineItems = lineItems
            self.vendorName = vendorName
            self.dueDate = dueDate
        }

        var invoiceDate: Date? { date }
        var totalAmount: Double? { price }
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
        var invoiceNumber: String?
        var subtotalAmount: Double?
        var salesTaxAmount: Double?
        var dueDate: Date?
        var vendorName: String?
        var lineItems: [String] = []
        var suggestedServiceType: ServiceType?
        let lowercasedText = rawText.lowercased()
        let cleanedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

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
        let invoiceNumberRegex = try? NSRegularExpression(
            pattern: #"(?i)\b(?:invoice|receipt|bill|rechnung|rechnungsnummer|rechnungsnr\.?|document)\s*(?:no\.?|number|nr\.?|#|id)?\s*[:#-]?\s*([A-Z0-9][A-Z0-9\-\/]{2,})"#
        )
        let standaloneNumberRegex = try? NSRegularExpression(
            pattern: #"(?i)\b(?:no\.?|nr\.?|#)\s*[:#-]?\s*([A-Z0-9][A-Z0-9\-\/]{2,})"#
        )

        func parseDate(in line: String) -> Date? {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = dateRegex?.firstMatch(in: line, range: range) else { return nil }
            let dateStr = nsLine.substring(with: match.range(at: 1))
            let normalized = dateStr.replacingOccurrences(of: "/", with: ".")
            for formatter in dateFormatters {
                if let parsed = formatter.date(from: normalized) {
                    return parsed
                }
            }
            return nil
        }

        func parsePrice(in line: String, preferLargest: Bool = false) -> Double? {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let matches = priceRegex?.matches(in: line, range: range), !matches.isEmpty else { return nil }
            var bestValue: Double?
            for match in matches {
                let numStr = nsLine.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: " ", with: "")
                if let value = Double(numStr), value > 0, value < 99_999 {
                    if preferLargest {
                        bestValue = max(bestValue ?? 0, value)
                    } else {
                        return value
                    }
                }
            }
            return bestValue
        }

        func extractInvoiceNumber(from line: String) -> String? {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if let match = invoiceNumberRegex?.firstMatch(in: line, range: range) {
                let value = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            if let match = standaloneNumberRegex?.firstMatch(in: line, range: range) {
                let value = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            return nil
        }

        func isLikelyVendorLine(_ line: String, index: Int) -> Bool {
            let lower = line.lowercased()
            let isNumericHeavy = line.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
            guard !isNumericHeavy, !lower.contains("invoice"), !lower.contains("receipt"), !lower.contains("total"), !lower.contains("subtotal"), !lower.contains("tax"), !lower.contains("due"), !lower.contains("date"), !lower.contains("phone"), !lower.contains("tel"), !lower.contains("www"), !lower.contains("http") else {
                return false
            }
            if lower.contains("gmbh") || lower.contains("ltd") || lower.contains("llc") || lower.contains("auto") || lower.contains("garage") || lower.contains("service") || lower.contains("repair") || lower.contains("workshop") {
                return true
            }
            return index < 6 && line.rangeOfCharacter(from: .letters) != nil && line.split(separator: " ").count <= 6
        }

        func isLineItemCandidate(_ line: String) -> Bool {
            let lower = line.lowercased()
            guard line.rangeOfCharacter(from: .letters) != nil else { return false }
            let excluded = [
                "invoice", "receipt", "subtotal", "total", "tax", "vat", "balance", "amount due",
                "date", "due", "phone", "tel", "email", "www", "http", "cash", "card", "change"
            ]
            guard !excluded.contains(where: { lower.contains($0) }) else { return false }
            if line.count > 90 { return false }
            return true
        }

        for (lineIndex, line) in lines.enumerated() {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            let lower = line.lowercased()

            if invoiceNumber == nil, let extracted = extractInvoiceNumber(from: line) {
                invoiceNumber = extracted
            }

            if vendorName == nil, isLikelyVendorLine(line, index: lineIndex) {
                vendorName = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if date == nil,
               !lower.contains("due"),
               (lower.contains("date") || lower.contains("invoice") || lower.contains("receipt") || lower.contains("datum") || lower.contains("issued") || lower.contains("bill")),
               let parsedDate = parseDate(in: line) {
                date = parsedDate
            }

            if dueDate == nil,
               (lower.contains("due") || lower.contains("pay by") || lower.contains("faellig")),
               let parsedDate = parseDate(in: line) {
                dueDate = parsedDate
            }

            if subtotalAmount == nil, (lower.contains("subtotal") || lower.contains("sub total") || lower.contains("netto")), let amount = parsePrice(in: line) {
                subtotalAmount = amount
            }

            if salesTaxAmount == nil, (lower.contains("tax") || lower.contains("vat") || lower.contains("mwst") || lower.contains("tva")), let amount = parsePrice(in: line) {
                salesTaxAmount = amount
            }

            if price == nil, (lower.contains("total") || lower.contains("amount due") || lower.contains("grand total") || lower.contains("balance due") || lower.contains("gesamt")), let amount = parsePrice(in: line) {
                price = amount
            }

            if price == nil, let amount = parsePrice(in: line, preferLargest: true) {
                price = amount
            }

            if mileage == nil, let match = mileageRegex?.firstMatch(in: line, range: range) {
                let numStr = nsLine.substring(with: match.range(at: 1)).replacingOccurrences(of: " ", with: "")
                mileage = Int(numStr)
            }

            if isLineItemCandidate(line) {
                lineItems.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if workshopName == nil, let vendorName, (vendorName.lowercased().contains("garage") || vendorName.lowercased().contains("repair") || vendorName.lowercased().contains("service") || vendorName.lowercased().contains("auto") || vendorName.lowercased().contains("workshop")) {
                workshopName = vendorName
            } else if workshopName == nil, (lower.contains("garage") || lower.contains("repair") || lower.contains("service") || lower.contains("workshop") || lower.contains("auto")) {
                workshopName = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if lineItems.count > 6 {
                lineItems = Array(lineItems.prefix(6))
            }
        }

        if date == nil {
            for line in cleanedLines.prefix(10) where !line.lowercased().contains("due") {
                if let parsed = parseDate(in: line) {
                    date = parsed
                    break
                }
            }
        }

        if vendorName == nil {
            vendorName = cleanedLines.first(where: { line in
                let lower = line.lowercased()
                return line.rangeOfCharacter(from: .letters) != nil && !lower.contains("invoice") && !lower.contains("receipt") && !lower.contains("date")
            })
        }

        if workshopName == nil, let vendorName {
            let lower = vendorName.lowercased()
            if lower.contains("garage") || lower.contains("repair") || lower.contains("service") || lower.contains("workshop") || lower.contains("auto") || lower.contains("tyre") || lower.contains("tire") {
                workshopName = vendorName
            }
        }

        return OCRResult(
            date: date,
            price: price,
            mileage: mileage,
            workshopName: workshopName,
            suggestedServiceType: suggestedServiceType,
            suggestedCategory: suggestedServiceType?.defaultCategory,
            rawText: rawText,
            invoiceNumber: invoiceNumber,
            subtotalAmount: subtotalAmount,
            salesTaxAmount: salesTaxAmount,
            lineItems: lineItems,
            vendorName: vendorName,
            dueDate: dueDate
        )
    }
}
