# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Flutter GPS speedometer + trip recorder. Shows live speed on a gauge, records trips
(distance, max/avg speed, moving vs. paused time, route waypoints), and stores them locally
for later viewing on a map, sharing, and JSON export/import. Targets Android and iOS;
desktop/web folders exist but are not the focus.

## Commands

```bash
flutter pub get                  # install deps
flutter run                      # run on attached device/emulator
flutter analyze                  # lint (uses flutter_lints via analysis_options.yaml)
flutter test                     # run all tests
flutter test test/widget_test.dart            # single test file
flutter test --plain-name "substring"         # run tests matching a name
./build.sh                       # clean + pub get + release APK (android-arm64)
```

## Architecture

The app is a single-activity Flutter app with a manual stream-based state flow — no state
management package. Data flows one direction:

```
LocationService (geolocator stream)
  ──emits TripData──▶ SpeedScreen (StreamSubscription → setState)
                       └─ on stop ──▶ Trip ──▶ TripStorageService (SharedPreferences)
```

- **`services/location_service.dart`** — the core and most subtle file. Wraps the geolocator
  position stream and emits `TripData` on a broadcast stream. Owns all GPS signal processing:
  exponential speed smoothing with a "snap" path for real acceleration, accuracy gating
  (`_maxTrustedAccuracyMeters`), stationary noise cutoff, point-to-point distance with
  jump/jitter rejection, moving-time accumulation, and waypoint capture (every ≥5 m). Read the
  inline comments before changing any threshold — most encode hard-won fixes for real-device GPS
  quirks. Permission escalation (whileInUse → always), notification + battery-optimization
  requests, and the Android foreground-service lifecycle live here too.
- **`models/trip_data.dart`** — immutable live state during tracking, plus the `TripStatus`
  enum that drives which UI the screen shows. `copyWith` with `clearRecordingStart` flag.
- **`models/trip.dart`** — immutable saved-trip record with `toJson`/`fromJson`. Note the JSON
  key is `movingMillis` (not `movingDuration`); `pausedDuration` is derived, never stored.
- **`services/trip_storage_service.dart`** — CRUD over a `List<String>` of JSON in
  SharedPreferences under key `saved_trips`. Also `exportJson`/`importJson` (import dedupes by id).
- **`screens/speed_screen.dart`** — home screen. Switches UI on `TripData.status`, runs the
  1 s elapsed-time UI timer, and handles start/stop + save-with-title.
- **`screens/trip_history_screen.dart`** — list, rename, delete, share-as-JSON (share_plus +
  path_provider temp file), and import (file_picker).
- **`screens/trip_map_screen.dart`** — renders a trip's waypoints with flutter_map over
  OpenStreetMap tiles.
- **`widgets/`** — `speedometer_gauge` (custom-painted dial), `stats_row`, `permission_prompt`,
  `title_input_dialog`.

## Key invariants & gotchas

- **Moving vs. paused time**: only moving time is accumulated (in `LocationService`, gated on
  `deltaMeters > 0`). Paused is always derived as `elapsed - moving`. This keeps the two summing
  to total even when GPS fixes are sparse. Don't add a separate paused counter.
- **Android foreground service**: starting/stopping a trip restarts the position stream to
  attach/detach the FGS notification. iOS keeps one stream (background updates enabled from
  `initialize()`). There's an error-fallback and an 8 s watchdog that drop to a plain
  (foreground-only) stream when an OEM skin blocks the FGS — see `background-tracking-miui` note:
  the code is correct; MIUI/Xiaomi kills require manual device settings (Autostart, no battery
  restrictions) that can't be set programmatically.
- **Distance uses displacement, not doppler integration** — many devices don't advance
  `position.timestamp` between fixes. Speed display, however, uses the doppler `position.speed`.
- All Android permissions are declared in `android/app/src/main/AndroidManifest.xml`, including
  the geolocator FGS `<service>` with `foregroundServiceType="location"`.
- Theme is a hardcoded dark palette (greens/dark-navy) inline in `main.dart` and per-widget;
  there is no central theme/colors file.
