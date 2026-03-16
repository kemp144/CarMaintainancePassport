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

    private func renderCoverPage(in context: CGContext, bounds: CGRect, vehicle: Vehicle, reminders: [ReminderItem]) {
        context.saveGState()
        let heroRect = CGRect(x: 32, y: 32, width: bounds.width - 64, height: 220)
        let colors = [UIColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1).cgColor, UIColor(red: 0.08, green: 0.20, blue: 0.25, alpha: 1).cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])
        context.addPath(UIBezierPath(roundedRect: heroRect, cornerRadius: 28).cgPath)
        context.clip()
        context.drawLinearGradient(gradient!, start: CGPoint(x: heroRect.minX, y: heroRect.minY), end: CGPoint(x: heroRect.maxX, y: heroRect.maxY), options: [])

          if let reference = vehicle.coverImageReference,
              let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
            image.draw(in: heroRect.insetBy(dx: 12, dy: 12), blendMode: .normal, alpha: 0.35)
        }
        context.restoreGState()

        draw(text: "Car Service Passport", in: CGRect(x: 56, y: 64, width: bounds.width - 112, height: 28), font: .systemFont(ofSize: 18, weight: .semibold), color: .white.withAlphaComponent(0.88))
        draw(text: vehicle.title, in: CGRect(x: 56, y: 96, width: bounds.width - 112, height: 42), font: .systemFont(ofSize: 30, weight: .bold), color: .white)
        draw(text: vehicle.subtitle, in: CGRect(x: 56, y: 140, width: bounds.width - 112, height: 24), font: .systemFont(ofSize: 16, weight: .regular), color: .white.withAlphaComponent(0.82))
        draw(text: "Private by default. Exported locally.", in: CGRect(x: 56, y: 182, width: bounds.width - 112, height: 20), font: .systemFont(ofSize: 13, weight: .medium), color: .white.withAlphaComponent(0.72))

        let infoTop: CGFloat = 284
        let statWidth = (bounds.width - 88) / 3
        drawStat(title: "Total spent", value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode), origin: CGPoint(x: 32, y: infoTop), width: statWidth)
        drawStat(title: "Entries", value: "\(vehicle.serviceEntries.count)", origin: CGPoint(x: 44 + statWidth, y: infoTop), width: statWidth)
        drawStat(title: "Documents", value: "\(vehicle.attachments.count)", origin: CGPoint(x: 56 + statWidth * 2, y: infoTop), width: statWidth)

        let details = [
            ("Current mileage", AppFormatters.mileage(vehicle.currentMileage)),
            ("Purchase date", vehicle.purchaseDate.map(AppFormatters.mediumDate.string) ?? "Not recorded"),
            ("Purchase price", vehicle.purchasePrice.map { AppFormatters.currency($0, code: vehicle.currencyCode) } ?? "Not recorded"),
            ("VIN", vehicle.vin.isEmpty ? "Not recorded" : vehicle.vin),
            ("Next due", reminders.first.map { $0.title } ?? "No active reminders")
        ]

        var currentY = infoTop + 120
        draw(text: "Vehicle profile", in: CGRect(x: 32, y: currentY, width: bounds.width - 64, height: 24), font: .systemFont(ofSize: 18, weight: .semibold), color: .white)
        currentY += 36

        for detail in details {
            draw(text: detail.0, in: CGRect(x: 32, y: currentY, width: 160, height: 20), font: .systemFont(ofSize: 12, weight: .medium), color: UIColor.white.withAlphaComponent(0.52))
            draw(text: detail.1, in: CGRect(x: 200, y: currentY - 2, width: bounds.width - 232, height: 22), font: .systemFont(ofSize: 14, weight: .regular), color: .white)
            currentY += 28
        }

        draw(text: "Service history", in: CGRect(x: 32, y: currentY + 20, width: bounds.width - 64, height: 24), font: .systemFont(ofSize: 18, weight: .semibold), color: .white)
        draw(text: "The following pages summarize dates, mileage, costs, workshop names and note excerpts for the recorded maintenance and repairs.", in: CGRect(x: 32, y: currentY + 52, width: bounds.width - 64, height: 44), font: .systemFont(ofSize: 13, weight: .regular), color: UIColor.white.withAlphaComponent(0.68))
    }

    private func renderServicePage(in context: CGContext, bounds: CGRect, vehicle: Vehicle, services: [ServiceEntry], startIndex: Int) -> Int {
        draw(text: vehicle.title, in: CGRect(x: 32, y: 28, width: bounds.width - 64, height: 28), font: .systemFont(ofSize: 18, weight: .bold), color: .white)
        draw(text: "Service history", in: CGRect(x: 32, y: 54, width: bounds.width - 64, height: 20), font: .systemFont(ofSize: 13, weight: .medium), color: UIColor.white.withAlphaComponent(0.66))

        var currentY: CGFloat = 92
        var index = startIndex
        while index < services.count {
            let entry = services[index]
            let estimatedHeight = entry.notes.isEmpty ? 88.0 : 116.0
            if currentY + estimatedHeight > bounds.height - 48 {
                break
            }

            let cardRect = CGRect(x: 32, y: currentY, width: bounds.width - 64, height: estimatedHeight)
            context.saveGState()
            context.setFillColor(UIColor(red: 0.09, green: 0.13, blue: 0.19, alpha: 1).cgColor)
            context.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 20).cgPath)
            context.fillPath()
            context.restoreGState()

            draw(text: entry.displayTitle, in: CGRect(x: 48, y: currentY + 18, width: 260, height: 20), font: .systemFont(ofSize: 16, weight: .semibold), color: .white)
            draw(text: AppFormatters.currency(entry.price, code: entry.currencyCode), in: CGRect(x: bounds.width - 180, y: currentY + 18, width: 132, height: 20), font: .systemFont(ofSize: 16, weight: .semibold), color: UIColor(red: 0.48, green: 0.84, blue: 0.79, alpha: 1))
            draw(text: "\(AppFormatters.mediumDate.string(from: entry.date)) • \(AppFormatters.mileage(entry.mileage))", in: CGRect(x: 48, y: currentY + 44, width: bounds.width - 120, height: 18), font: .systemFont(ofSize: 12, weight: .medium), color: UIColor.white.withAlphaComponent(0.62))

            if !entry.workshopName.isEmpty {
                draw(text: entry.workshopName, in: CGRect(x: 48, y: currentY + 64, width: bounds.width - 120, height: 18), font: .systemFont(ofSize: 13, weight: .regular), color: .white)
            }

            if !entry.notes.isEmpty {
                draw(text: String(entry.notes.prefix(130)), in: CGRect(x: 48, y: currentY + 84, width: bounds.width - 120, height: 30), font: .systemFont(ofSize: 12, weight: .regular), color: UIColor.white.withAlphaComponent(0.7))
            }

            currentY += estimatedHeight + 12
            index += 1
        }

        return index
    }

    private func drawStat(title: String, value: String, origin: CGPoint, width: CGFloat) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width, height: 92)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)
        UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1).setFill()
        path.fill()
        draw(text: title, in: CGRect(x: rect.minX + 16, y: rect.minY + 18, width: rect.width - 32, height: 16), font: .systemFont(ofSize: 12, weight: .medium), color: UIColor.white.withAlphaComponent(0.56))
        draw(text: value, in: CGRect(x: rect.minX + 16, y: rect.minY + 40, width: rect.width - 32, height: 28), font: .systemFont(ofSize: 20, weight: .semibold), color: .white)
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