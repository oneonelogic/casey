# Casey — project context

macOS SwiftUI app that builds Apple Music playlists from Billboard Hot 100 history. User picks a chart depth (top 5/10/25/40/100) and a date range; the app fetches each weekly chart in the range, takes the top n per week, dedupes across weeks, and creates the playlist via MusicKit. Named for Casey Kasem (American Top 40).

## Business identity

Ships under **OneOneLogic LLC** (formation in progress as of July 2026).

- Bundle ID: `com.oneonelogic.casey`
- GitHub: private repo at https://github.com/oneonelogic/casey (org `oneonelogic`, owned by personal account `gconz`)
- Apple: currently a personal developer account. For an App Store release under the LLC name: get a D-U-N-S number once the LLC is official, then an organization Apple Developer membership. App IDs don't transfer easily between accounts — if LLC release is the goal, register the MusicKit App ID under the org account when it exists (use a `.dev`-suffixed bundle ID for interim dev builds if needed).

## Data source

[mhollingshead/billboard-hot-100](https://github.com/mhollingshead/billboard-hot-100) — free JSON, no key, updated daily, covers Aug 1958 → present. Charts are dated Saturdays.

- Latest week: `https://raw.githubusercontent.com/mhollingshead/billboard-hot-100/main/recent.json`
- Specific week: `.../main/date/YYYY-MM-DD.json` (404 = no chart that week; treat as skipped, not fatal)
- Entry fields: `song`, `artist`, `this_week`, `last_week` (null for debuts), `peak_position`, `weeks_on_chart`

## Architecture

- `Casey/Models/` — `ChartWeek`/`ChartEntry` (Codable, snake_case keys), `SongCandidate` (deduped song; normalized `song|artist` dedupe key, tracks best position and weeks in range)
- `Casey/Services/BillboardClient.swift` — Foundation-only: Saturday date math (UTC calendar), concurrent week fetches (capped at 6), top-n reduce + dedupe. Deliberately has no MusicKit import so it compiles with the CLI toolchain for testing.
- `Casey/Services/PlaylistBuilder.swift` — MusicKit: authorization, catalog search per candidate (concurrency 4), match scoring by token overlap (title 0.65 / artist 0.35 — chart artist strings like "A Featuring B" rarely equal catalog strings), playlist creation via `MusicLibrary.shared.createPlaylist`.
- `Casey/Views/ContentView.swift` — depth picker, date range (clamped to chart era 1958-08-02→now), staged progress (fetch/match/create), results list flagging matches with confidence < 0.5.

## Build

Project is generated — edit `project.yml`, then run `xcodegen generate`. Don't hand-edit `Casey.xcodeproj`. Requires Xcode (MusicKit); target macOS 14+.

Core logic can be smoke-tested without Xcode:
`swiftc -parse-as-library Casey/Models/*.swift Casey/Services/BillboardClient.swift <test harness with @main> && ./…`
(Verified 2026-07-16 against live data: June 1988 top-10 → 17 unique songs.)

## Status / next steps

- [x] Scaffold, core logic verified, repo pushed
- [ ] Enable MusicKit app service on the App ID in the Apple developer portal
- [ ] Select signing team in Xcode (Signing & Capabilities), build & run
- [ ] First real end-to-end test: authorize Apple Music, build a playlist, check match quality
- [ ] Open design questions: playlist ordering (currently first-appearance chronological), manual review UI for low-confidence matches, local chart caching for re-runs

## Notes

Longer-form notes live in the Obsidian vault: `~/Documents/gconz_obsidian_vault/personal/casey/Casey - Project Overview.md` (keep its Log section updated with milestones).
