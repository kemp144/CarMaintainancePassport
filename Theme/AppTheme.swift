import SwiftUI

enum AppTheme {
    // New Tailwind Slate and Orange Palette
    static let background = Color(hex: "020617") // slate-950
    static let elevatedBackground = Color(hex: "0F172A") // slate-900
    static let surface = Color(hex: "0F172A") // slate-900
    static let surfaceSecondary = Color(hex: "1E293B") // slate-800
    static let accent = Color(hex: "F97316") // orange-500
    static let accentSecondary = Color(hex: "EA580C") // orange-600
    static let success = Color(hex: "22C55E") // green-500
    static let warning = Color(hex: "F59E0B") // amber-500
    static let error = Color(hex: "EF4444") // red-500
    
    static let primaryText = Color.white
    static let secondaryText = Color(hex: "94A3B8") // slate-400
    static let tertiaryText = Color(hex: "64748B") // slate-500
    static let separator = Color(hex: "1E293B") // slate-800

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "0F172A"), Color(hex: "020617")],
        startPoint: .top,
        endPoint: .bottom
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