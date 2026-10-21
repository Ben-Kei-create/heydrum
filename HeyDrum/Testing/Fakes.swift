#if DEBUG
import Foundation
import Observation

// Test doubles live in the app target (DEBUG only) so UI tests can launch the app with them injected
// via `LaunchMode` and previews/unit tests share one implementation.

actor InMemoryHistoryRepository: HistoryRepository {
    private var items: [HistoryEntry]
    private(set) var failWrites = false
    private(set) var failReads = false
    private var makeID: @Sendable () -> UUID

    init(items: [HistoryEntry] = [], makeID: @escaping @Sendable () -> UUID = { UUID() }) {
        self.items = JSONHistoryRepository.sorted(items)
        self.makeID = makeID
    }

    func setFailWrites(_ v: Bool) { failWrites = v }
    func setFailReads(_ v: Bool) { failReads = v }

    func list() async throws -> [HistoryEntry] {
        if failReads { throw HistoryError.corrupt }
        return items
    }

    func appendNew(text: String, at: Date) async throws -> HistoryEntry {
        guard let normalized = SpeechText.normalized(text) else { throw HistoryError.invalidText }
        if failWrites { throw HistoryError.writeFailed }
        let entry = HistoryEntry(id: makeID(), text: normalized, createdAt: at, lastPlayedAt: at)
        items = JSONHistoryRepository.sortedAndPruned(items + [entry])
        return entry
    }

    func markPlayed(id: UUID, at: Date) async throws {
        guard let i = items.firstIndex(where: { $0.id == id }) else { throw HistoryError.notFound }
        if failWrites { throw HistoryError.writeFailed }
        items[i].lastPlayedAt = at
        items = JSONHistoryRepository.sorted(items)
    }

    func delete(id: UUID) async throws {
        if failWrites { throw HistoryError.writeFailed }
        guard items.contains(where: { $0.id == id }) else { throw HistoryError.notFound }
        items.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        if failWrites { throw HistoryError.writeFailed }
        items = []
    }

    func resetCorruptStore() async throws { failReads = false; items = [] }
}

@MainActor
final class FakeSoundService: SoundProviding {
    private(set) var played: [(SoundKind, Float)] = []
    private(set) var preloadCount = 0
    private(set) var stopAllCount = 0
    var preloadError: Error?

    func preload() throws { preloadCount += 1; if let preloadError { throw preloadError } }
    func play(_ sound: SoundKind, volume: Float) { played.append((sound, volume)) }
    func stopAll() { stopAllCount += 1 }
}

@MainActor
final class FakeSpeechService: SpeechProviding {
    struct SpeakCall: Equatable {
        let sessionID: UUID
        let text: String
        let voiceID: String?
        let volume: Float
        let speed: SpeechSpeed
    }

    let events: AsyncStream<SpeechEvent>
    private let continuation: AsyncStream<SpeechEvent>.Continuation
    private(set) var calls: [SpeakCall] = []
    private(set) var stopCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    var voices: [SpeechVoiceOption] = [SpeechVoiceOption(id: "fake.ja.1", displayName: "テスト音声")]
    var readinessError: SpeechError?
    var speakError: SpeechError?
    var pauseResult = true
    var resumeResult = true
    /// When true, `.started` is emitted automatically after every `speak` (UI tests).
    var autoStart = false
    /// When true (UI tests), range notifications are emitted progressively after `.started`, like the real engine.
    var autoRanges = false
    /// When true (UI tests), `.finished` follows the last range.
    var autoFinish = false
    var chunkInterval: TimeInterval = 0.35
    private var autoPaused = false
    private var autoTask: Task<Void, Never>?

    init() {
        var c: AsyncStream<SpeechEvent>.Continuation!
        events = AsyncStream { c = $0 }
        continuation = c
    }

    func send(_ event: SpeechEvent) { continuation.yield(event) }
    var lastSessionID: UUID? { calls.last?.sessionID }

    func availableJapaneseVoices() -> [SpeechVoiceOption] { voices }
    func verifyReadiness(voiceID: String?) throws { if let readinessError { throw readinessError } }

    func speak(sessionID: UUID, text: String, voiceID: String?, volume: Float, speed: SpeechSpeed) throws {
        if let speakError { throw speakError }
        calls.append(SpeakCall(sessionID: sessionID, text: text, voiceID: voiceID, volume: volume, speed: speed))
        autoTask?.cancel()
        autoPaused = false
        if autoStart { continuation.yield(.started(sessionID: sessionID)) }
        if autoStart && autoRanges { runAutoRanges(session: sessionID, text: text) }
    }

    private func runAutoRanges(session: UUID, text: String) {
        let characters = Array(text)
        let chunk = max(3, characters.count / 8)
        autoTask = Task { @MainActor [weak self] in
            var location = 0
            var index = 0
            while index < characters.count {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.chunkInterval * 1_000_000_000))
                if Task.isCancelled { return }
                while self.autoPaused {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    if Task.isCancelled { return }
                }
                let slice = characters[index..<min(index + chunk, characters.count)]
                let length = slice.reduce(0) { $0 + String($1).utf16.count }
                self.continuation.yield(.range(sessionID: session, location: location, length: length))
                location += length
                index += chunk
            }
            if self?.autoFinish == true { self?.continuation.yield(.finished(sessionID: session)) }
        }
    }

    func pause() -> Bool { pauseCount += 1; if pauseResult { autoPaused = true }; return pauseResult }
    func resume() -> Bool { resumeCount += 1; if resumeResult { autoPaused = false }; return resumeResult }
    func stop() { stopCount += 1; autoTask?.cancel() }
}

@MainActor @Observable
final class FakePurchaseService: PurchaseProviding {
    var entitlement: EntitlementState
    var productState: ProductLoadState = .loaded(displayPrice: "¥480")
    var isBusy = false
    var statusMessage: String?
    var nextPurchaseOutcome: PurchaseOutcome = .purchased
    var nextRestoreOutcome: RestoreOutcome = .restored
    private(set) var observeCount = 0
    private(set) var restoreCount = 0
    private(set) var purchaseCount = 0

    init(entitlement: EntitlementState = .free) { self.entitlement = entitlement }

    func startObservingTransactions() { observeCount += 1 }
    func refreshEntitlements() async {}
    func loadProduct() async {}

    func purchaseRemoveAds() async -> PurchaseOutcome {
        purchaseCount += 1
        if nextPurchaseOutcome == .purchased { entitlement = .purchased }
        return nextPurchaseOutcome
    }

    func restore() async -> RestoreOutcome {
        restoreCount += 1
        if nextRestoreOutcome == .restored { entitlement = .purchased }
        return nextRestoreOutcome
    }
}
#endif
