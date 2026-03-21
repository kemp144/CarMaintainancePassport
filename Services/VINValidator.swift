import Foundation

struct VINValidator {
    private static let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")

    static func normalized(_ vin: String) -> String {
        vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValid(_ vin: String) -> Bool {
        let vin = normalized(vin)
        guard vin.count == 17 else { return false }
        return vin.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    static func helperText(for vin: String) -> String? {
        let vin = normalized(vin)
        guard !vin.isEmpty else { return nil }

        if vin.count < 17 {
            return "Enter a valid 17-character VIN to use Autofill."
        }

        if vin.count > 17 {
            return "VINs use exactly 17 characters."
        }

        if !isValid(vin) {
            return "VINs can use letters A-Z and numbers 0-9, without I, O, or Q."
        }

        return "Autofill can use this VIN to fill make, model, and year."
    }

    static func validationError(for vin: String) -> String? {
        let vin = normalized(vin)
        guard !vin.isEmpty else { return nil }
        guard vin.count == 17 else {
            return "VIN must be exactly 17 characters or left empty."
        }
        guard isValid(vin) else {
            return "VIN can contain only letters A-Z and numbers 0-9, without I, O, or Q."
        }
        return nil
    }
}
