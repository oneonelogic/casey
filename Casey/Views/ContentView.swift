import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var depth = 10
    @State private var playlistName = ""
    @State private var stage: Stage = .idle
    @State private var matches: [PlaylistBuilder.Match] = []
    @State private var skippedWeeks = 0

    private static let depths = [5, 10, 25, 40, 100]

    enum Stage: Equatable {
        case idle
        case fetchingCharts(done: Int, total: Int)
        case matching(done: Int, total: Int)
        case creating
        case done(playlistName: String, added: Int, missed: Int)
        case failed(String)

        var isRunning: Bool {
            switch self {
            case .fetchingCharts, .matching, .creating: return true
            default: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Picker("Chart depth", selection: $depth) {
                    ForEach(Self.depths, id: \.self) { Text("Top \($0)").tag($0) }
                }
                .pickerStyle(.segmented)

                DatePicker("From", selection: $startDate, in: chartEra, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: chartEra, displayedComponents: .date)

                TextField("Playlist name", text: $playlistName, prompt: Text(defaultPlaylistName))
            }
            .disabled(stage.isRunning)

            HStack {
                Button(action: build) {
                    Label("Build Playlist", systemImage: "music.note.list")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(stage.isRunning || startDate > endDate)

                Spacer()
                statusView
            }

            if !matches.isEmpty {
                resultsList
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .navigationTitle("Casey")
    }

    private var chartEra: ClosedRange<Date> {
        BillboardClient.dateFormatter.date(from: "1958-08-02")! ... Date.now
    }

    private var defaultPlaylistName: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return "Top \(depth): \(f.string(from: startDate)) – \(f.string(from: endDate))"
    }

    @ViewBuilder private var statusView: some View {
        switch stage {
        case .idle:
            EmptyView()
        case .fetchingCharts(let done, let total):
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .frame(width: 160)
            Text("Fetching charts \(done)/\(total)").monospacedDigit()
        case .matching(let done, let total):
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .frame(width: 160)
            Text("Matching songs \(done)/\(total)").monospacedDigit()
        case .creating:
            ProgressView().controlSize(.small)
            Text("Creating playlist…")
        case .done(let name, let added, let missed):
            Label("Created “\(name)” — \(added) songs\(missed > 0 ? ", \(missed) unmatched" : "")",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var resultsList: some View {
        List(matches) { match in
            HStack {
                Image(systemName: match.isConfident ? "checkmark.circle" : "questionmark.circle")
                    .foregroundStyle(match.isConfident ? .green : .orange)
                VStack(alignment: .leading) {
                    Text(match.candidate.song).fontWeight(.medium)
                    Text(match.candidate.artist).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("peak #\(match.candidate.bestPosition)")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                if match.song == nil {
                    Text("no match").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .frame(minHeight: 200)
    }

    private func build() {
        let name = playlistName.isEmpty ? defaultPlaylistName : playlistName
        let (start, end, depth) = (startDate, endDate, depth)
        matches = []
        stage = .fetchingCharts(done: 0, total: 0)

        Task {
            guard await PlaylistBuilder.requestAuthorization() else {
                stage = .failed("Apple Music access was not authorized.")
                return
            }
            do {
                let (candidates, skipped) = try await BillboardClient().topSongs(
                    from: start, to: end, depth: depth
                ) { done, total in
                    Task { @MainActor in stage = .fetchingCharts(done: done, total: total) }
                }
                skippedWeeks = skipped
                guard !candidates.isEmpty else {
                    stage = .failed("No chart entries found in that range.")
                    return
                }

                stage = .matching(done: 0, total: candidates.count)
                let results = await PlaylistBuilder.matchAll(candidates) { done, total in
                    Task { @MainActor in stage = .matching(done: done, total: total) }
                }
                matches = results

                stage = .creating
                let matched = results.filter { $0.song != nil }
                let description = "Billboard Hot 100 top \(depth), "
                    + "\(BillboardClient.dateFormatter.string(from: start)) to "
                    + "\(BillboardClient.dateFormatter.string(from: end)). Built by Casey."
                _ = try await PlaylistBuilder.createPlaylist(named: name, description: description, from: results)
                stage = .done(playlistName: name, added: matched.count, missed: results.count - matched.count)
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
