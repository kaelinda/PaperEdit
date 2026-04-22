import SwiftUI

struct PaperTheme {
    var windowBackground: Color
    var editorBackground: Color
    var sidebarBackground: Color
    var elevatedBackground: Color
    var textPrimary: Color
    var textMuted: Color
    var textSubtle: Color
    var accent: Color
    var accentForeground: Color
    var border: Color
    var hover: Color
    var pressed: Color
    var currentLine: Color
    var selection: Color
    var paletteBlur: Color
    var success: Color

    static let light = PaperTheme(
        windowBackground: Color(hex: "#FAFAFA"),
        editorBackground: Color(hex: "#FFFFFF"),
        sidebarBackground: Color(hex: "#F6F5F3"),
        elevatedBackground: Color(hex: "#FFFFFF"),
        textPrimary: Color(hex: "#1D1D1F"),
        textMuted: Color(hex: "#5F6066"),
        textSubtle: Color(hex: "#6E6E73"),
        accent: AccentSwatch.blue.interfaceColor,
        accentForeground: AccentSwatch.blue.foregroundColor,
        border: Color.black.opacity(0.08),
        hover: Color.black.opacity(0.05),
        pressed: Color.black.opacity(0.08),
        currentLine: Color.black.opacity(0.025),
        selection: AccentSwatch.blue.interfaceColor.opacity(0.14),
        paletteBlur: Color.white.opacity(0.9),
        success: Color(hex: "#248A3D")
    )

    static let dark = PaperTheme(
        windowBackground: Color(hex: "#1E1E1E"),
        editorBackground: Color(hex: "#252526"),
        sidebarBackground: Color(hex: "#202122"),
        elevatedBackground: Color(hex: "#2A2B2D"),
        textPrimary: Color(hex: "#E4E4E4"),
        textMuted: Color(hex: "#B5B5BA"),
        textSubtle: Color(hex: "#8E8E93"),
        accent: AccentSwatch.blue.interfaceColor,
        accentForeground: AccentSwatch.blue.foregroundColor,
        border: Color.white.opacity(0.08),
        hover: Color.white.opacity(0.05),
        pressed: Color.white.opacity(0.09),
        currentLine: Color.white.opacity(0.03),
        selection: AccentSwatch.blue.interfaceColor.opacity(0.24),
        paletteBlur: Color(hex: "#1D1D1D").opacity(0.95),
        success: Color(hex: "#32D74B")
    )
}

extension PaperTheme {
    static func resolve(from palette: ThemePalette, colorScheme: ColorScheme, accentSwatch: AccentSwatch) -> PaperTheme {
        let base: PaperTheme = switch palette {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            colorScheme == .dark ? .dark : .light
        }

        return PaperTheme(
            windowBackground: base.windowBackground,
            editorBackground: base.editorBackground,
            sidebarBackground: base.sidebarBackground,
            elevatedBackground: base.elevatedBackground,
            textPrimary: base.textPrimary,
            textMuted: base.textMuted,
            textSubtle: base.textSubtle,
            accent: accentSwatch.interfaceColor,
            accentForeground: accentSwatch.foregroundColor,
            border: base.border,
            hover: base.hover,
            pressed: base.pressed,
            currentLine: base.currentLine,
            selection: accentSwatch.interfaceColor.opacity(palette == .dark || (palette == .system && colorScheme == .dark) ? 0.24 : 0.14),
            paletteBlur: base.paletteBlur,
            success: base.success
        )
    }
}

extension AccentSwatch {
    var displayColor: Color {
        Color(hex: rawValue)
    }

    var interfaceColor: Color {
        switch self {
        case .blue:
            Color(hex: "#005ECF")
        case .red:
            Color(hex: "#C9342C")
        case .green:
            Color(hex: "#248A3D")
        case .orange:
            Color(hex: "#B86B00")
        case .purple:
            Color(hex: "#7240D8")
        }
    }

    var foregroundColor: Color {
        switch self {
        case .orange, .green:
            Color.white
        case .blue, .red, .purple:
            Color.white
        }
    }
}

extension Color {
    init(hex: String, opacity: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: (Double(a) / 255) * opacity
        )
    }
}
