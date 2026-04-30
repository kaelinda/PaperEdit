import SwiftUI

struct PaperTheme {
    var windowBackground: Color
    var chromeBackground: Color
    var editorBackground: Color
    var canvasBackground: Color
    var sidebarBackground: Color
    var elevatedBackground: Color
    var secondaryElevatedBackground: Color
    var textPrimary: Color
    var textMuted: Color
    var textSubtle: Color
    var accent: Color
    var accentForeground: Color
    var border: Color
    var borderStrong: Color
    var hover: Color
    var pressed: Color
    var selectedItemFill: Color
    var selectedItemStroke: Color
    var currentLine: Color
    var selection: Color
    var paletteBlur: Color
    var success: Color
    var warning: Color
    var danger: Color
    var shadow: Color

    static let light = PaperTheme(
        windowBackground: Color(hex: "#F5F5F7"),
        chromeBackground: Color.white.opacity(0.78),
        editorBackground: Color(hex: "#FFFFFF"),
        canvasBackground: Color(hex: "#ECECF1"),
        sidebarBackground: Color(hex: "#F2F2F7"),
        elevatedBackground: Color(hex: "#FFFFFF"),
        secondaryElevatedBackground: Color.white.opacity(0.68),
        textPrimary: Color(hex: "#1D1D1F"),
        textMuted: Color(hex: "#5F6066"),
        textSubtle: Color(hex: "#6E6E73"),
        accent: AccentSwatch.blue.interfaceColor,
        accentForeground: AccentSwatch.blue.foregroundColor,
        border: Color.black.opacity(0.08),
        borderStrong: Color.black.opacity(0.12),
        hover: Color.black.opacity(0.05),
        pressed: Color.black.opacity(0.08),
        selectedItemFill: AccentSwatch.blue.interfaceColor.opacity(0.10),
        selectedItemStroke: AccentSwatch.blue.interfaceColor.opacity(0.16),
        currentLine: Color.black.opacity(0.025),
        selection: AccentSwatch.blue.interfaceColor.opacity(0.14),
        paletteBlur: Color.white.opacity(0.9),
        success: Color(hex: "#248A3D"),
        warning: Color(hex: "#B86B00"),
        danger: Color(hex: "#D70015"),
        shadow: Color.black.opacity(0.08)
    )

    static let dark = PaperTheme(
        windowBackground: Color(hex: "#1C1C1E"),
        chromeBackground: Color.white.opacity(0.05),
        editorBackground: Color(hex: "#202124"),
        canvasBackground: Color(hex: "#17181B"),
        sidebarBackground: Color(hex: "#1E1F22"),
        elevatedBackground: Color(hex: "#2C2C2E"),
        secondaryElevatedBackground: Color.white.opacity(0.03),
        textPrimary: Color(hex: "#F2F2F7"),
        textMuted: Color(hex: "#B5B5BA"),
        textSubtle: Color(hex: "#8E8E93"),
        accent: AccentSwatch.blue.interfaceColor,
        accentForeground: AccentSwatch.blue.foregroundColor,
        border: Color.white.opacity(0.08),
        borderStrong: Color.white.opacity(0.14),
        hover: Color.white.opacity(0.05),
        pressed: Color.white.opacity(0.09),
        selectedItemFill: AccentSwatch.blue.interfaceColor.opacity(0.18),
        selectedItemStroke: AccentSwatch.blue.interfaceColor.opacity(0.26),
        currentLine: Color.white.opacity(0.03),
        selection: AccentSwatch.blue.interfaceColor.opacity(0.24),
        paletteBlur: Color(hex: "#1D1D1D").opacity(0.95),
        success: Color(hex: "#32D74B"),
        warning: Color(hex: "#FFD60A"),
        danger: Color(hex: "#FF453A"),
        shadow: Color.black.opacity(0.28)
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
            chromeBackground: base.chromeBackground,
            editorBackground: base.editorBackground,
            canvasBackground: base.canvasBackground,
            sidebarBackground: base.sidebarBackground,
            elevatedBackground: base.elevatedBackground,
            secondaryElevatedBackground: base.secondaryElevatedBackground,
            textPrimary: base.textPrimary,
            textMuted: base.textMuted,
            textSubtle: base.textSubtle,
            accent: accentSwatch.interfaceColor,
            accentForeground: accentSwatch.foregroundColor,
            border: base.border,
            borderStrong: base.borderStrong,
            hover: base.hover,
            pressed: base.pressed,
            selectedItemFill: accentSwatch.interfaceColor.opacity(palette == .dark || (palette == .system && colorScheme == .dark) ? 0.18 : 0.10),
            selectedItemStroke: accentSwatch.interfaceColor.opacity(palette == .dark || (palette == .system && colorScheme == .dark) ? 0.26 : 0.16),
            currentLine: base.currentLine,
            selection: accentSwatch.interfaceColor.opacity(palette == .dark || (palette == .system && colorScheme == .dark) ? 0.24 : 0.14),
            paletteBlur: base.paletteBlur,
            success: base.success,
            warning: base.warning,
            danger: base.danger,
            shadow: base.shadow
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
            Color(hex: "#1F7A2F")
        case .orange:
            Color(hex: "#B86B00")
        case .purple:
            Color(hex: "#7240D8")
        }
    }

    var foregroundColor: Color {
        switch self {
        case .orange:
            Color(hex: "#111214")
        case .blue, .red, .green, .purple:
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
