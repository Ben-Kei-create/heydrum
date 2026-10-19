import SwiftUI

/// Exactly two sound buttons (FR-002). One tap = one `play` call.
struct DrumView: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        VStack(spacing: 12) {
            soundButton(title: "ドラム音", kind: .drum, fill: Palette.primaryOrange, identifier: "drumButton")
            Text("タップで音を鳴らします").font(.footnote).foregroundStyle(Palette.muted)
            soundButton(title: "金属音", kind: .metal, fill: Palette.warmBeige, identifier: "metalButton")
            Text("タップで音を鳴らします").font(.footnote).foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
        }
        .padding(Metrics.outerPadding)
        .background(Palette.paper)
        .navigationTitle("ドラムモード")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies?.sound.stopAll() }
    }

    private func soundButton(title: String, kind: SoundKind, fill: Color, identifier: String) -> some View {
        Button {
            guard let dependencies else { return }
            dependencies.sound.play(kind, volume: dependencies.settings.masterVolume)
        } label: {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 140)
        }
        .buttonStyle(SoundButtonStyle(fill: fill))
        .accessibilityLabel(title)
        .accessibilityHint("タップで音を鳴らします")
        .accessibilityIdentifier(identifier)
    }
}

/// Only visual feedback: a ~100 ms pressed tint. No waveform / rhythm animation.
private struct SoundButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(Palette.ink.opacity(configuration.isPressed ? 0.12 : 0)))
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }
}
