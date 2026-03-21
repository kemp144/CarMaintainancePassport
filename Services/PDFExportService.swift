import Foundation
import UIKit

struct PDFExportService {
    static let shared = PDFExportService()

    // MARK: - Service Passport

    func exportPassport(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-service-passport.pdf"
            .replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: outputURL) { context in
            let services = vehicle.sortedServices

            context.beginPage()
            renderPassportCover(in: context.cgContext, bounds: pageBounds, vehicle: vehicle)

            var currentIndex = 0
            var pageNumber = 2
            while currentIndex < services.count {
                context.beginPage()
                currentIndex = renderPassportServicePage(
                    in: context.cgContext, bounds: pageBounds,
                    vehicle: vehicle, services: services,
                    startIndex: currentIndex, pageNumber: pageNumber
                )
                pageNumber += 1
            }
        }

        return outputURL
    }

    private func renderPassportCover(in ctx: CGContext, bounds: CGRect, vehicle: Vehicle) {
        let orange500 = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
        let slate400  = UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1)
        let slate900  = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        let slate950  = UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1)

        // Full dark background
        ctx.setFillColor(slate950.cgColor)
        ctx.fill(bounds)

        // Top accent bar
        ctx.setFillColor(orange500.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 5))

        // Hero card
        let heroRect = CGRect(x: 32, y: 14, width: bounds.width - 64, height: 236)
        ctx.saveGState()
        let space = CGColorSpaceCreateDeviceRGB()
        let heroColors = [slate900.cgColor, slate950.cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: space, colors: heroColors, locations: [0, 1]) {
            ctx.addPath(UIBezierPath(roundedRect: heroRect, cornerRadius: 20).cgPath)
            ctx.clip()
            ctx.drawLinearGradient(grad,
                start: CGPoint(x: heroRect.midX, y: heroRect.minY),
                end:   CGPoint(x: heroRect.midX, y: heroRect.maxY), options: [])
        }
        if let ref = vehicle.coverImageReference,
           let img = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: ref).path) {
            img.draw(in: heroRect, blendMode: .normal, alpha: 0.22)
        }
        ctx.restoreGState()

        // Badge pill: "CAR SERVICE PASSPORT"
        let badgeRect = CGRect(x: 52, y: 34, width: 178, height: 20)
        ctx.saveGState()
        ctx.setFillColor(orange500.withAlphaComponent(0.18).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: badgeRect, cornerRadius: 5).cgPath)
        ctx.fillPath()
        ctx.restoreGState()
        draw(text: "CAR SERVICE PASSPORT",
             in: CGRect(x: 60, y: 38, width: 162, height: 13),
             font: .systemFont(ofSize: 9, weight: .bold), color: orange500)

        // Vehicle title — wrapped, allows 2 lines for long names
        drawWrapped(text: vehicle.title,
                    in: CGRect(x: 52, y: 64, width: bounds.width - 88, height: 72),
                    font: .systemFont(ofSize: 26, weight: .bold), color: .white)

        // Year · plate subtitle
        let subtitleParts = [
            vehicle.year > 0 ? String(vehicle.year) : nil,
            vehicle.licensePlate.isEmpty ? nil : vehicle.licensePlate
        ].compactMap { $0 }
        let subtitleText = subtitleParts.isEmpty ? "" : subtitleParts.joined(separator: "  ·  ")
        draw(text: subtitleText,
             in: CGRect(x: 52, y: 144, width: bounds.width - 88, height: 20),
             font: .systemFont(ofSize: 13, weight: .medium), color: slate400)

        // "Official Maintenance Record" caption
        draw(text: "Official Maintenance Record",
             in: CGRect(x: 52, y: 170, width: bounds.width - 88, height: 18),
             font: .systemFont(ofSize: 11, weight: .medium),
             color: UIColor.white.withAlphaComponent(0.45))

        // VIN line if present
        if !vehicle.vin.isEmpty {
            draw(text: "VIN  \(vehicle.vin)",
                 in: CGRect(x: 52, y: 194, width: bounds.width - 88, height: 16),
                 font: .systemFont(ofSize: 9.5, weight: .regular), color: slate400.withAlphaComponent(0.7))
        }

        // Stats row — 3 dark cards
        let statsY: CGFloat = 262
        let statW = (bounds.width - 88) / 3.0
        drawPassportStat(ctx: ctx, title: "TOTAL SPENT",
                         value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode),
                         origin: CGPoint(x: 32, y: statsY), width: statW,
                         orange500: orange500, slate400: slate400, slate900: slate900)
        drawPassportStat(ctx: ctx, title: "SERVICES",
                         value: "\(vehicle.serviceEntries.count)",
                         origin: CGPoint(x: 44 + statW, y: statsY), width: statW,
                         orange500: orange500, slate400: slate400, slate900: slate900)
        drawPassportStat(ctx: ctx, title: "DOCUMENTS",
                         value: "\(vehicle.attachments.count)",
                         origin: CGPoint(x: 56 + statW * 2, y: statsY), width: statW,
                         orange500: orange500, slate400: slate400, slate900: slate900)

        // Section: Vehicle Specifications
        var currentY = statsY + 104
        draw(text: "VEHICLE SPECIFICATIONS",
             in: CGRect(x: 32, y: currentY, width: bounds.width - 64, height: 18),
             font: .systemFont(ofSize: 11, weight: .bold), color: orange500)
        currentY += 26

        let details: [(String, String)] = [
            ("Current Mileage", vehicle.currentMileageDisplayString),
            ("License Plate",   vehicle.licensePlate.isEmpty ? "Not recorded" : vehicle.licensePlate),
            ("VIN",             vehicle.vin.isEmpty ? "Not recorded" : vehicle.vin),
            ("Purchase Date",   vehicle.purchaseDate.map(AppFormatters.mediumDate.string) ?? "Not recorded"),
            ("Purchase Price",  vehicle.purchasePrice.map { AppFormatters.currency($0, code: vehicle.currencyCode) } ?? "Not recorded"),
        ]

        for detail in details {
            draw(text: detail.0,
                 in: CGRect(x: 32, y: currentY, width: 150, height: 18),
                 font: .systemFont(ofSize: 11, weight: .medium), color: slate400)
            draw(text: detail.1,
                 in: CGRect(x: 192, y: currentY - 1, width: bounds.width - 224, height: 20),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .white)
            ctx.saveGState()
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to:    CGPoint(x: 32, y: currentY + 22))
            ctx.addLine(to: CGPoint(x: bounds.width - 32, y: currentY + 22))
            ctx.strokePath()
            ctx.restoreGState()
            currentY += 30
        }

        // Subtle divider before summary
        currentY += 8
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to:    CGPoint(x: 32, y: currentY))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: currentY))
        ctx.strokePath()
        ctx.restoreGState()
        currentY += 16

        // Section: Service Summary
        draw(text: "SERVICE SUMMARY",
             in: CGRect(x: 32, y: currentY, width: bounds.width - 64, height: 18),
             font: .systemFont(ofSize: 11, weight: .bold), color: orange500)
        currentY += 22

        let summaryText: String
        let serviceCount = vehicle.serviceEntries.count
        if serviceCount == 0 {
            summaryText = "No service entries have been recorded for this vehicle yet."
        } else {
            let lastDateStr = vehicle.latestServiceDate.map { AppFormatters.mediumDate.string(from: $0) } ?? "unknown date"
            summaryText = "This document contains the verified service history for this vehicle as recorded in the Car Service Passport app. It includes \(serviceCount) service \(serviceCount == 1 ? "entry" : "entries") totalling \(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode)), with the most recent service on \(lastDateStr)."
        }
        drawWrapped(text: summaryText,
                    in: CGRect(x: 32, y: currentY, width: bounds.width - 64, height: 72),
                    font: .systemFont(ofSize: 11, weight: .regular), color: slate400)

        // Page footer
        let footerY = bounds.height - 28
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to:    CGPoint(x: 32, y: footerY - 8))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: footerY - 8))
        ctx.strokePath()
        ctx.restoreGState()
        draw(text: "Car Service Passport  ·  \(vehicle.title)  ·  Page 1",
             in: CGRect(x: 32, y: footerY, width: bounds.width - 64, height: 14),
             font: .systemFont(ofSize: 9), color: slate400.withAlphaComponent(0.6))
    }

    private func renderPassportServicePage(in ctx: CGContext, bounds: CGRect,
                                            vehicle: Vehicle, services: [ServiceEntry],
                                            startIndex: Int, pageNumber: Int) -> Int {
        let orange500 = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
        let slate400  = UIColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 1)
        let slate900  = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        let slate950  = UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1)

        // Background + accent bar
        ctx.setFillColor(slate950.cgColor)
        ctx.fill(bounds)
        ctx.setFillColor(orange500.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 5))

        // Page header
        draw(text: vehicle.title.uppercased(),
             in: CGRect(x: 32, y: 22, width: bounds.width - 64, height: 16),
             font: .systemFont(ofSize: 10, weight: .bold), color: orange500)
        draw(text: "DETAILED SERVICE HISTORY",
             in: CGRect(x: 32, y: 40, width: bounds.width - 64, height: 26),
             font: .systemFont(ofSize: 18, weight: .bold), color: .white)

        var currentY: CGFloat = 82
        var index = startIndex

        while index < services.count {
            let entry = services[index]

            // Calculate card height dynamically
            var cardHeight: CGFloat = 80
            if !entry.workshopName.isEmpty { cardHeight += 20 }
            if !entry.notes.isEmpty        { cardHeight += 38 }

            if currentY + cardHeight > bounds.height - 44 { break }

            // Card background
            let cardRect = CGRect(x: 32, y: currentY, width: bounds.width - 64, height: cardHeight)
            ctx.saveGState()
            ctx.setFillColor(slate900.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 14).cgPath)
            ctx.fillPath()
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.09).cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 14).cgPath)
            ctx.strokePath()
            // Left accent bar
            ctx.setFillColor(orange500.withAlphaComponent(0.55).cgColor)
            ctx.fill(CGRect(x: 32, y: currentY + 12, width: 3, height: cardHeight - 24))
            ctx.restoreGState()

            // Title + price
            draw(text: entry.displayTitle,
                 in: CGRect(x: 50, y: currentY + 16, width: 280, height: 22),
                 font: .systemFont(ofSize: 15, weight: .bold), color: .white)
            draw(text: AppFormatters.currency(entry.price, code: entry.currencyCode),
                 in: CGRect(x: bounds.width - 168, y: currentY + 16, width: 128, height: 22),
                 font: .systemFont(ofSize: 15, weight: .bold), color: .white)

            // Date + mileage
            draw(text: "\(AppFormatters.mediumDate.string(from: entry.date))  ·  \(AppFormatters.mileage(entry.mileage))",
                 in: CGRect(x: 50, y: currentY + 42, width: bounds.width - 114, height: 16),
                 font: .systemFont(ofSize: 11, weight: .medium), color: slate400)

            var lineY = currentY + 62
            if !entry.workshopName.isEmpty {
                draw(text: entry.workshopName,
                     in: CGRect(x: 50, y: lineY, width: bounds.width - 114, height: 17),
                     font: .systemFont(ofSize: 11.5, weight: .semibold),
                     color: UIColor.white.withAlphaComponent(0.85))
                lineY += 20
            }
            if !entry.notes.isEmpty {
                drawWrapped(text: entry.notes,
                            in: CGRect(x: 50, y: lineY, width: bounds.width - 114, height: 36),
                            font: .systemFont(ofSize: 11), color: slate400)
            }

            currentY += cardHeight + 12
            index += 1
        }

        // Page footer
        let footerY = bounds.height - 28
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to:    CGPoint(x: 32, y: footerY - 8))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: footerY - 8))
        ctx.strokePath()
        ctx.restoreGState()
        draw(text: "Car Service Passport  ·  \(vehicle.title)  ·  Page \(pageNumber)",
             in: CGRect(x: 32, y: footerY, width: bounds.width - 64, height: 14),
             font: .systemFont(ofSize: 9), color: slate400.withAlphaComponent(0.6))

        return index
    }

    private func drawPassportStat(ctx: CGContext, title: String, value: String,
                                   origin: CGPoint, width: CGFloat,
                                   orange500: UIColor, slate400: UIColor, slate900: UIColor) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width - 6, height: 88)
        ctx.saveGState()
        ctx.setFillColor(slate900.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 14).cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.09).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 14).cgPath)
        ctx.strokePath()
        ctx.restoreGState()
        draw(text: title,
             in: CGRect(x: rect.minX + 14, y: rect.minY + 16, width: rect.width - 28, height: 14),
             font: .systemFont(ofSize: 9, weight: .bold), color: slate400)
        draw(text: value,
             in: CGRect(x: rect.minX + 14, y: rect.minY + 36, width: rect.width - 28, height: 32),
             font: .systemFont(ofSize: 17, weight: .bold), color: .white)
    }

    // MARK: - Resale Report

    func exportResaleReport(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-for-sale.pdf"
            .replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let slate50   = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1)
        let slate100  = UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)
        let slate500  = UIColor(red: 0.40, green: 0.47, blue: 0.56, alpha: 1)
        let slate700  = UIColor(red: 0.20, green: 0.26, blue: 0.36, alpha: 1)
        let orange500 = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
        let green600  = UIColor(red: 0.09, green: 0.67, blue: 0.27, alpha: 1)

        try renderer.writePDF(to: outputURL) { context in
            let services = vehicle.sortedServices

            // Cover page
            context.beginPage()
            renderResaleCover(in: context.cgContext, bounds: pageBounds,
                              vehicle: vehicle, services: services,
                              slate50: slate50, slate100: slate100,
                              slate500: slate500, slate700: slate700, orange500: orange500)

            var currentIndex = 0
            var pageNumber = 2
            while currentIndex < services.count {
                context.beginPage()
                currentIndex = renderResaleServicePage(
                    in: context.cgContext, bounds: pageBounds,
                    vehicle: vehicle, services: services,
                    startIndex: currentIndex, pageNumber: pageNumber,
                    slate50: slate50, slate100: slate100,
                    slate500: slate500, slate700: slate700,
                    orange500: orange500, green600: green600
                )
                pageNumber += 1
            }
        }

        return outputURL
    }

    private func renderResaleCover(in ctx: CGContext, bounds: CGRect,
                                    vehicle: Vehicle, services: [ServiceEntry],
                                    slate50: UIColor, slate100: UIColor,
                                    slate500: UIColor, slate700: UIColor, orange500: UIColor) {
        // Background
        ctx.setFillColor(slate50.cgColor)
        ctx.fill(bounds)

        // Top accent bar
        ctx.setFillColor(orange500.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 6))

        // Vehicle photo
        let hasPhoto = vehicle.coverImageReference != nil
        if let ref = vehicle.coverImageReference,
           let img = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: ref).path) {
            let photoRect = CGRect(x: 32, y: 22, width: bounds.width - 64, height: 178)
            ctx.saveGState()
            ctx.addPath(UIBezierPath(roundedRect: photoRect, cornerRadius: 14).cgPath)
            ctx.clip()
            img.draw(in: photoRect, blendMode: .normal, alpha: 1)
            ctx.restoreGState()
        }

        let topOffset: CGFloat = hasPhoto ? 218 : 22

        // Badge
        let badgeRect = CGRect(x: 32, y: topOffset, width: 148, height: 22)
        ctx.saveGState()
        ctx.setFillColor(orange500.withAlphaComponent(0.12).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: badgeRect, cornerRadius: 5).cgPath)
        ctx.fillPath()
        ctx.restoreGState()
        draw(text: "FOR SALE — SERVICE HISTORY",
             in: CGRect(x: 40, y: topOffset + 5, width: 134, height: 13),
             font: .systemFont(ofSize: 8, weight: .bold), color: orange500)

        // Vehicle title — wrapped for long names
        drawWrapped(text: "\(vehicle.year) \(vehicle.make) \(vehicle.model)",
                    in: CGRect(x: 32, y: topOffset + 32, width: bounds.width - 64, height: 64),
                    font: .systemFont(ofSize: 26, weight: .bold), color: slate700)

        // Subtitle: plate + VIN + mileage
        var subtitleParts: [String] = []
        if !vehicle.licensePlate.isEmpty { subtitleParts.append(vehicle.licensePlate) }
        if !vehicle.vin.isEmpty          { subtitleParts.append("VIN: \(vehicle.vin)") }
        subtitleParts.append(AppFormatters.mileage(vehicle.currentMileage))
        drawWrapped(text: subtitleParts.joined(separator: "  •  "),
                    in: CGRect(x: 32, y: topOffset + 100, width: bounds.width - 64, height: 32),
                    font: .systemFont(ofSize: 12, weight: .medium), color: slate500)

        // Divider
        let divY = topOffset + 140
        ctx.setStrokeColor(slate100.cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to:    CGPoint(x: 32, y: divY))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: divY))
        ctx.strokePath()

        // Stats row (4 cards)
        let statsY = divY + 14
        let statW = (bounds.width - 88) / 4.0
        drawResaleStat(ctx: ctx, title: "TOTAL SERVICES",
                       value: "\(services.count)",
                       origin: CGPoint(x: 32, y: statsY), width: statW,
                       bg: slate100, textColor: slate700, accentColor: orange500)
        drawResaleStat(ctx: ctx, title: "TOTAL SPENT",
                       value: AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode),
                       origin: CGPoint(x: 40 + statW, y: statsY), width: statW,
                       bg: slate100, textColor: slate700, accentColor: orange500)
        drawResaleStat(ctx: ctx, title: "LAST SERVICE",
                       value: vehicle.latestService.map { AppFormatters.mediumDate.string(from: $0.date) } ?? "—",
                       origin: CGPoint(x: 48 + statW * 2, y: statsY), width: statW,
                       bg: slate100, textColor: slate700, accentColor: orange500)
        drawResaleStat(ctx: ctx, title: "DOCUMENTS",
                       value: "\(vehicle.attachments.count)",
                       origin: CGPoint(x: 56 + statW * 3, y: statsY), width: statW,
                       bg: slate100, textColor: slate700, accentColor: orange500)

        // "Complete Maintenance Record" section
        var currentY = statsY + 104
        draw(text: "COMPLETE MAINTENANCE RECORD",
             in: CGRect(x: 32, y: currentY, width: 300, height: 16),
             font: .systemFont(ofSize: 10.5, weight: .bold), color: orange500)
        currentY += 22

        let bullets: [String]
        if services.isEmpty {
            bullets = [
                "✓  Service history available in Car Service Passport",
                "✓  All future records will be documented and verifiable",
            ]
        } else {
            bullets = [
                "✓  Full service history documented in Car Service Passport",
                "✓  \(services.count) verified service \(services.count == 1 ? "entry" : "entries") on record",
                "✓  All costs transparently reported (\(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode)) total)",
                vehicle.latestService.map { "✓  Last serviced \(AppFormatters.mediumDate.string(from: $0.date))" }
                    ?? "✓  Service history documented",
            ]
        }
        for bullet in bullets {
            draw(text: bullet,
                 in: CGRect(x: 36, y: currentY, width: bounds.width - 72, height: 17),
                 font: .systemFont(ofSize: 11.5, weight: .regular), color: slate700)
            currentY += 21
        }

        // Cost by category
        currentY += 10
        draw(text: "COST BY CATEGORY",
             in: CGRect(x: 32, y: currentY, width: 200, height: 16),
             font: .systemFont(ofSize: 10.5, weight: .bold), color: orange500)
        currentY += 20

        let grouped = Dictionary(grouping: services, by: { $0.category })
        for category in EntryCategory.allCases {
            guard let entries = grouped[category], !entries.isEmpty else { continue }
            let total = entries.reduce(0.0) { $0 + $1.price }
            draw(text: category.title,
                 in: CGRect(x: 36, y: currentY, width: 180, height: 17),
                 font: .systemFont(ofSize: 11.5), color: slate500)
            draw(text: AppFormatters.currency(total, code: vehicle.currencyCode),
                 in: CGRect(x: 220, y: currentY, width: 160, height: 17),
                 font: .systemFont(ofSize: 11.5, weight: .semibold), color: slate700)
            currentY += 19
        }

        // Footer
        let footerY = bounds.height - 36
        ctx.setStrokeColor(slate100.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to:    CGPoint(x: 32, y: footerY - 8))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: footerY - 8))
        ctx.strokePath()
        draw(text: "Generated by Car Service Passport on \(AppFormatters.mediumDate.string(from: .now))  ·  All data entered by vehicle owner",
             in: CGRect(x: 32, y: footerY, width: bounds.width - 64, height: 14),
             font: .systemFont(ofSize: 9), color: slate500)
    }

    private func renderResaleServicePage(in ctx: CGContext, bounds: CGRect,
                                          vehicle: Vehicle, services: [ServiceEntry],
                                          startIndex: Int, pageNumber: Int,
                                          slate50: UIColor, slate100: UIColor,
                                          slate500: UIColor, slate700: UIColor,
                                          orange500: UIColor, green600: UIColor) -> Int {
        ctx.setFillColor(slate50.cgColor)
        ctx.fill(bounds)
        ctx.setFillColor(orange500.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 6))

        draw(text: "\(vehicle.make) \(vehicle.model) — DETAILED SERVICE HISTORY".uppercased(),
             in: CGRect(x: 32, y: 22, width: bounds.width - 64, height: 18),
             font: .systemFont(ofSize: 10.5, weight: .bold), color: orange500)

        var currentY: CGFloat = 52
        var index = startIndex

        while index < services.count {
            let entry = services[index]

            // Dynamic card height
            var cardHeight: CGFloat = 72
            if !entry.workshopName.isEmpty { cardHeight += 18 }
            let notesLineCount = entry.notes.isEmpty ? 0 : min(3, Int(ceil(Double(entry.notes.count) / 70.0)))
            if notesLineCount > 0 { cardHeight += CGFloat(notesLineCount) * 15 + 4 }

            if currentY + cardHeight > bounds.height - 44 { break }

            let cardRect = CGRect(x: 32, y: currentY, width: bounds.width - 64, height: cardHeight)
            ctx.setFillColor(slate100.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 10).cgPath)
            ctx.fillPath()
            ctx.setFillColor(orange500.withAlphaComponent(0.45).cgColor)
            ctx.fill(CGRect(x: 32, y: currentY, width: 4, height: cardHeight))

            draw(text: entry.displayTitle,
                 in: CGRect(x: 48, y: currentY + 12, width: 272, height: 20),
                 font: .systemFont(ofSize: 13.5, weight: .bold), color: slate700)
            draw(text: AppFormatters.currency(entry.price, code: entry.currencyCode),
                 in: CGRect(x: bounds.width - 152, y: currentY + 12, width: 112, height: 20),
                 font: .systemFont(ofSize: 13.5, weight: .bold), color: slate700)
            draw(text: "\(AppFormatters.mediumDate.string(from: entry.date))  ·  \(AppFormatters.mileage(entry.mileage))",
                 in: CGRect(x: 48, y: currentY + 34, width: bounds.width - 100, height: 16),
                 font: .systemFont(ofSize: 11), color: slate500)

            var lineY = currentY + 52
            if !entry.workshopName.isEmpty {
                draw(text: entry.workshopName,
                     in: CGRect(x: 48, y: lineY, width: bounds.width - 100, height: 16),
                     font: .systemFont(ofSize: 11, weight: .medium), color: slate500)
                lineY += 18
            }
            if !entry.notes.isEmpty {
                drawWrapped(text: entry.notes,
                            in: CGRect(x: 48, y: lineY, width: bounds.width - 100, height: CGFloat(notesLineCount) * 15 + 4),
                            font: .systemFont(ofSize: 11), color: slate500)
            }

            currentY += cardHeight + 10
            index += 1
        }

        // Page footer
        let footerY = bounds.height - 30
        ctx.setStrokeColor(slate100.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to:    CGPoint(x: 32, y: footerY - 8))
        ctx.addLine(to: CGPoint(x: bounds.width - 32, y: footerY - 8))
        ctx.strokePath()
        draw(text: "Car Service Passport  ·  \(vehicle.title)  ·  Page \(pageNumber)",
             in: CGRect(x: 32, y: footerY, width: bounds.width - 64, height: 14),
             font: .systemFont(ofSize: 9), color: slate500)

        return index
    }

    private func drawResaleStat(ctx: CGContext, title: String, value: String,
                                 origin: CGPoint, width: CGFloat,
                                 bg: UIColor, textColor: UIColor, accentColor: UIColor) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width - 4, height: 82)
        bg.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        draw(text: title,
             in: CGRect(x: rect.minX + 10, y: rect.minY + 11, width: rect.width - 20, height: 13),
             font: .systemFont(ofSize: 8, weight: .bold), color: accentColor)
        drawWrapped(text: value,
                    in: CGRect(x: rect.minX + 10, y: rect.minY + 28, width: rect.width - 20, height: 44),
                    font: .systemFont(ofSize: 13, weight: .bold), color: textColor)
    }

    // MARK: - CSV

    func exportCSV(for vehicle: Vehicle) throws -> URL {
        let filename = "\(vehicle.make)-\(vehicle.model)-history.csv"
            .replacingOccurrences(of: " ", with: "-")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let mileageHeader = "Mileage (\(UnitSettings.currentDistanceUnit.shortTitle))"

        var csvString = ["Date", "Service Type", mileageHeader, "Cost", "Currency", "Workshop", "Notes"]
            .map(csvField)
            .joined(separator: ",") + "\n"

        for entry in vehicle.sortedServices {
            let row = [
                dateFormatter.string(from: entry.date),
                entry.displayTitle,
                UnitFormatter.distanceValue(Double(entry.mileage)),
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

    // MARK: - Drawing helpers

    /// Single-line draw — truncates at tail. Use for labels, titles, and short values.
    private func draw(text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.minimumLineHeight = font.pointSize * 1.14
        paragraph.maximumLineHeight = font.pointSize * 1.24
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }

    /// Multi-line draw — wraps by word. Use for vehicle names, notes, and paragraph text.
    private func drawWrapped(text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        text.draw(in: rect, withAttributes: attributes)
    }
}
