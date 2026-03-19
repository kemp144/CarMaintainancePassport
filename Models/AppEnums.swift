import Foundation
import SwiftUI

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case oilChange
    case inspection
    case tires
    case brakes
    case battery
    case filters
    case airConditioning
    case repair
    case washDetailing
    case registration
    case insurance
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oilChange: return "Oil Change"
        case .inspection: return "Inspection"
        case .tires: return "Tires"
        case .brakes: return "Brakes"
        case .battery: return "Battery"
        case .filters: return "Filters"
        case .airConditioning: return "Air Conditioning"
        case .repair: return "Repair"
        case .washDetailing: return "Wash / Detailing"
        case .registration: return "Registration"
        case .insurance: return "Insurance"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .oilChange: return "drop.fill"
        case .inspection: return "checkmark.seal.fill"
        case .tires: return "circle.hexagongrid.fill"
        case .brakes: return "stop.circle.fill"
        case .battery: return "battery.100percent"
        case .filters: return "line.3.horizontal.decrease.circle.fill"
        case .airConditioning: return "wind"
        case .repair: return "wrench.and.screwdriver.fill"
        case .washDetailing: return "sparkles"
        case .registration: return "doc.text.fill"
        case .insurance: return "shield.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    var defaultCategory: EntryCategory {
        switch self {
        case .repair, .battery, .brakes:
            return .repair
        case .registration, .insurance:
            return .administration
        case .washDetailing:
            return .care
        default:
            return .maintenance
        }
    }

    var supportsReminderSuggestion: Bool {
        switch self {
        case .oilChange, .inspection, .tires, .brakes, .registration, .insurance:
            return true
        default:
            return false
        }
    }
}

enum EntryCategory: String, Codable, CaseIterable, Identifiable {
    case maintenance
    case repair
    case care
    case administration

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum AttachmentType: String, Codable, CaseIterable, Identifiable {
    case image
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return "Image"
        case .pdf: return "PDF"
        }
    }

    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        }
    }
}

enum DocumentVaultCategory: String, Codable, CaseIterable, Identifiable {
    case general
    case receipts
    case insurance
    case registration
    case warranty
    case inspection
    case title
    case roadside

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .receipts: return "Receipts"
        case .insurance: return "Insurance"
        case .registration: return "Registration"
        case .warranty: return "Warranty"
        case .inspection: return "Inspection"
        case .title: return "Vehicle Title"
        case .roadside: return "Roadside Assistance"
        }
    }

    var icon: String {
        switch self {
        case .general: return "doc.fill"
        case .receipts: return "doc.text.image.fill"
        case .insurance: return "shield.fill"
        case .registration: return "text.book.closed.fill"
        case .warranty: return "checkmark.seal.fill"
        case .inspection: return "magnifyingglass.circle.fill"
        case .title: return "star.fill"
        case .roadside: return "lifepreserver.fill"
        }
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case oilChange
    case inspection
    case tires
    case brakes
    case registration
    case insurance
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oilChange: return "Oil Change"
        case .inspection: return "Inspection"
        case .tires: return "Tires"
        case .brakes: return "Brakes"
        case .registration: return "Registration"
        case .insurance: return "Insurance"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .oilChange: return "drop.fill"
        case .inspection: return "checkmark.seal.fill"
        case .tires: return "circle.hexagongrid.fill"
        case .brakes: return "stop.circle.fill"
        case .registration: return "doc.text.fill"
        case .insurance: return "shield.fill"
        case .custom: return "bell.fill"
        }
    }

    init(serviceType: ServiceType) {
        switch serviceType {
        case .oilChange: self = .oilChange
        case .inspection: self = .inspection
        case .tires: self = .tires
        case .brakes: self = .brakes
        case .registration: self = .registration
        case .insurance: self = .insurance
        default: self = .custom
        }
    }
}

enum NotificationTiming: String, Codable, CaseIterable, Identifiable {
    case onTheDay
    case sevenDaysBefore
    case thirtyDaysBefore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onTheDay: return "On the day"
        case .sevenDaysBefore: return "7 days before"
        case .thirtyDaysBefore: return "30 days before"
        }
    }

    var dayOffset: Int {
        switch self {
        case .onTheDay: return 0
        case .sevenDaysBefore: return 7
        case .thirtyDaysBefore: return 30
        }
    }
}

enum ReminderStatus: String, Codable, CaseIterable, Identifiable {
    case overdue
    case dueSoon
    case upcoming
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .dueSoon: return "Due Soon"
        case .upcoming: return "Upcoming"
        case .disabled: return "Disabled"
        }
    }

    var tint: Color {
        switch self {
        case .overdue: return AppTheme.error
        case .dueSoon: return AppTheme.warning
        case .upcoming: return AppTheme.accent
        case .disabled: return AppTheme.secondaryText
        }
    }
}

enum FuelEntryType: String, Codable, CaseIterable, Identifiable {
    case initialTank
    case fullFillUp
    case partialFillUp
    case missedFillUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .initialTank: return "Initial Tank"
        case .fullFillUp: return "Full Fill-up"
        case .partialFillUp: return "Partial Fill-up"
        case .missedFillUp: return "Missed Fill-up"
        }
    }

    var shortTitle: String {
        switch self {
        case .initialTank: return "Initial"
        case .fullFillUp: return "Full"
        case .partialFillUp: return "Partial"
        case .missedFillUp: return "Missed"
        }
    }

    var icon: String {
        switch self {
        case .initialTank: return "flag.fill"
        case .fullFillUp: return "fuelpump.fill"
        case .partialFillUp: return "fuelpump"
        case .missedFillUp: return "exclamationmark.triangle.fill"
        }
    }

    var defaultIsFullTank: Bool {
        switch self {
        case .initialTank, .fullFillUp:
            return true
        case .partialFillUp, .missedFillUp:
            return false
        }
    }

    var requiresFuelAmounts: Bool {
        switch self {
        case .fullFillUp, .partialFillUp:
            return true
        case .initialTank, .missedFillUp:
            return false
        }
    }

    var helperText: String {
        switch self {
        case .initialTank:
            return "Creates the starting point for accurate tracking."
        case .fullFillUp:
            return "Use when the tank is filled completely."
        case .partialFillUp:
            return "Adds fuel without closing a full-to-full cycle yet."
        case .missedFillUp:
            return "Marks the sequence as incomplete until the next full fill-up."
        }
    }
}

enum FuelLogPeriod: String, CaseIterable, Identifiable {
    case currentTank
    case days30
    case days90
    case months12
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentTank: return "Current Tank"
        case .days30: return "30 Days"
        case .days90: return "90 Days"
        case .months12: return "12 Months"
        case .allTime: return "All Time"
        }
    }

    var shortTitle: String {
        switch self {
        case .currentTank: return "Tank"
        case .days30: return "30D"
        case .days90: return "90D"
        case .months12: return "12M"
        case .allTime: return "All"
        }
    }
}

enum FuelChartMetric: String, CaseIterable, Identifiable {
    case spend
    case consumption
    case price

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spend: return "Spend"
        case .consumption: return "Consumption"
        case .price: return "Price"
        }
    }
}

enum CurrencyPreset: String, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case chf = "CHF"

    var id: String { rawValue }
}
