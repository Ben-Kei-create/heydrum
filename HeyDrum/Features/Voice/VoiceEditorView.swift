import SwiftUI

struct VoiceEditorView: View {
    @Environment(VoiceEditorViewModel.self) private var editor
    @Environment(HistoryViewModel.self) private var history
    @Environment(SettingsStore.self) private var settings
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var editor = editor
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editor.text)
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .padding(8)
                        .frame(minHeight: 160)
                        .accessibilityLabel("読み上げたい文字")
                        .accessibilityIdentifier("voiceTextEditor")
                    if editor.text.isEmpty {
                        Text("読み上げたい文字を入力")
                            .font(.body)
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .background(Palette.pureWhite, in: RoundedRectangle(cornerRadius: Metrics.chipRadius))
                .overlay(RoundedRectangle(cornerRadius: Metrics.chipRadius).stroke(Palette.stroke))

                HStack {
                    if let notice = editor.notice {
                        Text(notice).font(.footnote).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text("\(editor.characterCount)/\(SpeechText.maxLength)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                        .accessibilityLabel("\(editor.characterCount)文字、上限\(SpeechText.maxLength)文字")
                        .accessibilityIdentifier("voiceCounter")
                }

                delayGrid

                Button {
                    focused = false
                    Task { await editor.start() }
                } label: {
                    Label(settings.startDelaySeconds == 0 ? "読み上げ開始" : "\(settings.startDelaySeconds)秒後に読み上げ開始", systemImage: "play.fill")
                }
                .buttonStyle(HeyDrumButtonStyle())
                .disabled(!editor.canStart)
                .accessibilityIdentifier("voiceStartButton")

                if let message = editor.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0xB3261E))
                        .accessibilityIdentifier("voiceErrorMessage")
                }

                recentHistory
            }
            .padding(Metrics.outerPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") { focused = false }
                    .accessibilityIdentifier("keyboardDismiss")
            }
        }
        .background(Palette.paper)
        .navigationTitle("音声モード")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var delayGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("読み上げ開始のタイミング").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(StartDelay.options, id: \.self) { seconds in
                    let selected = settings.startDelaySeconds == seconds
                    Button { settings.startDelaySeconds = seconds } label: {
                        Text(StartDelay.label(seconds))
                            .font(.body.weight(selected ? .bold : .regular))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: Metrics.minTap + 4)
                            .background(selected ? Palette.primaryOrange : Palette.pureWhite, in: RoundedRectangle(cornerRadius: Metrics.chipRadius))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.chipRadius).stroke(selected ? Palette.orangePressed : Palette.stroke, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(seconds == 0 ? "すぐに読み上げ" : "\(seconds)秒後に読み上げ")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("delay-\(seconds)")
                }
            }
        }
    }

    @ViewBuilder
    private var recentHistory: some View {
        let recent = Array(history.entries.prefix(4))
        if !recent.isEmpty {
            Text("履歴（最大100件）").font(.headline).foregroundStyle(Palette.ink).padding(.top, 8)
            VStack(spacing: 8) {
                ForEach(recent) { entry in
                    HistoryRow(entry: entry) { Task { await history.play(entry) } }
                }
            }
            if let message = history.message {
                Text(message).font(.footnote).foregroundStyle(Color(hex: 0xB3261E))
            }
        }
    }
}
