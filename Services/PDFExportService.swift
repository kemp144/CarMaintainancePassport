import Foundation
import UIKit

struct PDFExportService {
    static let shared = PDFExportService()

    func exportPassport(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-service-passport.pdf".replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: outputURL) { context in
            let services = vehicle.sortedServices
            let reminders = vehicle.sortedReminders

            context.beginPage()
            renderCoverPage(in: context.cgContext, bounds: pageBounds, vehicle: vehicle, reminders: reminders)

            var currentIndex = 0
            while currentIndex < services.count {
                context.beginPage()
                currentIndex = renderServicePage(in: context.cgContext, bounds: pageBounds, vehicle: vehicle, services: services, startIndex: currentIndex)
            }
        }

        return outputURL
    }

    func exportCSV(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-history.csv".replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        var csvString = "Date,Service Type,Mileage,Cost,Currency,Workshop,Notes\n"
        
        for entry in vehicle.sortedServices {
            let date = AppFormatters.mediumDate.string(from: entry.date)
            let type = entry.displayTitle.replacingOccurrences(of: ",", with: " ")
            let mileage = entry.mileage
            let cost = entry.price
            let currency = entry.currencyCode
            let workshop = entry.workshopName.replacingOccurrences(of: ",", with: " ")
            let notes = entry.notes.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
            
            csvString += "\(date),\(type),\(mileage),\(cost),\(currency),\(workshop),\(notes)\n"
        }
        
        try csvString.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func renderCoverPage(in context: CGContext, bounds: CGRect, vehicle: Vehicle, reminders: [ReminderItem]) {
        // Background
        context.saveGState()
        context.setFillColor(UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1).cgColor) // Slate 950: #020617
        context.fill(bounds)
        context.restoreGState()

        // Hero Section
        context.saveGState()
        let heroRect = CGRect(x: 32, y: 32, width: bounds.width - 64, height: 220)
        let colors = [
            UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1).cgColor, // Slate 900: #0F172A
            UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1).cgColor  // Slate 950: #020617
        ] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])
        context.addPath(UIBezierPath(roundedRect: heroRect, cornerRadius: 24).cgPath)
        context.clip()
        context.drawLinearGradient(gradient!, start: CGPoint(x: heroRect.midX, y: heroRect.minY), end: CGPoint(x: heroRect.midX, y: heroRect.maxY), options: [])

        if let reference = vehicle.coverImageReference,
           let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
            // Draw image with overlay
            image.draw(in: heroRect, blendMode: .normal, alpha: 0.25)
        }
        context.restoreGState()

        // Header Text
        draw(text: "CAR SERVICE PASSPORT", in: CGRect(x: 56, y: 64, width: bounds.width - 112, height: 20), font: .systemFont(ofSize: 14, weight: .bold), color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)) // Orange 500: #F97316
        draw(text: vehicle.title, in: CGRect(x: 56, y: 88, width: bounds.width - 112, height: 42), font: .systemFont(ofSize: 32, weight: .bold), color: .white)
        draw(text: vehicle.subtitle, in: CGRect(x: 56, y: 134, width: bounds.width - 112, height: 24), font: .systemFont(ofSize: 18, weight: .medium), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1)) // Slate 400: #94A3B8
        draw(text: "Official Maintenance Record", in: CGRect(x: 56, y: 182, width: bounds.width - 112, height: 20), font: .systemFont(ofSize: 13, weight: .medium), color: .white.withAlphaComponent(0.6))

        // Stats Row
        let infoTop: CGFloat = 284
        let statWidth = (bounds.width - 88) / 3
        drawStat(title: "TOTAL SPENT", value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode), origin: CGPoint(x: 32, y: infoTop), width: statWidth)
        drawStat(title: "ENTRIES", value: "\(vehicle.serviceEntries.count)", origin: CGPoint(x: 44 + statWidth, y: infoTop), width: statWidth)
        drawStat(title: "DOCUMENTS", value: "\(vehicle.attachments.count)", origin: CGPoint(x: 56 + statWidth * 2, y: infoTop), width: statWidth)

        // Vehicle Details
        let details = [
            ("Current Mileage", AppFormatters.mileage(vehicle.currentMileage)),
            ("License Plate", vehicle.licensePlate.isEmpty ? "Not recorded" : vehicle.licensePlate),
            ("VIN", vehicle.vin.isEmpty ? "Not recorded" : vehicle.vin),
            ("Purchase Date", vehicle.purchaseDate.map(AppFormatters.mediumDate.string) ?? "Not recorded"),
            ("Purchase Price", vehicle.purchasePrice.map { AppFormatters.currency($0, code: vehicle.currencyCode) } ?? "Not recorded"),
        ]

        var currentY = infoTop + 120
        draw(text: "VEHICLE SPECIFICATIONS", in: CGRect(x: 32, y: currentY, width: bounds.width - 64, height: 24), font: .systemFont(ofSize: 14, weight: .bold), color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1))
        currentY += 32

        for detail in details {
            draw(text: detail.0, in: CGRect(x: 32, y: currentY, width: 160, height: 20), font: .systemFont(ofSize: 12, weight: .medium), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1))
            draw(text: detail.1, in: CGRect(x: 200, y: currentY - 2, width: bounds.width - 232, height: 22), font: .systemFont(ofSize: 14, weight: .semibold), color: .white)
            
            // Separator
            context.saveGState()
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: 32, y: currentY + 22))
            context.addLine(to: CGPoint(x: bounds.width - 32, y: currentY + 22))
            context.strokePath()
            context.restoreGState()
            
            currentY += 34
        }

        draw(text: "SERVICE SUMMARY", in: CGRect(x: 32, y: currentY + 20, width: bounds.width - 64, height: 24), font: .systemFont(ofSize: 14, weight: .bold), color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1))
        draw(text: "This document contains the verified service history for this vehicle as recorded in the Car Service Passport application. It includes all maintenance, repairs, and inspections.", in: CGRect(x: 32, y: currentY + 48, width: bounds.width - 64, height: 44), font: .systemFont(ofSize: 12, weight: .regular), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1))
    }

    private func renderServicePage(in context: CGContext, bounds: CGRect, vehicle: Vehicle, services: [ServiceEntry], startIndex: Int) -> Int {
        // Background
        context.saveGState()
        context.setFillColor(UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1).cgColor)
        context.fill(bounds)
        context.restoreGState()

        draw(text: vehicle.title.uppercased(), in: CGRect(x: 32, y: 28, width: bounds.width - 64, height: 20), font: .systemFont(ofSize: 12, weight: .bold), color: UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1))
        draw(text: "DETAILED SERVICE HISTORY", in: CGRect(x: 32, y: 48, width: bounds.width - 64, height: 24), font: .systemFont(ofSize: 18, weight: .bold), color: .white)

        var currentY: CGFloat = 92
        var index = startIndex
        while index < services.count {
            let entry = services[index]
            let estimatedHeight: CGFloat = entry.notes.isEmpty ? 96.0 : 124.0
            
            if currentY + estimatedHeight > bounds.height - 48 {
                break
            }

            let cardRect = CGRect(x: 32, y: currentY, width: bounds.width - 64, height: estimatedHeight)
            context.saveGState()
            context.setFillColor(UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1).cgColor) // Slate 900
            context.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 16).cgPath)
            context.fillPath()
            
            // Card Border
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(1)
            context.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 16).cgPath)
            context.strokePath()
            context.restoreGState()

            draw(text: entry.displayTitle, in: CGRect(x: 48, y: currentY + 18, width: 260, height: 22), font: .systemFont(ofSize: 16, weight: .bold), color: .white)
            draw(text: AppFormatters.currency(entry.price, code: entry.currencyCode), in: CGRect(x: bounds.width - 180, y: currentY + 18, width: 132, height: 22), font: .systemFont(ofSize: 16, weight: .bold), color: .white)
            
            draw(text: "\(AppFormatters.mediumDate.string(from: entry.date)) • \(AppFormatters.mileage(entry.mileage))", in: CGRect(x: 48, y: currentY + 44, width: bounds.width - 120, height: 18), font: .systemFont(ofSize: 12, weight: .medium), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1))

            if !entry.workshopName.isEmpty {
                draw(text: entry.workshopName, in: CGRect(x: 48, y: currentY + 66, width: bounds.width - 120, height: 18), font: .systemFont(ofSize: 13, weight: .semibold), color: .white.withAlphaComponent(0.9))
            }

            if !entry.notes.isEmpty {
                draw(text: String(entry.notes.prefix(130)), in: CGRect(x: 48, y: currentY + 88, width: bounds.width - 120, height: 32), font: .systemFont(ofSize: 12, weight: .regular), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1))
            }

            currentY += estimatedHeight + 16
            index += 1
        }

        return index
    }

    private func drawStat(title: String, value: String, origin: CGPoint, width: CGFloat) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width, height: 92)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 16)
        UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1).setFill() // Slate 900
        path.fill()
        
        // Border
        let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: 16)
        UIColor.white.withAlphaComponent(0.1).setStroke()
        borderPath.lineWidth = 1
        borderPath.stroke()

        draw(text: title, in: CGRect(x: rect.minX + 16, y: rect.minY + 18, width: rect.width - 32, height: 16), font: .systemFont(ofSize: 10, weight: .bold), color: UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1))
        draw(text: value, in: CGRect(x: rect.minX + 16, y: rect.minY + 40, width: rect.width - 32, height: 28), font: .systemFont(ofSize: 18, weight: .bold), color: .white)
    }

    private func draw(text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.minimumLineHeight = font.pointSize * 1.14
        paragraph.maximumLineHeight = font.pointSize * 1.24
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }
}