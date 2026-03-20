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
        UnitFormatter.distance(Double(value))
    }

    static func fuelVolume(_ value: Double) -> String {
        UnitFormatter.fuelVolume(value)
    }

    static func consumption(_ value: Double) -> String {
        UnitFormatter.consumption(value)
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

enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometers
    case miles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    var shortTitle: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }
}

enum FuelVolumeUnit: String, CaseIterable, Identifiable {
    case liters
    case gallons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liters: return "Liters"
        case .gallons: return "Gallons"
        }
    }

    var shortTitle: String {
        switch self {
        case .liters: return "L"
        case .gallons: return "gal"
        }
    }
}

enum ConsumptionUnit: String, CaseIterable, Identifiable {
    case litersPer100Kilometers
    case mpgUS
    case mpgUK
    case kilometersPerLiter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .litersPer100Kilometers: return "L/100 km"
        case .mpgUS: return "mpg (US)"
        case .mpgUK: return "mpg (UK)"
        case .kilometersPerLiter: return "km/L"
        }
    }
}

struct UnitProfile: Equatable {
    var distanceUnit: DistanceUnit
    var fuelVolumeUnit: FuelVolumeUnit
    var consumptionUnit: ConsumptionUnit

    var summary: String {
        "\(distanceUnit.title) · \(fuelVolumeUnit.title) · \(consumptionUnit.title)"
    }

    static let metric = UnitProfile(distanceUnit: .kilometers, fuelVolumeUnit: .liters, consumptionUnit: .litersPer100Kilometers)
    static let imperialUS = UnitProfile(distanceUnit: .miles, fuelVolumeUnit: .gallons, consumptionUnit: .mpgUS)
    static let imperialUK = UnitProfile(distanceUnit: .miles, fuelVolumeUnit: .gallons, consumptionUnit: .mpgUK)
}

enum UnitSettings {
    static let useSystemDefaultKey = "settings.units.useSystemDefault"
    static let distanceUnitKey = "settings.units.distanceUnit"
    static let fuelVolumeUnitKey = "settings.units.fuelVolumeUnit"
    static let consumptionUnitKey = "settings.units.consumptionUnit"

    static func registerDefaultValues(for locale: Locale = .autoupdatingCurrent) {
        let profile = suggestedProfile(for: locale)
        UserDefaults.standard.register(defaults: [
            useSystemDefaultKey: true,
            distanceUnitKey: profile.distanceUnit.rawValue,
            fuelVolumeUnitKey: profile.fuelVolumeUnit.rawValue,
            consumptionUnitKey: profile.consumptionUnit.rawValue
        ])
    }

    static func suggestedProfile(for locale: Locale = .autoupdatingCurrent) -> UnitProfile {
        let region = locale.region?.identifier.uppercased()

        switch region {
        case "US", "LR", "MM":
            return .imperialUS
        case "GB":
            return .imperialUK
        default:
            return .metric
        }
    }

    static func currentProfile(for defaults: UserDefaults = .standard, locale: Locale = .autoupdatingCurrent) -> UnitProfile {
        let useSystemDefault = defaults.object(forKey: useSystemDefaultKey) as? Bool ?? true
        return useSystemDefault ? suggestedProfile(for: locale) : storedProfile(for: defaults, locale: locale)
    }

    static func storedProfile(for defaults: UserDefaults = .standard, locale: Locale = .autoupdatingCurrent) -> UnitProfile {
        let fallback = suggestedProfile(for: locale)
        return UnitProfile(
            distanceUnit: DistanceUnit(rawValue: defaults.string(forKey: distanceUnitKey) ?? fallback.distanceUnit.rawValue) ?? fallback.distanceUnit,
            fuelVolumeUnit: FuelVolumeUnit(rawValue: defaults.string(forKey: fuelVolumeUnitKey) ?? fallback.fuelVolumeUnit.rawValue) ?? fallback.fuelVolumeUnit,
            consumptionUnit: ConsumptionUnit(rawValue: defaults.string(forKey: consumptionUnitKey) ?? fallback.consumptionUnit.rawValue) ?? fallback.consumptionUnit
        )
    }

    static var current: UnitProfile {
        currentProfile()
    }

    static var currentDistanceUnit: DistanceUnit { current.distanceUnit }
    static var currentFuelVolumeUnit: FuelVolumeUnit { current.fuelVolumeUnit }
    static var currentConsumptionUnit: ConsumptionUnit { current.consumptionUnit }
}

enum UnitConverter {
    static let kilometersPerMile = 1.609_344
    static let litersPerUSGallon = 3.785_411_784
    static let litersPerImperialGallon = 4.546_09
    static let litersPer100KmPerMpgUS = 235.214_583
    static let litersPer100KmPerMpgUK = 282.480_936_3

    static func kilometersToMiles(_ kilometers: Double) -> Double {
        kilometers / kilometersPerMile
    }

    static func milesToKilometers(_ miles: Double) -> Double {
        miles * kilometersPerMile
    }

