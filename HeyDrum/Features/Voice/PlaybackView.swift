import SwiftUI

/// Dedicated reading screen (UI-05): pure white, large text, centre control, small stop bottom-right.
/// The shared ad slot (owned by AppShell) stays below this view.
struct PlaybackView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(PlaybackViewModel.self) private var playback
    /// 1.0 at the default text size; grows with the user's Dynamic Type setting.
    @ScaledMetric(relativeTo: .largeTitle) private var typeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Text appears as the synthesizer announces it. Left-aligned and top-anchored so
                            // already shown lines never move; the font is fixed for the whole session.
                            Text(playback.visibleText.isEmpty ? " " : playback.visibleText)   // never an empty Text (keeps the element and one line of height)
                                .font(.system(size: PlaybackTextStyle.fontSize(forCharacterCount: playback.text.count, scale: typeScale), weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .lineSpacing(10)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel(playback.visibleText.isEmpty ? "読み上げ待機中" : playback.visibleText)
                                .accessibilityIdentifier("playbackText")
                            Color.clear.frame(height: 1).id("revealEnd")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, max(24, proxy.size.height * 0.12))
                        .padding(.bottom, 32)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .onChange(of: playback.revealedUTF16) { _, _ in
                        // Keep the newest text in view for long passages.
                        withAnimation(.easeOut(duration: 0.2)) { scroller.scrollTo("revealEnd", anchor: .bottom) }
                    }
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
        .background(Color.white.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playbackScreen")
    }

    private var statusText: String {
        if let remaining = playback.countdownRemaining { return "\(remaining)秒後に読み上げます" }
        return switch playback.state {
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
                    if let remaining = playback.countdownRemaining {
                        Text("\(remaining)").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("playbackCountdown")
                    } else {
                        ProgressView().tint(Palette.ink)
                    }
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
        .accessibilityLabel(centerLabel)
        .accessibilityIdentifier("playbackCenterButton")
    }

    private var centerLabel: String {
        switch playback.state {
        case .idle, .preparing: playback.countdownRemaining.map { "あと\($0)秒" } ?? "準備中"
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
