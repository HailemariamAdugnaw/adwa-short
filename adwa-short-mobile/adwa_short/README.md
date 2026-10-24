# ADWA SHORT — Flutter Mobile App

> Premium short-drama streaming for the Ethiopian market and beyond.
> Built with Flutter 3.47.1 + Dart 3.13.1. Black, Blood Red, White.

---

## 1. Overview

ADWA SHORT is a mobile-first, TikTok-meets-Netflix short-drama streaming
service. The mobile app provides:

- **Home** with hero banner, dynamic horizontal shelves and category tabs.
- **Shorts** — a vertical, snapping video feed (TikTok-style) for previews and
  discovery.
- **Series detail** with episode list, cast, and a flexible access gate
  (watch-ad / coins / time pass / subscription).
- **My List** with watch history and saved series.
- **Profile** with wallet, coin store, time passes, subscriptions, loyalty
  rewards, device management and settings.
- **Search** across series, actors and tags.

The app talks to a FastAPI backend (see `../adwa-short-backend/README.md`)
over HTTP. All state is managed with `provider`; networking is handled by a
single `ApiClient` that auto-attaches `Authorization: Bearer <token>` and
`X-Device-Id` headers, transparently refreshes tokens on `401`, and surfaces
the `MAX_DEVICE_LIMIT_REACHED` error to the UI.

## 2. Prerequisites

| Tool            | Version       | Notes                                                  |
|-----------------|---------------|--------------------------------------------------------|
| Flutter         | 3.47.1        | `flutter --version` should print exactly `3.47.1`.     |
| Dart            | 3.13.1        | Bundled with Flutter.                                  |
| Android Studio  | latest        | Android SDK + emulator (Android 11+ image recommended).|
| Xcode           | 15+           | Required for iOS builds (macOS only).                  |
| CocoaPods       | 1.15+         | `sudo gem install cocoapods` (macOS only).             |
| Backend         | running       | The FastAPI service at `API_BASE_URL` (see `.env`).    |

> Tip: For the Android emulator, use `API_BASE_URL=http://10.0.2.2:8000`
> so the emulator can reach the host's `localhost:8000`.

## 3. Configuration

### 3.1 Environment file

Copy the example and edit values:

```bash
cp .env.example .env
# then edit .env
```

```dotenv
API_BASE_URL=http://10.0.2.2:8000
APP_ENV=dev
DEFAULT_LOCALE=en
HTTP_CONNECT_TIMEOUT=15000
HTTP_READ_TIMEOUT=30000
HTTP_LOG_ENABLED=true
```

- `API_BASE_URL` is prepended to every endpoint path.
- The `.env` file is bundled as a Flutter asset (see `pubspec.yaml`) and loaded
  via `flutter_dotenv` in `lib/main.dart`.
- If `.env` is missing the app falls back to `http://10.0.2.2:8000` so it works
  out-of-the-box on the Android emulator.

### 3.2 Device fingerprint

On first launch the app generates a stable device identifier using
`device_info_plus` plus a secure random suffix, persists it in
`SharedPreferences`, and sends it as the `X-Device-Id` header on every request.
The backend uses this to enforce the device-limit policy. Resetting app data
will generate a new id and force a re-login.

## 4. Install

```bash
cd adwa-short-mobile
flutter pub get
```

There is no code generation step required — the project does not use
`build_runner` (the dependency is listed for tooling only). If you add
`freezed` or `json_serializable` later, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 5. Run on Android

```bash
# Plug in a device or start an emulator, then:
flutter run
```

Or with a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

For Android emulators, the default `API_BASE_URL=http://10.0.2.2:8000` works
out of the box.

## 6. Run on iOS (macOS only)

```bash
cd ios && pod install && cd ..
flutter run -d <ios-device-id>
```

The first launch may require opening `ios/Runner.xcworkspace` in Xcode to
set the development team and bundle identifier.

## 7. Run on Web (optional)

The video player has limited codec support on the web; this target is
not officially supported but useful for quick smoke tests:

```bash
flutter run -d chrome
```

## 8. Build Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