    static func litersPer100KmToMpgUS(_ litersPer100Km: Double) -> Double {
        litersPer100KmPerMpgUS / litersPer100Km
    }

    static func litersPer100KmToMpgUK(_ litersPer100Km: Double) -> Double {
        litersPer100KmPerMpgUK / litersPer100Km
    }

    static func litersPer100KmToKilometersPerLiter(_ litersPer100Km: Double) -> Double {
        guard litersPer100Km > 0 else { return 0 }
        return 100 / litersPer100Km
    }
}

enum UnitFormatter {
    private static func gallonStyle(for consumptionUnit: ConsumptionUnit = UnitSettings.currentConsumptionUnit) -> Double {
        consumptionUnit == .mpgUK ? UnitConverter.litersPerImperialGallon : UnitConverter.litersPerUSGallon
    }

    static func distance(_ kilometers: Double, unit: DistanceUnit = UnitSettings.currentDistanceUnit, digits: Int = 0) -> String {
        let value = unit == .miles ? UnitConverter.kilometersToMiles(kilometers) : kilometers
        return "\(formatted(value, digits: digits)) \(unit.shortTitle)"
    }

    static func distanceValue(_ kilometers: Double, unit: DistanceUnit = UnitSettings.currentDistanceUnit, digits: Int = 0) -> String {
        let value = unit == .miles ? UnitConverter.kilometersToMiles(kilometers) : kilometers
        return formatted(value, digits: digits)
    }

    static func fuelVolume(_ liters: Double, unit: FuelVolumeUnit = UnitSettings.currentFuelVolumeUnit, digits: Int = 1) -> String {
        let value = unit == .gallons ? liters / gallonStyle() : liters
        return "\(formatted(value, digits: digits)) \(unit.shortTitle)"
    }

    static func fuelVolumeValue(_ liters: Double, unit: FuelVolumeUnit = UnitSettings.currentFuelVolumeUnit, digits: Int = 1) -> String {
        let value = unit == .gallons ? liters / gallonStyle() : liters
        return formatted(value, digits: digits)
    }

    static func consumption(_ litersPer100Km: Double, unit: ConsumptionUnit = UnitSettings.currentConsumptionUnit, digits: Int = 1) -> String {
        let value: Double
        let suffix: String

        switch unit {
        case .litersPer100Kilometers:
            value = litersPer100Km
            suffix = "L/100 km"
        case .mpgUS:
            value = UnitConverter.litersPer100KmToMpgUS(litersPer100Km)
            suffix = "mpg (US)"
        case .mpgUK:
            value = UnitConverter.litersPer100KmToMpgUK(litersPer100Km)
            suffix = "mpg (UK)"
        case .kilometersPerLiter:
            value = UnitConverter.litersPer100KmToKilometersPerLiter(litersPer100Km)
            suffix = "km/L"
        }

        return "\(formatted(value, digits: digits)) \(suffix)"
    }

    static func costPerDistanceCurrency(_ costPer100Km: Double, currencyCode: String, unit: DistanceUnit = UnitSettings.currentDistanceUnit) -> String {
        let value: Double
        let suffix: String

        switch unit {
        case .kilometers:
            value = costPer100Km
            suffix = "/100 km"
        case .miles:
            value = costPer100Km * UnitConverter.kilometersPerMile
            suffix = "/100 mi"
        }

        return "\(AppFormatters.currency(value, code: currencyCode)) \(suffix)"
    }

    static func costPerFuelUnitCurrency(_ costPerLiter: Double, currencyCode: String, fuelVolumeUnit: FuelVolumeUnit = UnitSettings.currentFuelVolumeUnit) -> String {
        let value: Double
        let suffix: String
        switch fuelVolumeUnit {
        case .liters:
            value = costPerLiter
            suffix = "/L"
        case .gallons:
            value = costPerLiter * gallonStyle()
            suffix = "/gal"
        }
        return "\(AppFormatters.currency(value, code: currencyCode)) \(suffix)"
    }

    static func costRateTitle(for unit: DistanceUnit = UnitSettings.currentDistanceUnit) -> String {
        unit == .miles ? "Cost / 100 mi" : "Cost / 100 km"
    }

    static func parseDistance(_ text: String, unit: DistanceUnit = UnitSettings.currentDistanceUnit) -> Int? {
        guard let value = parseDecimal(text) else { return nil }
        let kilometers = unit == .miles ? UnitConverter.milesToKilometers(value) : value
        return Int(kilometers.rounded())
    }

    static func parseFuelVolume(_ text: String, unit: FuelVolumeUnit = UnitSettings.currentFuelVolumeUnit) -> Double? {
        guard let value = parseDecimal(text) else { return nil }
        return unit == .gallons ? value * gallonStyle() : value
    }

    static func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try locale-aware parsing first — handles grouping separators correctly
        // (e.g. "70,000" in en_US or "70.000" in de_DE → 70000)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .autoupdatingCurrent
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }

        // Fallback: treat comma as decimal separator for simple inputs like "45,5"
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    static func formatted(_ value: Double, digits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }
}
