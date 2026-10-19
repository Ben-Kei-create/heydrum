import Foundation

/// Byte-level storage behind the repository, so write failures can be injected in tests.
protocol HistoryFileStore: Sendable {
    func read() throws -> Data?
    func write(_ data: Data) throws
    /// Moves the current file aside; returns nothing if there was no file.
    func quarantine(suffix: String) throws
}

struct FileHistoryStore: HistoryFileStore {
    let url: URL

    static func defaultURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent("HeyDrum", isDirectory: true).appendingPathComponent("history-v1.json")
    }

    func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func quarantine(suffix: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let target = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + suffix)
        try FileManager.default.moveItem(at: url, to: target)
    }
}

/// History persisted as `history-v1.json`. All reads/writes are serialised by the actor (docs/05).
actor JSONHistoryRepository: HistoryRepository {
    static let maxItems = 100
    static let schemaVersion = 1

    private struct Envelope: Codable {
        var schemaVersion: Int
        var items: [HistoryEntry]
    }

    private let store: HistoryFileStore
    private let makeID: @Sendable () -> UUID
    private var items: [HistoryEntry] = []
    private var loaded = false

    init(store: HistoryFileStore, makeID: @escaping @Sendable () -> UUID = { UUID() }) {
        self.store = store
        self.makeID = makeID
    }

    // MARK: HistoryRepository

    func list() async throws -> [HistoryEntry] {
        try loadIfNeeded()
        return items
    }

    func appendNew(text: String, at date: Date) async throws -> HistoryEntry {
        guard let normalized = SpeechText.normalized(text) else { throw HistoryError.invalidText }
        try loadIfNeeded()
        let entry = HistoryEntry(id: makeID(), text: normalized, createdAt: date, lastPlayedAt: date)
        let next = Self.sortedAndPruned(items + [entry])
        try persist(next)
        items = next
        return entry
    }

    func markPlayed(id: UUID, at date: Date) async throws {
        try loadIfNeeded()
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw HistoryError.notFound }
        var next = items
        next[index].lastPlayedAt = date
        next = Self.sortedAndPruned(next)
        try persist(next)
        items = next
    }

    func delete(id: UUID) async throws {
        try loadIfNeeded()
        guard items.contains(where: { $0.id == id }) else { throw HistoryError.notFound }
        let next = items.filter { $0.id != id }
        try persist(next)
        items = next
    }

    func deleteAll() async throws {
        try loadIfNeeded()
        try persist([])
        items = []
    }

    func resetCorruptStore() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        do { try store.quarantine(suffix: ".corrupt-\(stamp)") } catch { throw HistoryError.writeFailed }
        items = []
        loaded = true
    }

    // MARK: Internals

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        let data: Data?
        do { data = try store.read() } catch { throw HistoryError.corrupt }
        guard let data else {
            items = []
            loaded = true
            return
        }
        // `loaded` stays false on failure, so a corrupt file is never overwritten by a later append.
        let envelope: Envelope
        do { envelope = try Self.decoder.decode(Envelope.self, from: data) } catch { throw HistoryError.corrupt }
        guard envelope.schemaVersion == Self.schemaVersion else { throw HistoryError.unsupportedSchema(envelope.schemaVersion) }
        var seen = Set<UUID>()
        for item in envelope.items {
            guard seen.insert(item.id).inserted, SpeechText.normalized(item.text) != nil else { throw HistoryError.corrupt }
        }
        items = Self.sorted(envelope.items)
        loaded = true
    }

    private func persist(_ next: [HistoryEntry]) throws {
        do {
            let data = try Self.encoder.encode(Envelope(schemaVersion: Self.schemaVersion, items: next))
            try store.write(data)
        } catch {
            throw HistoryError.writeFailed
        }
    }

    static func sorted(_ list: [HistoryEntry]) -> [HistoryEntry] {
        list.sorted { a, b in
            if a.lastPlayedAt != b.lastPlayedAt { return a.lastPlayedAt > b.lastPlayedAt }
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    static func sortedAndPruned(_ list: [HistoryEntry]) -> [HistoryEntry] {
        Array(sorted(list).prefix(maxItems))
    }

    // ISO8601 with fractional seconds so ordering survives a restart.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(isoFormatter().string(from: date))
        }
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = isoFormatter().date(from: s) ?? ISO8601DateFormatter().date(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad date")
            }
            return date
        }
        return d
    }()

    private static func isoFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }
}
