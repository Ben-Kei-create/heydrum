import SwiftUI

/// Dedicated reading screen (UI-05): pure white, large text, centre control, small stop bottom-right.
/// The shared ad slot (owned by AppShell) stays below this view.
struct PlaybackView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(PlaybackViewModel.self) private var playback

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView {
                    Text(TextHighlighter.attributed(playback.text, highlight: playback.highlightRange))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .frame(minHeight: proxy.size.height)
                        .accessibilityIdentifier("playbackText")
                }
            }

            VStack(spacing: 12) {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("playbackStatus")
                centerButton
                if case .failed(let message) = playback.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0xB3261E))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
            .padding(.top, 8)

            HStack {
                Spacer()
                stopButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea(.container, edges: [.top, .horizontal]))
        .accessibilityIdentifier("playbackScreen")
    }

    private var statusText: String {
        switch playback.state {
        case .idle, .preparing: "準備しています…"
        case .speaking: "読み上げ中"
        case .paused: "一時停止中"
        case .finished: "読み上げが完了しました"
        case .failed: "読み上げできませんでした"
        }
    }

    private var centerButton: some View {
        Button { playback.centerAction() } label: {
            ZStack {
                Circle().fill(Palette.softOrange).frame(width: 96, height: 96)
                Circle().fill(Palette.primaryOrange).frame(width: 72, height: 72)
                switch playback.state {
                case .idle, .preparing:
                    ProgressView().tint(Palette.ink)
                case .speaking:
                    Image(systemName: "pause.fill").font(.title.weight(.bold)).foregroundStyle(Palette.ink)
                case .paused:
                    Image(systemName: "play.fill").font(.title.weight(.bold)).foregroundStyle(Palette.ink)
                case .finished, .failed:
                    Image(systemName: "arrow.counterclockwise").font(.title.weight(.bold)).foregroundStyle(Palette.ink)
                }
            }
            .frame(width: 96, height: 96)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(playback.state == .preparing || playback.state == .idle)
        .accessibilityLabel(centerLabel)
        .accessibilityIdentifier("playbackCenterButton")
    }

    private var centerLabel: String {
        switch playback.state {
        case .idle, .preparing: "準備中"
        case .speaking: "一時停止"
        case .paused: "再開"
        case .finished: "もう一度読み上げる"
        case .failed: "もう一度試す"
        }
    }

    private var stopButton: some View {
        let finished: Bool = {
            switch playback.state {
            case .finished, .failed: true
            default: false
            }
        }()
        return Button { coordinator.closePlayback() } label: {
            VStack(spacing: 2) {
                Image(systemName: finished ? "chevron.backward" : "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 28, height: 28)
                    .background(Palette.adBackground, in: Circle())
                Text(finished ? "戻る" : "停止").font(.caption2).foregroundStyle(Palette.muted)
            }
            .frame(minWidth: Metrics.minTap, minHeight: Metrics.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(finished ? "戻る" : "停止")
        .accessibilityIdentifier("playbackStopButton")
    }
}
