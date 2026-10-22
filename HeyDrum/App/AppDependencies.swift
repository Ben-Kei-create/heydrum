import Foundation

/// Composition root. Everything is injected so tests and previews never touch real services.
@MainActor
final class AppDependencies {
    let config: AppConfig
    let settings: SettingsStore
    let sound: SoundProviding
    let speech: SpeechProviding
    let hub: SpeechSessionHub
    let history: HistoryViewModel
    let purchase: PurchaseProviding
    let playback: PlaybackViewModel
    let coordinator: AppCoordinator
    let editor: VoiceEditorViewModel
    let preview: VoicePreviewController
    let keyboard = KeyboardObserver()
    let ads: AdMobManager
    /// Launch greeting is on for the real app; UI-test launches turn it off unless `-uitest-greeting` is passed.
    var launchGreetingEnabled = true
    /// How long the spoken word stays on screen after the voice ends (UI tests lengthen it).
    var greetingHold: TimeInterval = 0.9

    init(config: AppConfig, settings: SettingsStore, sound: SoundProviding, speech: SpeechProviding,
         historyRepository: HistoryRepository, purchase: PurchaseProviding, ads: AdMobManager,
         now: @escaping () -> Date = Date.init) {
        self.config = config
        self.settings = settings
        self.sound = sound
        self.speech = speech
        self.purchase = purchase
        self.ads = ads
        let hub = SpeechSessionHub(speech: speech)
        self.hub = hub
        let playback = PlaybackViewModel(hub: hub, settings: settings)
        self.playback = playback
        let coordinator = AppCoordinator(playback: playback, sound: sound)
        self.coordinator = coordinator
        let history = HistoryViewModel(repository: historyRepository, now: now)
        self.history = history
        history.epoch = { [weak coordinator] in coordinator?.interruptionEpoch ?? 0 }
        history.verifyReadiness = { [settings] in try hub.verifyReadiness(voiceID: settings.preferredVoiceID) }
        history.openPlayback = { [weak coordinator] entry in
            coordinator?.openPlayback(text: entry.text, source: .history(id: entry.id))
        }
        self.editor = VoiceEditorViewModel(history: history, hub: hub, settings: settings, epoch: { [weak coordinator] in coordinator?.interruptionEpoch ?? 0 }) { [weak coordinator] text, source, delay in
            coordinator?.openPlayback(text: text, source: source, delaySeconds: delay)
        }
        let preview = VoicePreviewController(hub: hub, settings: settings)
        self.preview = preview
        coordinator.interruptionHandlers.append { [weak preview] in preview?.stop() }
    }

    static func live() -> AppDependencies {
        let config = AppConfig.from()
        #if DEBUG
        if let uiTest = UITestLaunch.parse(ProcessInfo.processInfo.arguments) { return uiTest.makeDependencies(config: config) }
        #endif
        let url = (try? FileHistoryStore.defaultURL())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("HeyDrum-history-v1.json")
        let purchase = StoreKitPurchaseService(productID: config.removeAdsProductID)
        return AppDependencies(
            config: config,
            settings: SettingsStore(),
            sound: DrumSoundService(),
            speech: SystemSpeechService(),
            historyRepository: JSONHistoryRepository(store: FileHistoryStore(url: url)),
            purchase: purchase,
            ads: AdMobManager(config: config, purchase: purchase, consent: UMPConsentService(), sdk: GoogleMobileAdsStarter())
        )
    }

    /// Everything that must run once at launch. None of it blocks the UI (UC-01).
    func startUp() async {
        try? sound.preload()
        if launchGreetingEnabled { coordinator.startGreeting(voices: speech.availableJapaneseVoices(), hold: greetingHold) }
        async let historyLoad: Void = history.reload()
        purchase.startObservingTransactions()
        async let products: Void = purchase.loadProduct()
        await purchase.refreshEntitlements()
        await ads.start()
        await historyLoad
        await products
    }
}

#if DEBUG
/// `-uitest` launch arguments used by HeyDrumUITests (fake services, deterministic data).
struct UITestLaunch {
    var purchased = false
    var historyCount = 0
    var sampleHistory = false
    var greeting = false
    var readingFont = ReadingFont.system
    var textScale = 1.0
    var chunkInterval: Double = 0.35
    var fakeSpeechAutoStart = true

    static func parse(_ args: [String]) -> UITestLaunch? {
        guard args.contains("-uitest") else { return nil }
        var launch = UITestLaunch()
        launch.purchased = args.contains("-uitest-purchased")
        launch.sampleHistory = args.contains("-uitest-history-sample")
        launch.greeting = args.contains("-uitest-greeting")
        if let i = args.firstIndex(of: "-uitest-reading-font"), i + 1 < args.count { launch.readingFont = ReadingFont.from(args[i + 1]) }
        if let i = args.firstIndex(of: "-uitest-text-scale"), i + 1 < args.count, let v = Double(args[i + 1]) { launch.textScale = v }
        if let i = args.firstIndex(of: "-uitest-chunk-interval"), i + 1 < args.count, let v = Double(args[i + 1]) { launch.chunkInterval = v }
        if let i = args.firstIndex(of: "-uitest-history-count"), i + 1 < args.count, let n = Int(args[i + 1]) {
            launch.historyCount = n
        }
        return launch
    }

    @MainActor
    func makeDependencies(config: AppConfig) -> AppDependencies {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = ["本日は晴天なり", "いってらっしゃい", "お疲れさまでした", "また明日", "次は13時45分です", "ご来店ありがとうございました"]
        let now = Date()
        let sampleItems = samples.enumerated().map { i, text in
            let t = now.addingTimeInterval(-Double(i) * 1800)
            return HistoryEntry(id: UUID(), text: text, createdAt: t, lastPlayedAt: t)
        }
        let items = sampleHistory ? sampleItems : (0..<historyCount).map { i in
            HistoryEntry(id: UUID(), text: "履歴テスト\(i + 1)", createdAt: base.addingTimeInterval(Double(i)), lastPlayedAt: base.addingTimeInterval(Double(i)))
        }
        let speech = FakeSpeechService()
        speech.autoStart = fakeSpeechAutoStart
        speech.autoRanges = true
        speech.chunkInterval = chunkInterval
        let purchase = FakePurchaseService(entitlement: purchased ? .purchased : .free)
        let defaults = UserDefaults(suiteName: "heydrum.uitest.\(UUID().uuidString)") ?? .standard
        if greeting {
            speech.voices.append(SpeechVoiceOption(id: "fake.eddy", displayName: "Eddy"))
            speech.autoFinish = true
        }
        let store = SettingsStore(defaults: defaults)
        store.readingFont = readingFont
        store.readingTextScale = textScale
        let deps = AppDependencies(
            config: config,
            settings: store,
            sound: FakeSoundService(),
            speech: speech,
            historyRepository: InMemoryHistoryRepository(items: items),
            purchase: purchase,
            ads: AdMobManager(config: config, purchase: purchase, consent: FakeConsentService(canRequestAds: false), sdk: FakeAdSDK())
        )
        deps.launchGreetingEnabled = greeting
        deps.greetingHold = 6
        return deps
    }
}
#endif
