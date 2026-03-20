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

    func exportResaleReport(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-for-sale.pdf".replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let slate50  = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1) // #F8FAFC
        let slate100 = UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1) // #F1F5F9
        let slate700 = UIColor(red: 0.20, green: 0.26, blue: 0.36, alpha: 1) // #334155
        let slate500 = UIColor(red: 0.40, green: 0.47, blue: 0.56, alpha: 1) // #64748B
        let orange500 = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
        let green600  = UIColor(red: 0.09, green: 0.67, blue: 0.27, alpha: 1)

        try renderer.writePDF(to: outputURL) { context in
            let services = vehicle.sortedServices

            // --- Cover Page ---
            context.beginPage()
            let ctx = context.cgContext

            // White background
            ctx.setFillColor(slate50.cgColor)
            ctx.fill(pageBounds)

            // Top accent bar
            ctx.setFillColor(orange500.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: pageBounds.width, height: 6))

            // Vehicle photo
            if let ref = vehicle.coverImageReference,
               let img = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: ref).path) {
                let photoRect = CGRect(x: 32, y: 30, width: pageBounds.width - 64, height: 180)
                ctx.saveGState()
                ctx.addPath(UIBezierPath(roundedRect: photoRect, cornerRadius: 16).cgPath)
                ctx.clip()
                img.draw(in: photoRect, blendMode: .normal, alpha: 1)
                ctx.restoreGState()
            }

            let topOffset: CGFloat = vehicle.coverImageReference != nil ? 230 : 30

            // Badge
            let badgeRect = CGRect(x: 32, y: topOffset, width: 120, height: 26)
            ctx.setFillColor(orange500.withAlphaComponent(0.12).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: badgeRect, cornerRadius: 6).cgPath)
            ctx.fillPath()
            draw(text: "FOR SALE — SERVICE HISTORY", in: CGRect(x: 40, y: topOffset + 5, width: 110, height: 16),
                 font: .systemFont(ofSize: 8, weight: .bold), color: orange500)

            // Title
            draw(text: "\(vehicle.year) \(vehicle.make) \(vehicle.model)",
                 in: CGRect(x: 32, y: topOffset + 36, width: pageBounds.width - 64, height: 40),
                 font: .systemFont(ofSize: 28, weight: .bold), color: slate700)

            // Subtitle row
            var subtitleParts: [String] = []
            if !vehicle.licensePlate.isEmpty { subtitleParts.append(vehicle.licensePlate) }
            if !vehicle.vin.isEmpty { subtitleParts.append("VIN: \(vehicle.vin)") }
            subtitleParts.append(AppFormatters.mileage(vehicle.currentMileage))
            draw(text: subtitleParts.joined(separator: "  •  "),
                 in: CGRect(x: 32, y: topOffset + 82, width: pageBounds.width - 64, height: 22),
                 font: .systemFont(ofSize: 13, weight: .medium), color: slate500)

            // Divider
            ctx.setStrokeColor(slate100.cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 32, y: topOffset + 116))
            ctx.addLine(to: CGPoint(x: pageBounds.width - 32, y: topOffset + 116))
            ctx.strokePath()

            // Key stats row
            let statsY = topOffset + 132
            let statW = (pageBounds.width - 88) / 4.0
            drawResaleStat(ctx: ctx, title: "TOTAL SERVICES", value: "\(services.count)",
                           origin: CGPoint(x: 32, y: statsY), width: statW,
                           bg: slate100, textColor: slate700, accentColor: orange500)
            drawResaleStat(ctx: ctx, title: "TOTAL SPENT", value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode),
                           origin: CGPoint(x: 40 + statW, y: statsY), width: statW,
                           bg: slate100, textColor: slate700, accentColor: orange500)
            drawResaleStat(ctx: ctx, title: "LAST SERVICE", value: vehicle.latestService.map { AppFormatters.mediumDate.string(from: $0.date) } ?? "—",
                           origin: CGPoint(x: 48 + statW * 2, y: statsY), width: statW,
                           bg: slate100, textColor: slate700, accentColor: orange500)
            drawResaleStat(ctx: ctx, title: "DOCUMENTS", value: "\(vehicle.attachments.count)",
                           origin: CGPoint(x: 56 + statW * 3, y: statsY), width: statW,
                           bg: slate100, textColor: slate700, accentColor: orange500)

            // "Why buy with confidence" section
            let confY = statsY + 110
            draw(text: "COMPLETE MAINTENANCE RECORD", in: CGRect(x: 32, y: confY, width: 300, height: 18),
                 font: .systemFont(ofSize: 11, weight: .bold), color: orange500)

            let bullets = [
                "✓  Full service history documented in Car Service Passport",
                "✓  \(services.count) verified service \(services.count == 1 ? "entry" : "entries") on record",
                "✓  All costs transparently reported (\(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode)) total)",
                vehicle.latestService != nil ? "✓  Last serviced \(AppFormatters.mediumDate.string(from: vehicle.latestService!.date))" : "✓  Service history available",
            ]
            var bulletY = confY + 24
            for bullet in bullets {
                draw(text: bullet, in: CGRect(x: 36, y: bulletY, width: pageBounds.width - 72, height: 18),
                     font: .systemFont(ofSize: 12, weight: .regular), color: slate700)
                bulletY += 22
            }

            // Cost by category breakdown
            let catY = bulletY + 16
            draw(text: "COST BY CATEGORY", in: CGRect(x: 32, y: catY, width: 200, height: 18),
                 font: .systemFont(ofSize: 11, weight: .bold), color: orange500)

            let grouped = Dictionary(grouping: services, by: { $0.category })
            var catRowY = catY + 24
            for category in EntryCategory.allCases {
                guard let entries = grouped[category], !entries.isEmpty else { continue }
                let total = entries.reduce(0.0) { $0 + $1.price }
                draw(text: category.title, in: CGRect(x: 36, y: catRowY, width: 160, height: 18),
                     font: .systemFont(ofSize: 12), color: slate500)
                draw(text: AppFormatters.currency(total, code: vehicle.currencyCode),
                     in: CGRect(x: 200, y: catRowY, width: 160, height: 18),
                     font: .systemFont(ofSize: 12, weight: .semibold), color: slate700)
                catRowY += 20
            }

            // Footer
            let footerY = pageBounds.height - 40
            ctx.setStrokeColor(slate100.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: 32, y: footerY - 8))
            ctx.addLine(to: CGPoint(x: pageBounds.width - 32, y: footerY - 8))
            ctx.strokePath()

            let generatedDate = AppFormatters.mediumDate.string(from: .now)
            draw(text: "Generated by Car Service Passport on \(generatedDate)  •  All data entered by vehicle owner",
                 in: CGRect(x: 32, y: footerY, width: pageBounds.width - 64, height: 16),
                 font: .systemFont(ofSize: 9), color: slate500)

            // --- Service History Pages ---
            var currentIndex = 0
            while currentIndex < services.count {
                context.beginPage()
                currentIndex = renderResaleServicePage(in: context.cgContext, bounds: pageBounds,
                                                        vehicle: vehicle, services: services,
                                                        startIndex: currentIndex,
                                                        slate50: slate50, slate100: slate100,
                                                        slate500: slate500, slate700: slate700,
                                                        orange500: orange500, green600: green600)
            }
        }

        return outputURL
    }

    private func renderResaleServicePage(in ctx: CGContext, bounds: CGRect, vehicle: Vehicle,
                                          services: [ServiceEntry], startIndex: Int,
                                          slate50: UIColor, slate100: UIColor,
                                          slate500: UIColor, slate700: UIColor,
                                          orange500: UIColor, green600: UIColor) -> Int {
        ctx.setFillColor(slate50.cgColor)
        ctx.fill(bounds)
        ctx.setFillColor(orange500.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 6))

        draw(text: "\(vehicle.make) \(vehicle.model) — DETAILED SERVICE HISTORY".uppercased(),
             in: CGRect(x: 32, y: 24, width: bounds.width - 64, height: 20),
             font: .systemFont(ofSize: 11, weight: .bold), color: orange500)

        var currentY: CGFloat = 56
        var index = startIndex

        while index < services.count {
            let entry = services[index]
            let cardHeight: CGFloat = entry.notes.isEmpty ? 80 : 102

            if currentY + cardHeight > bounds.height - 48 { break }

            let cardRect = CGRect(x: 32, y: currentY, width: bounds.width - 64, height: cardHeight)
            ctx.setFillColor(slate100.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 10).cgPath)
            ctx.fillPath()

            // Left accent bar
            ctx.setFillColor(orange500.withAlphaComponent(0.5).cgColor)
            ctx.fill(CGRect(x: 32, y: currentY, width: 4, height: cardHeight))

            draw(text: entry.displayTitle,
                 in: CGRect(x: 48, y: currentY + 14, width: 260, height: 20),
                 font: .systemFont(ofSize: 14, weight: .bold), color: slate700)
            draw(text: AppFormatters.currency(entry.price, code: entry.currencyCode),
                 in: CGRect(x: bounds.width - 160, y: currentY + 14, width: 120, height: 20),
                 font: .systemFont(ofSize: 14, weight: .bold), color: slate700)
            draw(text: "\(AppFormatters.mediumDate.string(from: entry.date))  •  \(AppFormatters.mileage(entry.mileage))",
                 in: CGRect(x: 48, y: currentY + 36, width: bounds.width - 96, height: 16),
                 font: .systemFont(ofSize: 11), color: slate500)
            if !entry.workshopName.isEmpty {
                draw(text: entry.workshopName,
                     in: CGRect(x: 48, y: currentY + 54, width: bounds.width - 96, height: 16),
                     font: .systemFont(ofSize: 12, weight: .medium), color: slate500)
            }
            if !entry.notes.isEmpty {
                draw(text: String(entry.notes.prefix(120)),
                     in: CGRect(x: 48, y: currentY + 70, width: bounds.width - 96, height: 28),
                     font: .systemFont(ofSize: 11), color: slate500)
            }

            currentY += cardHeight + 10
            index += 1
        }

        // Page footer
        let footerY = bounds.height - 32
        draw(text: "Car Service Passport  •  \(vehicle.title)  •  Page \(index / 8 + 2)",
             in: CGRect(x: 32, y: footerY, width: bounds.width - 64, height: 14),
             font: .systemFont(ofSize: 9), color: slate500)

        return index
    }

    private func drawResaleStat(ctx: CGContext, title: String, value: String, origin: CGPoint, width: CGFloat,
                                 bg: UIColor, textColor: UIColor, accentColor: UIColor) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width - 4, height: 86)
        bg.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        draw(text: title, in: CGRect(x: rect.minX + 10, y: rect.minY + 12, width: rect.width - 20, height: 14),
             font: .systemFont(ofSize: 8, weight: .bold), color: accentColor)
        draw(text: value, in: CGRect(x: rect.minX + 10, y: rect.minY + 32, width: rect.width - 20, height: 36),
             font: .systemFont(ofSize: 14, weight: .bold), color: textColor)
    }

    func exportCSV(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-history.csv".replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var csvString = [
            "Date",
            "Service Type",
            "Mileage (km)",
            "Cost",
            "Currency",
            "Workshop",
            "Notes"
        ]
        .map(csvField)
        .joined(separator: ",")
        + "\n"

        for entry in vehicle.sortedServices {
            let row = [
                dateFormatter.string(from: entry.date),
                entry.displayTitle,
                String(entry.mileage),
                String(format: "%.2f", entry.price),
                entry.currencyCode,
                entry.workshopName,
                entry.notes.replacingOccurrences(of: "\n", with: " ")
            ]

            csvString += row.map(csvField).joined(separator: ",") + "\n"
        }

        try csvString.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
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
            ("Current Mileage", vehicle.currentMileageDisplayString),
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
