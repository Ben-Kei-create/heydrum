import XCTest
@testable import HeyDrum

/// Polls until `condition` holds (MainActor), failing the test on timeout.
@MainActor
func waitUntil(_ message: String = "condition", timeout: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line,
               _ condition: @MainActor () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline { XCTFail("Timed out waiting for \(message)", file: file, line: line); return }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

/// Lets queued AsyncStream deliveries run so "nothing happened" assertions are meaningful.
@MainActor
func settle() async {
    for _ in 0..<20 { await Task.yield() }
    try? await Task.sleep(nanoseconds: 30_000_000)
}

final class MemoryHistoryStore: HistoryFileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var _failWrites = false
    private(set) var writeCount = 0
    private(set) var quarantined: [String] = []

    init(data: Data? = nil) { self.data = data }

    var failWrites: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _failWrites }
        set { lock.lock(); _failWrites = newValue; lock.unlock() }
    }
    var current: Data? { lock.lock(); defer { lock.unlock() }; return data }

    func read() throws -> Data? { lock.lock(); defer { lock.unlock() }; return data }

    func write(_ newData: Data) throws {
        lock.lock(); defer { lock.unlock() }
        if _failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        data = newData
        writeCount += 1
    }

    func quarantine(suffix: String) throws {
        lock.lock(); defer { lock.unlock() }
        quarantined.append(suffix)
        data = nil
    }
}

@MainActor
struct AppHarness {
    let deps: AppDependencies
    let speech: FakeSpeechService
    let sound: FakeSoundService
    let purchase: FakePurchaseService
    let history: InMemoryHistoryRepository
    let settings: SettingsStore

    static func make(entitlement: EntitlementState = .free, items: [HistoryEntry] = [],
                     consent: FakeConsentService? = nil) -> AppHarness {
        let speech = FakeSpeechService()
        let sound = FakeSoundService()
        let purchase = FakePurchaseService(entitlement: entitlement)
        let repo = InMemoryHistoryRepository(items: items)
        let defaults = UserDefaults(suiteName: "heydrum.tests.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        let config = AppConfig(adUnitID: "ca-app-pub-3940256099942544/2435281174", adsTestMode: true, removeAdsProductID: "test.remove_ads")
        let ads = AdMobManager(config: config, purchase: purchase, consent: consent ?? FakeConsentService(canRequestAds: true),
                               sdk: FakeAdSDK(), makeBanner: { FakeBannerController() })
        let deps = AppDependencies(config: config, settings: settings, sound: sound, speech: speech,
                                   historyRepository: repo, purchase: purchase, ads: ads)
        return AppHarness(deps: deps, speech: speech, sound: sound, purchase: purchase, history: repo, settings: settings)
    }
}
