import Foundation

/// Fetches weekly Hot 100 charts from the mhollingshead/billboard-hot-100
/// GitHub repo and reduces a date range to a deduped list of song candidates.
struct BillboardClient {
    static let base = URL(string: "https://raw.githubusercontent.com/mhollingshead/billboard-hot-100/main")!

    /// Charts have been dated on Saturdays for the repo's whole history
    /// (Aug 1958 → present).
    static let chartWeekday = 7 // Calendar weekday: 1 = Sunday … 7 = Saturday

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static var utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// All chart dates (Saturdays) falling within [start, end], inclusive.
    static func chartDates(from start: Date, to end: Date) -> [Date] {
        let cal = utcCalendar
        var day = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        var dates: [Date] = []
        // Advance to the first Saturday on or after `start`.
        while cal.component(.weekday, from: day) != chartWeekday {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { return dates }
            day = next
        }
        while day <= last {
            dates.append(day)
            guard let next = cal.date(byAdding: .day, value: 7, to: day) else { break }
            day = next
        }
        return dates
    }

    /// Fetches one chart week. Returns nil if the repo has no chart for that
    /// date (404) — callers count these as skipped weeks rather than failures.
    func fetchWeek(_ date: Date) async throws -> ChartWeek? {
        let dateString = Self.dateFormatter.string(from: date)
        let url = Self.base.appendingPathComponent("date/\(dateString).json")
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return nil
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ChartWeek.self, from: data)
    }

    /// Fetches every chart week in the range and reduces the top `depth`
    /// entries of each week into a deduped, chronologically ordered candidate
    /// list. `progress` is called after each week completes (fetched count,
    /// total weeks).
    func topSongs(
        from start: Date,
        to end: Date,
        depth: Int,
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async throws -> (candidates: [SongCandidate], skippedWeeks: Int) {
        let dates = Self.chartDates(from: start, to: end)
        var weeks: [ChartWeek] = []
        var skipped = 0

        try await withThrowingTaskGroup(of: ChartWeek?.self) { group in
            var iterator = dates.makeIterator()
            var inFlight = 0
            var completed = 0
            // Cap concurrent fetches to be polite to raw.githubusercontent.com.
            while inFlight < 6, let date = iterator.next() {
                group.addTask { try await fetchWeek(date) }
                inFlight += 1
            }
            while let result = try await group.next() {
                completed += 1
                progress(completed, dates.count)
                if let week = result { weeks.append(week) } else { skipped += 1 }
                if let date = iterator.next() {
                    group.addTask { try await fetchWeek(date) }
                }
            }
        }

        weeks.sort { $0.date < $1.date }

        var byKey: [String: SongCandidate] = [:]
        var order: [String] = []
        for week in weeks {
            guard let weekDate = Self.dateFormatter.date(from: week.date) else { continue }
            for entry in week.data where entry.thisWeek <= depth {
                let candidate = SongCandidate(
                    song: entry.song,
                    artist: entry.artist,
                    firstChartDate: weekDate,
                    bestPosition: entry.thisWeek,
                    weeksInRange: 1
                )
                if var existing = byKey[candidate.dedupeKey] {
                    existing.bestPosition = min(existing.bestPosition, entry.thisWeek)
                    existing.weeksInRange += 1
                    byKey[candidate.dedupeKey] = existing
                } else {
                    byKey[candidate.dedupeKey] = candidate
                    order.append(candidate.dedupeKey)
                }
            }
        }
        return (order.compactMap { byKey[$0] }, skipped)
    }
}
