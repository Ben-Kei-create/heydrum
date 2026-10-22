import SwiftUI

/// Dedicated reading screen (UI-05): pure white, large text, quiet controls at the bottom corners.
/// The shared ad slot (owned by AppShell) stays below this view.
struct PlaybackView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(PlaybackViewModel.self) private var playback
    @Environment(SettingsStore.self) private var settings
    /// 1.0 at the default text size; grows with the user's Dynamic Type setting.
    @ScaledMetric(relativeTo: .largeTitle) private var typeScale: CGFloat = 1
    private var isGreeting: Bool { coordinator.request?.source == .greeting }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Text appears as the synthesizer announces it. Left-aligned and top-anchored so
                            // already shown lines never move; the font is fixed for the whole session.
                            Text(playback.visibleText.isEmpty ? " " : playback.visibleText)   // never an empty Text (keeps the element and one line of height)
                                .font(settings.readingFont.font(size: PlaybackTextStyle.fontSize(forCharacterCount: playback.text.count, scale: min(typeScale, 2) * CGFloat(settings.readingTextScale))))
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
                if !isGreeting {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("playbackStatus")
                if case .failed(let message) = playback.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0xB3261E))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                }
            }
            .padding(.top, 8)

            HStack {
                if !isGreeting { pauseSideButton } else { Color.clear.frame(width: Metrics.minTap, height: Metrics.minTap) }
                Spacer()
                if let remaining = playback.countdownRemaining {
                    Text("\(remaining)秒")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                        .accessibilityLabel("あと\(remaining)秒")
                        .accessibilityIdentifier("playbackCountdownSeconds")
                }
                Spacer()
                stopButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { if isGreeting { coordinator.closePlayback() } }     // tap skips the launch greeting
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playbackScreen")
    }

    private var statusText: String {
        if playback.countdownRemaining != nil { return "まもなく読み上げます" }
        return switch playback.state {
        case .idle, .preparing: "準備しています…"
        case .speaking: "読み上げ中"
        case .paused: "一時停止中"
        case .finished: "読み上げが完了しました"
        case .failed: "読み上げできませんでした"
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

    /// Bottom-left twin of the stop button: same size, same quiet grey (no orange).
    private var pauseSideButton: some View {
        let icon: String
        let label: String
        let enabled: Bool
        switch playback.state {
        case .speaking: (icon, label, enabled) = ("pause.fill", "一時停止", true)
        case .paused: (icon, label, enabled) = ("play.fill", "再開", true)
        case .finished, .failed: (icon, label, enabled) = ("arrow.counterclockwise", "もう一度", true)
        case .idle, .preparing: (icon, label, enabled) = ("pause.fill", "一時停止", false)
        }
        return Button { playback.centerAction() } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 28, height: 28)
                    .background(Palette.adBackground, in: Circle())
                Text(label).font(.caption2).foregroundStyle(Palette.muted)
            }
            .frame(minWidth: Metrics.minTap, minHeight: Metrics.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label == "もう一度" ? "もう一度読み上げる" : label)
        .accessibilityIdentifier("playbackPauseButton")
    }
}
