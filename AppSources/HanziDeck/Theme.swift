import SwiftUI

enum AppTheme {
    static let background = Color(hex: 0x050505)
    static let surface = Color(hex: 0x111111)
    static let elevatedSurface = Color(hex: 0x191919)
    static let orange = Color(hex: 0xFF8000)
    static let primaryText = Color(hex: 0xF5F5F5)
    static let secondaryText = Color(hex: 0xA3A3A3)
    static let divider = Color.white.opacity(0.10)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.orange.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct DarkFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(AppTheme.primaryText)
            .background(AppTheme.elevatedSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func darkPanel() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
    }
}
