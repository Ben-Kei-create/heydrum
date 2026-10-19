import AVFoundation

/// Two bundled WAVs, pooled `AVAudioPlayer`s (max 4 per sound). One `play` call = one sound (docs/04 §5).
@MainActor
final class DrumSoundService: SoundProviding {
    static let poolSize = 4

    private struct Slot {
        var players: [AVAudioPlayer] = []
        var startOrder: [ObjectIdentifier: UInt64] = [:]
    }

    private let bundle: Bundle
    private var slots: [SoundKind: Slot] = [:]
    private var counter: UInt64 = 0

    init(bundle: Bundle = .main) { self.bundle = bundle }

    static func fileName(for kind: SoundKind) -> String {
        switch kind {
        case .drum: "drum"
        case .metal: "metal"
        }
    }

    func preload() throws {
        AudioSessionConfigurator.activate()
        for kind in SoundKind.allCases where slots[kind] == nil {
            guard let url = bundle.url(forResource: Self.fileName(for: kind), withExtension: "wav") else {
                throw CocoaError(.fileNoSuchFile)
            }
            var slot = Slot()
            for _ in 0..<Self.poolSize {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                slot.players.append(player)
            }
            slots[kind] = slot
        }
    }

    func play(_ sound: SoundKind, volume: Float) {
        if slots[sound] == nil { try? preload() }
        guard var slot = slots[sound] else { return }
        let player = slot.players.first(where: { !$0.isPlaying })
            ?? slot.players.min(by: { (slot.startOrder[ObjectIdentifier($0)] ?? 0) < (slot.startOrder[ObjectIdentifier($1)] ?? 0) })
        guard let player else { return }
        counter += 1
        slot.startOrder[ObjectIdentifier(player)] = counter
        slots[sound] = slot
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = SettingsStore.clamp(volume)
        player.play()
    }

    func stopAll() {
        for slot in slots.values { slot.players.forEach { $0.stop(); $0.currentTime = 0 } }
    }
}
