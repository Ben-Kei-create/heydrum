import SwiftUI

struct SettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(SettingsStore.self) private var settings
    @Environment(VoicePreviewController.self) private var preview
    @Environment(AdMobManager.self) private var ads
    @Environment(HistoryViewModel.self) private var history

    @State private var restoreMessage: String?
    @State private var purchaseMessage: String?

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("音量").font(.headline)
                        Spacer()
                        Text("\(Int((settings.masterVolume * 100).rounded()))%")
                            .font(.body.monospacedDigit()).foregroundStyle(Palette.muted)
                            .accessibilityHidden(true)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.masterVolume * 100) },
                        set: { settings.masterVolume = Float($0 / 100) }
                    ), in: 0...100, step: 1)
                    .tint(Palette.primaryOrange)
                    .accessibilityLabel("音量")
                    .accessibilityValue("\(Int((settings.masterVolume * 100).rounded()))パーセント")
                    .accessibilityIdentifier("volumeSlider")
                    Text("アプリ内の効果音と読み上げの音量です。端末の音量とは別に調整されます。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                .padding(.vertical, 4)
            }

            Section("音声") {
                Picker("音声", selection: Binding(
                    get: { voiceSelection },
                    set: { settings.preferredVoiceID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("システム標準（日本語）").tag("")
                    ForEach(voices) { voice in Text(voice.displayName).tag(voice.id) }
                }
                .frame(minHeight: Metrics.minTap)
                .accessibilityIdentifier("voicePicker")

                Picker("読み上げ速度", selection: $settings.speechSpeed) {
                    ForEach(SpeechSpeed.allCases) { speed in Text(speed.label).tag(speed) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("speedPicker")

                Button {
                    if preview.isPlaying { preview.stop() } else { preview.play() }
                } label: {
                    Label(preview.isPlaying ? "停止" : "音声を試す", systemImage: preview.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                }
                .frame(minHeight: Metrics.minTap)
                .accessibilityIdentifier("voicePreviewButton")
                if let message = preview.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(Color(hex: 0xB3261E))
                }
                Text("声の種類は端末にインストールされた日本語音声によって決まります。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }

            purchaseSection

            if ads.privacyOptionsRequired {
                Section {
                    Button("プライバシー設定") { Task { await ads.presentPrivacyOptions() } }
                        .frame(minHeight: Metrics.minTap)
                        .accessibilityIdentifier("privacyOptionsButton")
                }
            }

            Section {
                NavigationLink("プライバシーポリシー") { PrivacyInfoView() }.frame(minHeight: Metrics.minTap)
                NavigationLink("アプリについて") { AboutView() }.frame(minHeight: Metrics.minTap)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    private var voices: [SpeechVoiceOption] { dependencies?.speech.availableJapaneseVoices() ?? [] }

    /// A stored voice that no longer exists shows as "システム標準" without rewriting the setting (ER-15).
    private var voiceSelection: String {
        guard let id = settings.preferredVoiceID, voices.contains(where: { $0.id == id }) else { return "" }
        return id
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if let purchase = dependencies?.purchase {
            Section("広告") {
                if purchase.entitlement == .purchased {
                    Label("広告非表示済み", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("adsRemovedLabel")
                } else {
                    Button {
                        Task {
                            let outcome = await purchase.purchaseRemoveAds()
                            if case .failed(let message) = outcome { purchaseMessage = message } else { purchaseMessage = purchase.statusMessage }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("広告を非表示にする").font(.headline).foregroundStyle(purchaseEnabled(purchase) ? Palette.ink : Palette.muted)
                            Text(priceText(purchase)).font(.caption).foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTap, alignment: .leading)
                    }
                    .disabled(!purchaseEnabled(purchase))
                    .listRowBackground(Palette.softOrange)
                    .accessibilityIdentifier("removeAdsButton")
                }
                Button("購入を復元") {
                    Task {
                        let outcome = await purchase.restore()
                        switch outcome {
                        case .restored: restoreMessage = "購入を復元しました"
                        case .nothingToRestore: restoreMessage = "復元できる購入が見つかりません"
                        case .failed: restoreMessage = "購入情報を更新できませんでした"
                        }
                    }
                }
                .disabled(purchase.isBusy)
                .frame(minHeight: Metrics.minTap)
                .accessibilityIdentifier("restoreButton")

                if let message = restoreMessage ?? purchaseMessage ?? purchase.statusMessage {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("purchaseMessage")
                }
            }
        }
    }

    private func purchaseEnabled(_ purchase: PurchaseProviding) -> Bool {
        if case .loaded = purchase.productState, !purchase.isBusy, purchase.entitlement != .checking { return true }
        return false
    }

    private func priceText(_ purchase: PurchaseProviding) -> String {
        switch purchase.productState {
        case .loading: "価格を取得しています…"
        case .loaded(let price): "買い切り・広告を削除（\(price)）"
        case .unavailable: "現在購入情報を取得できません"
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            LabeledContent("アプリ名", value: "ヘイドラム")
            LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
            Text("2つの音を鳴らし、文字を読み上げるシンプルなアプリです。読み上げにはiOS標準の音声合成を使用します。")
                .font(.footnote).foregroundStyle(Palette.muted)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .navigationTitle("アプリについて")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("入力した文章と履歴は、この端末内にのみ保存され、外部へ送信されません。")
                Text("読み上げにはiOS標準の音声合成を使用し、クラウドの音声サービスやAIサービスは使用しません。")
                Text("広告の表示には Google AdMob を使用します。広告の配信に伴い、広告SDKが端末情報などを収集する場合があります。入力した文章や履歴が広告のために送られることはありません。")
                Text("広告の非表示（買い切り）は Apple のアプリ内課金で処理されます。")
                if let url = AppConfig.privacyPolicyURL {
                    Link("プライバシーポリシー（Web）", destination: url).frame(minHeight: Metrics.minTap)
                }
            }
            .font(.body)
            .foregroundStyle(Palette.ink)
            .padding(Metrics.outerPadding)
        }
        .background(Palette.paper)
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
