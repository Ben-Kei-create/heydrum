import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.cardSpacing) {
                NavigationLink(value: HomeDestination.drum) {
                    ModeCard(title: "ドラムモード", subtitle: "シンプルに音を鳴らす", fill: Palette.warmBeige)
                }
                .accessibilityIdentifier("homeDrumCard")

                NavigationLink(value: HomeDestination.voiceEditor) {
                    ModeCard(title: "音声モード", subtitle: "文字を読み上げる", fill: Palette.softOrange)
                }
                .accessibilityIdentifier("homeVoiceCard")
            }
            .padding(Metrics.outerPadding)
        }
        .background(Palette.paper)
        .navigationTitle("ヘイドラム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ModeCard: View {
    let title: String
    let subtitle: String
    let fill: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title2.bold()).foregroundStyle(Palette.ink)
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(Palette.primaryOrange)
                .frame(width: 44, height: 44)
                .background(Palette.pureWhite, in: Circle())
                .accessibilityHidden(true)
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
