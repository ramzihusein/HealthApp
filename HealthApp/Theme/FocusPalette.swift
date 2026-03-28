import SwiftUI

/// Deep slate and copper-amber accents — high contrast, calm intensity for focus and determination.
enum FocusPalette {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let surface = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let surfaceElevated = Color(red: 0.14, green: 0.16, blue: 0.21)
    static let border = Color(red: 0.22, green: 0.25, blue: 0.32)

    static let textPrimary = Color(red: 0.94, green: 0.94, blue: 0.96)
    static let textSecondary = Color(red: 0.62, green: 0.66, blue: 0.74)

    static let accent = Color(red: 0.92, green: 0.55, blue: 0.18)
    static let accentMuted = Color(red: 0.92, green: 0.55, blue: 0.18).opacity(0.35)
    static let positive = Color(red: 0.35, green: 0.78, blue: 0.52)
    static let warning = Color(red: 0.95, green: 0.72, blue: 0.28)
    static let danger = Color(red: 0.92, green: 0.35, blue: 0.38)
}

struct FocusScreenBackground: View {
    var body: some View {
        ZStack {
            FocusPalette.background
            LinearGradient(
                colors: [
                    FocusPalette.background,
                    Color(red: 0.08, green: 0.09, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct FocusCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(FocusPalette.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FocusPalette.border, lineWidth: 1)
            )
    }
}

struct FocusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(FocusPalette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FocusPalette.accent.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FocusSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(FocusPalette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FocusPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FocusPalette.accent.opacity(0.5), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
