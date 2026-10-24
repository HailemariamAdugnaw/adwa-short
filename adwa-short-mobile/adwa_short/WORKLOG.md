# ADWA SHORT — Worklog

## 2026-10-22 — Task 29-mobile-downloads — Offline Episode Download UI + Storage

### Scope
Implemented the offline episode download flow for the Flutter mobile app,
covering the storage layer, state provider, UI widgets, player integration,
profile entry point and routing.

### Files added
- `lib/core/services/download_service.dart` — Standalone download service.
  Defines `DownloadedEpisode` model (fromJson/toJson + `fileUri` getter),
  `DownloadAccessDeniedException`, and `DownloadService` with static methods:
  `getDownloadedEpisodes`, `downloadEpisode`, `deleteDownload`,
  `deleteAllDownloads`, `isDownloaded`, `getLocalPath`. Files are stored in
  `Directory.systemTemp/adwa_downloads/episode_<id>.mp4` (path_provider is
  not in pubspec.yaml so we use dart:io's system temp). Metadata is persisted
  as a JSON list in `shared_preferences` under key `downloaded_episodes`.
  Token request: `POST /downloads/tokens` with Bearer auth. On 403 the
  service throws `DownloadAccessDeniedException(message, reason)`. File
  download: streamed via `http.Client.send` to `GET /downloads/file/{token}`
  (no auth) and piped to a `File.openWrite()` sink.
- `lib/features/downloads/providers/download_provider.dart` —
  `ChangeNotifier` exposing `status`, `errorMessage`, `progress`,
  `downloadingEpisodeId`, `downloads`, `isDownloading`, plus
  `loadDownloads`, `downloadEpisode(episode, series, token)`,
  `deleteDownload`, `deleteAllDownloads`, `isDownloaded`, `getLocalPath`,
  `getFileUri`, `resetStatus`. Catches `DownloadAccessDeniedException` and
  surfaces it as `DownloadStatus.accessDenied`.
- `lib/features/downloads/widgets/download_button.dart` — `DownloadButton`
  stateful widget. Compact mode renders just an icon (download / done /
  spinner). Full mode renders a labeled pill button. Uses
  `context.watch<DownloadProvider>` for reactive UI, `TokenManager` for the
  auth token, surfaces the `PaywallOverlay` (same as the player) on
  `accessDenied`, shows a snackbar on success/error.
- `lib/features/downloads/screens/downloads_screen.dart` — Full screen with
  AppBar "Downloads", Clear All button (with confirmation dialog),
  pull-to-refresh, empty state (`EmptyState`), and per-episode tiles
  showing thumbnail (CachedNetworkImage), episode title, series title,
  EP.# badge, duration, success checkmark and a delete IconButton. Tapping
  a tile constructs an `Episode` with `videoUrl = file://<localPath>` and
  navigates to `AppRoutes.episodePlayer`.
- `test/download_service_test.dart` — 5 unit tests covering
  `DownloadedEpisode.fromJson`, `toJson` round-trip, `fileUri`, numeric
  string coercion, and `DownloadAccessDeniedException`.

### Files modified
- `lib/core/constants/api_constants.dart` — added `downloadTokens =
  '/downloads/tokens'` and `downloadFile = '/downloads/file'`.
- `lib/core/network/api_client.dart` — `resolveMediaUrl` now recognises the
  `file://` prefix and strips it, so local file paths are not rewritten to
  `http://<base>/...`.
- `lib/core/widgets/unified_video_player.dart` — added `import 'dart:io';`
  and updated `_initPlayer` to construct `VideoPlayerController.file(File(
  url))` when `widget.videoUrl.startsWith('file://')`, falling back to
  `networkUrl` for http URLs and `asset` for everything else. The resolved
  `url` (post-`resolveMediaUrl`) is used for the File path.
- `lib/core/router/app_router.dart` — added `downloads = '/profile/downloads'`.
- `lib/features/shorts/widgets/episode_selector_sheet.dart` — `_EpisodeButton`
  now takes a `series` parameter; a compact `DownloadButton` is rendered at
  the top-right corner of each unlocked, non-current episode cell (mirrors
  the lock badge layout). The episode Grid cell itself remains tappable to
  play. Container → DecoratedBox for lint compliance.
- `lib/features/profile/screens/profile_screen.dart` — added
  `onOpenDownloads` callback, refreshed `DownloadProvider` on init and
  pull-to-refresh, and a new `_downloadsTile()` ListTile with a reactive
  badge (`Consumer<DownloadProvider>`) showing the offline episode count.
- `lib/app.dart` — added route case for `AppRoutes.downloads` →
  `DownloadsScreen()`, wired `onOpenDownloads` in both the named-route
  ProfileScreen and the MainShell ProfileScreen.
- `lib/main.dart` — registered `ChangeNotifierProvider<DownloadProvider>`.
- `.env` — added minimal default `.env` (was missing from repo; required
  by `pubspec.yaml` asset bundle and `flutter_dotenv`).

### Tech decisions
- `path_provider` is NOT in `pubspec.yaml` and the task forbade modifying
  pubspec, so local files are stored under `Directory.systemTemp
  /adwa_downloads/`. On Android this resolves to the app's cache directory,
  which persists across app launches but not across reinstalls — acceptable
  for v1.
- `shared_preferences` stores the JSON list of `DownloadedEpisode` metadata
  so the Downloads screen can render offline without hitting the backend.
- The local file path is exposed to the player as a `file://` URI so
  `resolveMediaUrl` can recognise it without ambiguity with backend
  relative paths.
- The download token endpoint uses a raw `http.post` with Bearer auth
  (the ApiClient auto-refresh path does not gracefully surface 403
  access-denied bodies, so we bypass it for this single call).
- The file download itself uses `http.Client.send` + `stream.pipe(sink)`
  for streaming, no auth header (per the API contract).
- Locked episodes do NOT show a download icon in the selector sheet — the
  backend `/downloads/tokens` would 403 anyway, and the button's tap
  handler surfaces the paywall if access is denied at request time.

### Verification
- `flutter pub get` — succeeds.
- `flutter analyze` — 0 errors. 81 info/warning lints remain, all
  pre-existing (`prefer_const_constructors`, `use_build_context_synchronously`,
  `deprecated_member_use` on `activeColor`, missing `.env` asset warning
  prior to creation, `_position` unused field in unified_video_player that
  predates this task). No new issues introduced by the download feature
  files.
- `flutter test` — 34 tests pass (29 pre-existing + 5 new
  download_service tests).

### Next actions
- Wire a backend route for `POST /downloads/tokens` and
  `GET /downloads/file/{token}` (see `app/routers/`); the mobile client is
  ready to consume them.
- Add an in-progress download progress bar (the provider already exposes
  `progress`, but the streaming `pipe` does not yet report bytes received;
  switch to a manual byte-counting sink if a progress UI is desired).
- Consider migrating file storage to `path_provider`'s
  `getApplicationDocumentsDirectory()` once it can be added to pubspec, so
  downloads survive cache eviction.

## 2026-10-22 — Task 30-episode-nav-fix — Episode Nav, Bottom Sheet + Download Placement

### Scope
Fixed three UX issues in the Shorts tab and Full Series Player: (1) the
Episodes button in the Shorts tab now navigates to the Full Series Player
and auto-opens the Episode List bottom sheet; (2) tapping an episode in
the bottom sheet now actually loads and plays that episode in the active
player; (3) the download button was moved out of the episode selector
sheet (hard to find) and onto the RightActionBar of the Full Series
Player, while being hidden entirely in the Shorts tab.

### Files modified
- `lib/features/series/screens/episode_player_screen.dart` — Added
  `openEpisodesSheet` bool parameter (default false). In `initState`, a
  post-frame callback now auto-calls `_openEpisodes()` when the flag is
  true. Introduced a `_currentEpisode` state field (initialised from
  `widget.episode`) that replaces all direct `widget.episode` reads; the
  `UnifiedVideoPlayer` now receives `videoUrl: _currentEpisode.videoUrl`
  so `didUpdateWidget` detects the URL change and calls `_switchVideo()`
  when the user picks a different episode from the sheet. The episode
  selector's `onEpisodeSelected` callback is wired to `_onEpisodeSelected`
  which resets engagement counters, `setState`s the new episode,
  re-fetches ratings/reviews, and restarts the engagement timer. Removed
  the old `pushReplacement`-based `_navigateToEpisode`. Added a
  `_onDownload()` method that checks access (shows PaywallOverlay if
  locked), pulls the auth token from `TokenManager`, calls
  `DownloadProvider.downloadEpisode`, and surfaces success/error snacks
  plus the paywall on `accessDenied`. The `build` method now watches
  `DownloadProvider`, computes `isDownloaded` / `downloadStatus` for the
  current episode, and passes `onDownload` + `downloadStatus` +
  `isDownloaded` to `UnifiedVideoPlayer`.
- `lib/core/widgets/unified_video_player.dart` — Added three optional
  params: `onDownload` (VoidCallback?), `downloadStatus`
  (DownloadStatus, default idle), `isDownloaded` (bool, default false).
  Imported `download_provider.dart` for the `DownloadStatus` enum.
  `_buildRightActionBar` forwards the new params to `RightActionBar`.
  When `onDownload` is null (Shorts context) the bar renders without a
  download button; when non-null (Full Series Player) the download
  button appears below Share.
- `lib/features/shorts/widgets/right_action_bar.dart` — Added optional
  `onDownload`, `downloadStatus`, `isDownloaded` params. When
  `onDownload != null`, a fifth action is appended below Share: a
  circular icon button that shows `Icons.download_rounded` + "Download"
  (idle), a blood-red `CircularProgressIndicator` + "Downloading"
  (downloading), or `Icons.download_done_rounded` + "Downloaded"
  (downloaded, green). Tapping is disabled while downloading.
- `lib/features/shorts/screens/shorts_screen.dart` — `_showEpisodesSheet`
  no longer opens the sheet over the Shorts feed; instead it builds a
  `Series` + `Episode` from the current `ShortItem` (extracted into a
  shared `_toSeries` helper also used by `_watchFull`) and calls
  `widget.onPlayEpisode!(series, episode, openEpisodesSheet: true)` to
  navigate to the Full Series Player with auto-open-sheet. The
  `onPlayEpisode` callback type was extended with an optional
  `{bool openEpisodesSheet}` named parameter so `_watchFull` can omit it
  (defaults to false → no auto-open). Removed the now-unused
  `_playEpisodeInFeed` helper and the `episode_selector_sheet` import.
- `lib/app.dart` — The Shorts tab's `onPlayEpisode` closure now accepts
  `{openEpisodesSheet = false}` and forwards it into the
  `AppRoutes.episodePlayer` arguments map. The `episodePlayer` route
  handler reads `args['openEpisodesSheet']` (defaulting to false) and
  passes it to `EpisodePlayerScreen`. The SeriesDetail-origin
  `_openEpisodePlayer` helper is unchanged (no flag → false).
- `lib/features/shorts/widgets/episode_selector_sheet.dart` — Removed
  the per-cell compact `DownloadButton` from `_EpisodeButton` (and the
  now-unused `series` field + `download_button` import). Episode cells
  now show only the episode number / equalizer / lock badge; tapping
  still calls `onEpisodeSelected` then pops the sheet. Downloads are now
  exclusively triggered from the RightActionBar in the Full Series
  Player.
- `.env` — Recreated minimal `.env` (was missing after workspace reset;
  required by `pubspec.yaml` asset bundle and `flutter_dotenv.load` in
  `main.dart`). Contains `API_KEY=` and `HTTP_LOG_ENABLED=false`.

### Tech decisions
- The `_currentEpisode` state pattern (rather than `pushReplacement` on
  each episode tap) keeps the player widget tree stable so
  `UnifiedVideoPlayer.didUpdateWidget` can detect the URL change and
  hot-swap controllers via `_switchVideo` without rebuilding the entire
  screen. This also preserves scroll position, provider state, and
  avoids a route transition on every episode switch.
- Selecting a locked episode from the sheet sets `_currentEpisode` to
  the locked episode; because `isLocked: !_isAccessible` becomes true,
  `UnifiedVideoPlayer.build` short-circuits to `_buildLockedView` and
  shows the PaywallOverlay — satisfying "show the paywall instead of
  switching" without a separate overlay code path.
- The download button is gated by `onDownload != null` in
  `RightActionBar` rather than a bool flag, so the same widget serves
  both contexts (Shorts: null → hidden; Full Player: callback → shown)
  without conditional construction in the player.
- The Shorts-tab `onPlayEpisode` callback signature now uses a named
  `{bool openEpisodesSheet}` parameter defaulting to false, so
  `_watchFull` (which should NOT auto-open the sheet) and
  `_showEpisodesSheet` (which SHOULD) can share the same navigation
  callback. The SeriesDetail `onPlayEpisode` is a separate, simpler
  `void Function(Series, Episode)` and is unaffected.
- `_toSeries` in `ShortsScreen` builds a `Series` with only the current
  episode in `episodes: [episode]`; the `EpisodeSelectorSheet` re-fetches
  the full series via `SeriesProvider.load(widget.seriesId)` on init, so
  the sheet always shows all episodes regardless of how many were in the
  initial Series object.

### Verification
- `flutter analyze` — 0 errors. 81 info/warning lints remain, all
  pre-existing (`prefer_const_constructors`, `use_build_context_synchronously`,
  `deprecated_member_use`, `_position` unused field in
  unified_video_player that predates this task, unused imports in
  unrelated files). No new issues introduced.
- `flutter test` — 34 tests pass (29 pre-existing + 5 download_service
  tests).

### Next actions
- Consider auto-advancing to the next episode when the user dismisses
  the paywall on a locked episode (currently `onMaybeLater` pops the
  whole EpisodePlayerScreen).
- Consider adding a download progress bar (the provider exposes
  `progress` but the streaming pipe does not yet report bytes received).
