# Casey

A native macOS app that builds Apple Music playlists from Billboard Hot 100 history — named for Casey Kasem of American Top 40.

Pick a chart depth (top 5, 10, 25, …) and a date range. Casey fetches every weekly Hot 100 chart in that range, takes the top *n* from each week, dedupes across weeks, and creates an Apple Music playlist from the result.

## How it works

- **Chart data:** [mhollingshead/billboard-hot-100](https://github.com/mhollingshead/billboard-hot-100) — free JSON, updated daily, covers August 1958 to present.
  - Latest week: `https://raw.githubusercontent.com/mhollingshead/billboard-hot-100/main/recent.json`
  - Specific week: `.../main/date/YYYY-MM-DD.json`
  - Entry fields: `song`, `artist`, `this_week`, `last_week`, `peak_position`, `weeks_on_chart`
- **Playlist creation:** Apple's MusicKit framework (native Swift) — catalog search to resolve song/artist pairs to catalog IDs, then playlist creation in the user's library.

## Requirements

- macOS, Xcode
- Apple Developer Program membership (MusicKit entitlement on the App ID)
- An Apple Music subscription on the account that authorizes the app

## Status

Early scaffolding — see the `casey` folder in the Obsidian vault for design notes.
