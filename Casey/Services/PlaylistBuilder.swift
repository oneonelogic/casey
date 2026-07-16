import Foundation
import MusicKit

/// Resolves song candidates against the Apple Music catalog and creates the
/// playlist in the user's library.
struct PlaylistBuilder {

    struct Match: Identifiable {
        let id = UUID()
        let candidate: SongCandidate
        let song: Song?
        /// 0…1 — token overlap between the chart's title/artist and the catalog's.
        let confidence: Double

        var isConfident: Bool { song != nil && confidence >= 0.5 }
    }

    static func requestAuthorization() async -> Bool {
        await MusicAuthorization.request() == .authorized
    }

    /// Searches the catalog for the candidate and scores the best result.
    static func match(_ candidate: SongCandidate) async -> Match {
        var request = MusicCatalogSearchRequest(
            term: "\(candidate.song) \(candidate.artist)",
            types: [Song.self]
        )
        request.limit = 5
        do {
            let response = try await request.response()
            let scored = response.songs.map { song in
                (song, score(candidate: candidate, against: song))
            }
            if let best = scored.max(by: { $0.1 < $1.1 }) {
                return Match(candidate: candidate, song: best.0, confidence: best.1)
            }
            return Match(candidate: candidate, song: nil, confidence: 0)
        } catch {
            return Match(candidate: candidate, song: nil, confidence: 0)
        }
    }

    /// Matches all candidates with limited concurrency, reporting progress.
    static func matchAll(
        _ candidates: [SongCandidate],
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async -> [Match] {
        var matches: [Match] = []
        matches.reserveCapacity(candidates.count)
        await withTaskGroup(of: (Int, Match).self) { group in
            var iterator = candidates.enumerated().makeIterator()
            var inFlight = 0
            var completed = 0
            var indexed: [(Int, Match)] = []
            while inFlight < 4, let (i, c) = iterator.next() {
                group.addTask { (i, await match(c)) }
                inFlight += 1
            }
            while let result = await group.next() {
                completed += 1
                progress(completed, candidates.count)
                indexed.append(result)
                if let (i, c) = iterator.next() {
                    group.addTask { (i, await match(c)) }
                }
            }
            matches = indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return matches
    }

    /// Creates the playlist from every match that resolved to a catalog song.
    static func createPlaylist(named name: String, description: String, from matches: [Match]) async throws -> Playlist {
        let songs = matches.compactMap(\.song)
        return try await MusicLibrary.shared.createPlaylist(
            name: name,
            description: description,
            items: songs
        )
    }

    /// Token-overlap score between chart metadata and a catalog song, weighted
    /// toward the title. Chart artist strings ("A Featuring B") rarely equal
    /// catalog artist strings ("A feat. B"), so artist only needs partial overlap.
    private static func score(candidate: SongCandidate, against song: Song) -> Double {
        let titleScore = tokenOverlap(SongCandidate.normalize(candidate.song),
                                      SongCandidate.normalize(song.title))
        let artistScore = tokenOverlap(SongCandidate.normalize(candidate.artist),
                                       SongCandidate.normalize(song.artistName))
        return titleScore * 0.65 + artistScore * 0.35
    }

    private static func tokenOverlap(_ a: String, _ b: String) -> Double {
        let ta = Set(a.split(separator: " "))
        let tb = Set(b.split(separator: " "))
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        return Double(ta.intersection(tb).count) / Double(ta.union(tb).count)
    }
}
