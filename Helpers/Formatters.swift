import Foundation

enum AppFormatters {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let compactNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func decimal(_ value: Double, digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }

    static func mileage(_ value: Int) -> String {
        let formatted = compactNumber.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) km"
    }

    static func currency(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(code)"
    }

    static let receiptFilename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
