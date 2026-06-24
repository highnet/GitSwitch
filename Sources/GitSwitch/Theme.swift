import SwiftUI

/// Visual constants for the app's slick dark look.
enum Theme {
    static let accent = Color(red: 1.00, green: 0.62, blue: 0.30)   // git orange
    static let accentDim = Color(red: 1.00, green: 0.62, blue: 0.30).opacity(0.16)

    static let bgTop = Color(red: 0.09, green: 0.08, blue: 0.13)
    static let bgBottom = Color(red: 0.05, green: 0.04, blue: 0.08)

    static let rowFill = Color.white.opacity(0.04)
    static let rowHover = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.07)

    static let danger = Color(red: 1, green: 0.42, blue: 0.42)

    static let background = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A deterministic accent hue per login, for the leading glyph chip.
    static func tint(for key: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.36, green: 0.72, blue: 1.00),   // blue
            Color(red: 0.66, green: 0.55, blue: 1.00),   // violet
            Color(red: 1.00, green: 0.62, blue: 0.40),   // orange
            Color(red: 0.20, green: 0.86, blue: 0.60),   // green
            Color(red: 1.00, green: 0.45, blue: 0.62),   // pink
            Color(red: 0.40, green: 0.84, blue: 0.86),   // teal
        ]
        let hash = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[hash % palette.count]
    }
}