### 8.1 Split per-ABI (smaller APKs)

```bash
flutter build apk --release --split-per-abi
```

## 9. Build iOS IPA

```bash
flutter build ipa --release
```

Output: `build/ios/ipa/adwa_short.ipa`. Open in Xcode → validate → upload to
App Store Connect.

## 10. Build App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

## 11. Testing

```bash
flutter test
```

The test suite covers:

- `test/widget_test.dart` — theme, `AdwaButton`, `TagChip` smoke tests.
- `test/auth_test.dart` — validators, `User.fromJson`, `ApiException` parsing.
- `test/shelf_test.dart` — `Shelf`, `Series`, `Episode`, `ShortItem`,
  `Category` model parsing.

## 12. Code structure

```
lib/
├── main.dart                 # Entry, dotenv load, ProviderScope, device id bootstrap
├── app.dart                  # MaterialApp + named routes + MainShell (bottom nav)
├── core/
│   ├── theme/                # colors, text_styles, theme (dark-only, brand palette)
│   ├── constants/            # api_constants, app_constants (AppStrings)
│   ├── network/              # api_client, api_exception, token_manager
│   ├── router/               # AppRoutes + onGenerateRoute
│   ├── utils/                # device_id, validators, formatters
│   └── widgets/              # AdwaButton, AdwaTextField, PosterCard, ShelfRow,
│                             # ShelfBanner, LoadingShimmer, EmptyState, ErrorView,
│                             # TagChip, BottomNavBar
├── features/
│   ├── auth/                 # splash, login, register, auth_provider, auth_repository
│   ├── home/                 # home_screen, shelf_provider, category_provider, widgets
│   ├── shorts/               # shorts_screen, shorts_provider, short_video_item, overlay
│   ├── series/               # series_detail, episode_player, series_provider,
│   │                         # episode_list_tile, access_gate_dialog, cast_list
│   ├── my_list/              # my_list_screen, my_list_provider, history_tab, saved_tab
│   ├── profile/              # profile, wallet, coin_store, passes, subscriptions,
│   │                         # loyalty, devices, settings + providers
│   └── search/               # search_screen, search_provider
├── models/                   # plain Dart model classes (fromJson/toJson)
└── providers/                # AppStateProvider (global app state)
```

### Architecture

- **State**: `ChangeNotifier` providers per feature (`auth_provider`,
  `shelf_provider`, `shorts_provider`, `series_provider`, `my_list_provider`,
  `wallet_provider`, `loyalty_provider`, `device_provider`,
  `search_provider`, `category_provider`, `app_state_provider`).
- **Networking**: A single `ApiClient` instance injects the access token,
  device id, and refreshes the access token once on `401`. `403` with code
  `MAX_DEVICE_LIMIT_REACHED` is surfaced to the UI via the
  `ApiClient.onDeviceLimitReached` callback.
- **Routing**: Named routes in `core/router/app_router.dart`; `app.dart`
  wires `onGenerateRoute` to actual screens and passes through args.
- **Theming**: One dark `ThemeData` in `core/theme/theme.dart`. Brand colors
  live in `core/theme/colors.dart`. Typography uses Inter (body) and Poppins
  (display) via `google_fonts`.

## 13. Brand identity enforcement

Three colors govern the entire UI:

| Token                | Hex        | Use                                       |
|----------------------|------------|-------------------------------------------|
| `AppColors.black`    | `#0A0A0A`  | Scaffold background, depth                |
| `AppColors.bloodRed` | `#C8102E`  | CTAs, active tabs, focus borders, accents |
| `AppColors.white`    | `#FFFFFF`  | Primary text on dark                      |

- All screens use `Scaffold(backgroundColor: AppColors.black)` (or `surface`
  for elevated sheets).
- All CTAs are `AdwaButton` (blood-red gradient).
- All text fields get a blood-red focus border (`AdwaTextField`).
- Loading uses `shimmer` skeletons (`LoadingShimmer`, `ShelfSkeleton`,
  `HomeLoadingView`).
- The Hot shelf renders as a `ShelfBanner` (snapping carousel). All other
  shelves render as `ShelfRow`.

