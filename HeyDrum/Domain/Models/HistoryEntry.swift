import Foundation

struct HistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    var lastPlayedAt: Date
}

/// Text rules shared by the editor, the repository and the speech layer (FR-004, FR-011).
enum SpeechText {
    static let maxLength = 500

    /// Trimmed text, or nil when empty / whitespace only / over the limit.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        return trimmed
    }

    /// Cuts to `maxLength` grapheme clusters (Swift `Character`s); returns whether it was cut.
    static func clamped(_ raw: String) -> (text: String, wasTruncated: Bool) {
        guard raw.count > maxLength else { return (raw, false) }
        return (String(raw.prefix(maxLength)), true)
    }
}
