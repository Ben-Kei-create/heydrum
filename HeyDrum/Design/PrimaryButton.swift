import SwiftUI

/// Large action button. Ink text on orange (white on #ED8D45 is only ~2.5:1, below WCAG AA).
struct HeyDrumButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundStyle(isEnabled ? Palette.ink : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .padding(.horizontal, Metrics.outerPadding)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: Metrics.buttonRadius))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius))
    }

    private func background(pressed: Bool) -> Color {
        guard isEnabled else { return Palette.stroke }
        switch kind {
        case .primary: return pressed ? Palette.orangePressed : Palette.primaryOrange
        case .secondary: return pressed ? Palette.softOrange : Palette.warmBeige
        }
    }
}
