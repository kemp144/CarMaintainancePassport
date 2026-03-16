import SwiftUI

enum AppTheme {
    static let background = Color(hex: "0B1016")
    static let elevatedBackground = Color(hex: "111823")
    static let surface = Color(hex: "151F2C")
    static let surfaceSecondary = Color(hex: "1D2938")
    static let accent = Color(hex: "4BA9C8")
    static let accentSecondary = Color(hex: "7AD4D8")
    static let success = Color(hex: "4DBB87")
    static let warning = Color(hex: "E5A84A")
    static let error = Color(hex: "DD6A6A")
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.42)
    static let separator = Color.white.opacity(0.08)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "111A24"), Color(hex: "0D2430"), Color(hex: "172731")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch value.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}