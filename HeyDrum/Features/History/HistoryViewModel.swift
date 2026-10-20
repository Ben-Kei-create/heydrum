import Foundation
import Observation

enum HistoryLoadProblem: Equatable {
    case corrupt
    case unsupportedSchema
}

/// Single source of truth for history on screen (History tab and the editor's recent list).
@MainActor @Observable
final class HistoryViewModel {
    private(set) var entries: [HistoryEntry] = []
    private(set) var loadProblem: HistoryLoadProblem?
    var message: String?

    @ObservationIgnored private let repository: HistoryRepository
    @ObservationIgnored private let now: () -> Date
    /// Wired by the composition root: readiness check and navigation (kept out of the VM's concerns).
    @ObservationIgnored var epoch: () -> Int = { 0 }
    @ObservationIgnored var verifyReadiness: () throws -> Void = {}
    @ObservationIgnored var openPlayback: (HistoryEntry) -> Void = { _ in }

    init(repository: HistoryRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    func reload() async {
        do {
            entries = try await repository.list()
            loadProblem = nil
        } catch HistoryError.unsupportedSchema {
            entries = []
            loadProblem = .unsupportedSchema
        } catch {
            entries = []
            loadProblem = .corrupt
        }
    }

    /// New speech from the editor: a new row (even for identical text). Throws on failure; nothing is changed.
    func addNew(text: String) async throws -> HistoryEntry {
        let entry = try await repository.appendNew(text: text, at: now())
        entries = (try? await repository.list()) ?? entries
        return entry
    }

    /// Replaying from history: same ID, count unchanged, row moves to the top.
    func play(_ entry: HistoryEntry) async {
        let startEpoch = epoch()
        do {
            try verifyReadiness()
        } catch {
            message = "日本語の音声が見つかりません。iOSの設定で日本語音声を追加してください。"
            return
        }
        do {
            try await repository.markPlayed(id: entry.id, at: now())
            entries = try await repository.list()
        } catch {
            message = "履歴を更新できません。空き容量などを確認してください"
            return
        }
        guard epoch() == startEpoch else { return }   // interrupted while updating: do not start
        openPlayback(entry)
    }

    func delete(_ entry: HistoryEntry) async {
        do {
            try await repository.delete(id: entry.id)
            entries = try await repository.list()
        } catch {
            message = "履歴を削除できません"
        }
    }

    func deleteAll() async {
        do {
            try await repository.deleteAll()
            entries = try await repository.list()
        } catch {
            message = "履歴を削除できません"
        }
    }

    /// Explicit user action only ("履歴を初期化").
    func resetCorruptStore() async {
        do {
            try await repository.resetCorruptStore()
            await reload()
        } catch {
            message = "履歴を初期化できません"
        }
    }
}
