import SwiftUI

struct HistoryRow: View {
    let entry: HistoryEntry
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.text)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(entry.lastPlayedAt.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill")
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.softOrange, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTap + 16, alignment: .leading)
            .background(Palette.pureWhite, in: RoundedRectangle(cornerRadius: Metrics.chipRadius))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.chipRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("再生 \(entry.text)")
        .accessibilityIdentifier("historyRow")
    }
}
