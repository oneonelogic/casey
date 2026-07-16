import Foundation

/// One week of the Billboard Hot 100, as served by
/// https://github.com/mhollingshead/billboard-hot-100
struct ChartWeek: Codable {
    let date: String
    let data: [ChartEntry]
}

struct ChartEntry: Codable, Hashable {
    let song: String
    let artist: String
    let thisWeek: Int
    let lastWeek: Int?
    let peakPosition: Int
    let weeksOnChart: Int

    enum CodingKeys: String, CodingKey {
        case song, artist
        case thisWeek = "this_week"
        case lastWeek = "last_week"
        case peakPosition = "peak_position"
        case weeksOnChart = "weeks_on_chart"
    }
}
