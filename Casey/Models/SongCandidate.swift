import Foundation

/// A unique song drawn from one or more chart weeks, ready to be matched
/// against the Apple Music catalog.
struct SongCandidate: Identifiable {
    let id = UUID()
    let song: String
    let artist: String
    /// Date of the first chart week (within the selected range) the song appeared in.
    let firstChartDate: Date
    /// Best (lowest) position reached within the selected range and depth.
    var bestPosition: Int
    /// Number of selected weeks the song appeared in at or above the chosen depth.
    var weeksInRange: Int

    var dedupeKey: String {
        Self.normalize(song) + "|" + Self.normalize(artist)
    }

    /// Lowercases, strips diacritics and punctuation, and collapses whitespace
    /// so "Livin' On A Prayer" and "Livin On A Prayer" dedupe together.
    static func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
