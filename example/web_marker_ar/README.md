# Augen Web Marker AR Example

A standalone Flutter web app demonstrating **marker-based AR** using the Augen plugin.

## What This Demo Does

- Opens the device camera in the browser
- Detects **Hiro pattern markers** in the camera feed
- Displays a debug overlay with camera status, detector status, marker visibility, confidence, and FPS
- Anchors a green 3D cube to the detected marker
- Provides controls to toggle debug overlay and pause/resume tracking

## Prerequisites

- **Flutter SDK** ≥ 3.3.0 with web support enabled
- **Chrome** or **Edge** (Chromium-based browser)
- **HTTPS or localhost** — camera access requires a secure context
- A printed **Hiro marker** (see below)

## How to Run

```bash
cd example/web_marker_ar
flutter pub get
flutter run -d chrome --wasm
```

> **Note:** The `--wasm` flag enables Dart-to-Wasm compilation for better performance. If Wasm is not supported in your Flutter version, omit the flag.

## Getting the Hiro Marker

1. Search for **"Hiro AR marker"** or visit [https://chev.me/armarker/](https://chev.me/armarker/) and select the "Hiro" preset.
2. Print the marker on paper (8–12 cm recommended).
3. Tape it to a flat surface for best results.

### Marker Pattern File

Place `hiro.patt` in `assets/markers/`. You can download it from:
[AR.js Hiro pattern](https://raw.githubusercontent.com/AR-js-org/AR.js/master/data/data/patt.hiro)

## Expected Behavior

1. The app requests camera permission — **allow it**.
2. The debug overlay shows camera and detector status turning green.
3. Point the camera at the printed Hiro marker.
4. The overlay shows **"VISIBLE ✅"** with confidence percentage.
5. A green cube appears anchored to the marker.

## Controls

| Button | Action |
| --- | --- |
| 🪲 Bug icon (FAB) | Toggle the debug overlay on/off |
| ⏸️ Pause icon (FAB) | Pause/resume marker tracking |

## Troubleshooting

### Camera permission denied
- Click the camera icon in the browser address bar and allow access.
- On some systems, you may need to grant browser-level camera permissions in system settings.

### Camera not working / black screen
- Ensure you are on **HTTPS** or **localhost**. Browsers block camera access on plain HTTP.
- Check that no other app is using the camera.

### Wasm loading errors
- Ensure your Flutter SDK supports Wasm compilation (`flutter --version`).
- Try without `--wasm`: `flutter run -d chrome`

### Marker not detected
- Ensure the Hiro marker is printed clearly with a solid black border.
- Improve lighting — avoid shadows and glare on the marker.
- Hold the marker steady and at a reasonable distance (20–60 cm from camera).
- Ensure `assets/markers/hiro.patt` exists.

### `augen_web_ar.js` not found
Flutter's plugin system should auto-serve `augen_web_ar.js` from the Augen package's `web/` directory. If the JS file is not found at runtime, copy it manually:

```bash
cp ../../web/augen_web_ar.js web/
```

## Running Tests

End-to-end (integration) tests live in `integration_test/` and exercise the
example app in a real Chrome browser using `package:integration_test`.

```bash
cd example/web_marker_ar
flutter pub get

# Web (Chrome) — requires chromedriver. See below.
./tool/run_e2e.sh

# Or directly via flutter drive:
chromedriver --port=4444 &
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/web_marker_ar_test.dart \
  -d chrome
```

The same tests also run on a desktop/VM target without any browser:

```bash
flutter test integration_test/web_marker_ar_test.dart -d macos   # or linux/windows
```

Requirements:

- **Chrome** installed and on `PATH`.
- **chromedriver matching your Chrome major version** — version mismatch fails
  immediately with `SessionNotCreatedException`. Get the exact matching build
  from <https://googlechromelabs.github.io/chrome-for-testing/>.
- On macOS you may need to clear the quarantine attribute the first time:
  `xattr -d com.apple.quarantine $(which chromedriver)`. `tool/run_e2e.sh`
  does this automatically.
- The runner script accepts `CHROMEDRIVER=/path/to/chromedriver` to point at
  a specific binary (useful when `brew`'s chromedriver doesn't match Chrome).

**Verified passing**: 9 tests pass via `./tool/run_e2e.sh` against Chrome 147 +
chromedriver 147 on macOS arm64 (Flutter 3.44).

> ⚠️ As of Flutter 3.44, `flutter test integration_test -d chrome` and
> `flutter test --platform chrome` are **not** supported for integration
> tests (Flutter exits with "Web devices are not supported for integration
> tests yet."). Web E2E must go through `flutter drive` + `chromedriver`.

Expected behavior:

- In a headless / permission-less browser the camera will fail to start.
  The tests treat that as a valid outcome — they verify that the UI still
  boots, the debug overlay renders, the `AugenView` mounts, and the widget
  tree stays intact even when the camera surfaces a permission error.

## Project Structure

```
web_marker_ar/
├── lib/main.dart                       # Demo app with AR view and debug overlay
├── web/index.html                      # Web entry point (loads augen_web_ar.js)
├── assets/markers/                     # Place hiro.patt here
├── integration_test/                   # E2E tests (run with flutter test -d chrome)
│   └── web_marker_ar_test.dart
├── tool/run_e2e.sh                     # Convenience runner for E2E tests
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```
