import Foundation

enum SoundKind: CaseIterable, Sendable { case drum, metal }

@MainActor
protocol SoundProviding: AnyObject {
    func preload() throws
    func play(_ sound: SoundKind, volume: Float)
    func stopAll()
}
