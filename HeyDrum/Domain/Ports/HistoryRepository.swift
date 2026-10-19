import Foundation

enum HistoryError: Error, Equatable {
    case invalidText
    case notFound
    case writeFailed
    /// The stored file could not be decoded. The original file is left untouched.
    case corrupt
    /// `schemaVersion` is not supported. The original file is left untouched.
    case unsupportedSchema(Int)
}

protocol HistoryRepository: Sendable {
    func list() async throws -> [HistoryEntry]
    func appendNew(text: String, at: Date) async throws -> HistoryEntry
    func markPlayed(id: UUID, at: Date) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    /// Explicit user action only: moves a corrupt file aside (`.corrupt-TIMESTAMP`) and starts empty.
    func resetCorruptStore() async throws
}
