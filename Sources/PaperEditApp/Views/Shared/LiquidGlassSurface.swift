import SwiftUI

struct LiquidGlassChrome: View {
    let theme: PaperTheme
    var material: NSVisualEffectView.Material = .headerView

    var body: some View {
        ZStack {
            VisualEffectBlur(material: material)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    theme.chromeBackground.opacity(0.62),
                    theme.accent.opacity(0.055),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0),
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 260
            )
            .blendMode(.screen)
        }
    }
}

struct LiquidGlassSurface: View {
    let theme: PaperTheme
    var cornerRadius: CGFloat
    var material: NSVisualEffectView.Material = .hudWindow
    var isProminent = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            VisualEffectBlur(material: material)

            LinearGradient(
                colors: [
                    Color.white.opacity(isProminent ? 0.32 : 0.22),
                    theme.secondaryElevatedBackground.opacity(isProminent ? 0.74 : 0.52),
                    theme.accent.opacity(isProminent ? 0.10 : 0.055),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(isProminent ? 0.24 : 0.14),
                    Color.white.opacity(0),
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isProminent ? 0.56 : 0.38),
                        theme.borderStrong.opacity(isProminent ? 0.72 : 0.58),
                        Color.white.opacity(0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .shadow(color: theme.shadow.opacity(isProminent ? 0.20 : 0.12), radius: isProminent ? 14 : 10, y: isProminent ? 7 : 4)
        .allowsHitTesting(false)
    }
}