## 14. Backend dependency

The app expects the FastAPI backend in `../adwa-short-backend/` to be running
at `API_BASE_URL` before launch. Without it:

- The splash screen will sit on `loading` and then fall back to login.
- The home screen will show an error view with a Retry button.
- The shorts feed will be empty.

Consult `../adwa-short-backend/README.md` for backend setup, database
migrations, and seed scripts.

## 15. Troubleshooting

### 15.1 Device limit reached

If you see *"This account has reached its device limit."*:

1. Open Profile → My Devices.
2. Revoke one or more old sessions.
3. Try logging in again.

### 15.2 Token expired

The app refreshes tokens automatically. If refresh also fails (refresh token
revoked server-side), you'll be redirected to the login screen.

### 15.3 Video does not play

- Verify the URL returned by the backend is reachable from your device
  (emulators can't reach `localhost:8000` — use `10.0.2.2:8000`).
- H.264 MP4 is the safest codec for Android + iOS. The web target only
  supports VP9/Opus in some Chromium builds.
- The shorts feed expects portrait (vertical) videos.

### 15.4 Shelves don't load

- Confirm `API_BASE_URL` is set correctly in `.env`.
- Check that `/shelves/home` returns 200 (see backend logs).
- If you changed `.env` after install, run `flutter clean && flutter pub get`.

### 15.5 `.env` not loaded

If you see `dotenv`-related errors, make sure `.env` exists at the project
root and that `pubspec.yaml` lists it under `assets:` (it does).

## 16. Deployment

### 16.1 Android (Play Store)

1. **Signing config**: create `android/key.properties`:

   ```properties
   storePassword=********
   keyPassword=********
   keyAlias=adwa-upload
   storeFile=/path/to/adwa-upload.jks
   ```

2. Edit `android/app/build.gradle`:

   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile file(keystoreProperties['storeFile'])
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               minifyEnabled true
               shrinkResources true
               proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
           }
       }
   }
   ```

3. Build the App Bundle:

   ```bash
   flutter build appbundle --release
   ```

4. Upload `build/app/outputs/bundle/release/app-release.aab` to the Play
   Console under **Production → Create new release**.

5. Complete the store listing, content rating, and data safety form.

### 16.2 iOS (App Store)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set the team, bundle identifier, and version.
3. Create an App ID and provisioning profile on the Apple Developer portal.
4. Build the IPA:

   ```bash
   flutter build ipa --release
   ```

5. Validate and upload via Xcode → Window → Organizer → Distribute App, or
   with `altool` / Transporter.
6. In App Store Connect: create the app, fill in metadata, screenshots, and
   submit for review.

### 16.3 Code obfuscation

To ship an obfuscated build with separate debug-info symbols:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
# or for iOS:
flutter build ipa --release --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols/` somewhere safe — you'll need it to symbolicate crash
reports.

## 17. Environment-specific configuration

For different environments, create additional `.env` files and use
`--dart-define`:

```bash
# Staging
flutter run --dart-define=ENV=staging --dart-define=API_BASE_URL=https://staging-api.adwashort.com

# Production
flutter run --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.adwashort.com
```

Or load multiple dotenv files (`dotenv.load(fileName: '.env.prod')`) by
branching on `const String.fromEnvironment('ENV')` in `main.dart`.

A common pattern is to keep three files in the repo (`.env.example`,
`.env.staging`, `.env.prod`) and select one at build time using
`--dart-define=ENV_FILE=.env.prod`. The committed `.gitignore` excludes the
runtime `.env` and `*.prod` / `*.staging` secrets.

---

### Notes for v1

- Telebirr deposit flow is stubbed: it calls `POST /wallet/deposit` with
  `{amount, provider:'telebirr'}` and expects the backend to either simulate
  success or integrate with Telebirr's H5 callback. The mobile app does not
  handle real Telebirr SDK callbacks in v1.
- The share button on shorts and series detail is a placeholder for v1.
- Localization is wired for English only; the `AppStrings` class is ready for
  future ARB-file integration.
