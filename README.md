# Augen - Flutter AR Plugin

[![pub package](https://img.shields.io/pub/v/augen.svg)](https://pub.dev/packages/augen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A cross-platform Flutter plugin for building AR (Augmented Reality) apps using **ARCore** on Android and **RealityKit** on iOS. Write your AR logic entirely in Dart — no native code required.

## Features

- **Plane Detection** — detect horizontal and vertical surfaces
- **3D Objects** — place primitives (sphere, cube, cylinder) or load custom models (GLTF, GLB, OBJ, USDZ)
- **Hit Testing** — tap-to-place objects on detected surfaces
- **Image Tracking** — track real-world images and anchor content to them
- **Face Tracking** — detect faces with facial landmarks and expressions
- **Cloud Anchors** — persist and share AR anchors across sessions and devices
- **Occlusion** — depth, person, and plane occlusion for realistic rendering
- **Physics** — dynamic, static, and kinematic bodies with forces, impulses, and constraints
- **Multi-User AR** — shared sessions with real-time object synchronization
- **Lighting & Shadows** — directional, point, spot, and ambient lights with configurable shadows
- **Environmental Probes** — realistic reflections and environmental lighting
- **Animations** — skeletal animations with blending, transitions, and state machines

For detailed API docs and advanced usage, see [Documentation.md](Documentation.md).

## Platform Requirements

| Platform | Minimum Version        | AR Framework         |
| -------- | ---------------------- | -------------------- |
| Android  | API 24 (Android 7.0)  | ARCore               |
| iOS      | iOS 13.0              | RealityKit & ARKit   |

**SDK:** Flutter >= 3.3.0, Dart >= 3.9.2

## Installation

```yaml
dependencies:
  augen: ^1.3.0
```

```bash
flutter pub get
```

### Android Setup

Add to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="true" />
<uses-feature android:glEsVersion="0x00030000" android:required="true" />

<application>
    <meta-data android:name="com.google.ar.core" android:value="required" />
</application>
```

Set `minSdkVersion` to at least **24** in `android/app/build.gradle`.

### iOS Setup

Add to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for AR features</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>
```

Set the deployment target to at least **iOS 13.0**.

## Quick Start

### 1. Display the AR View

`AugenView` is the widget that renders the camera feed and AR scene. When the view is ready, you receive an `AugenController` to drive everything.

```dart
import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

class ARScreen extends StatefulWidget {
  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  AugenController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AugenView(
        onViewCreated: (controller) {
          _controller = controller;
          _initAR();
        },
        config: ARSessionConfig(
          planeDetection: true,
          lightEstimation: true,
        ),
      ),
    );
  }

  Future<void> _initAR() async {
    final supported = await _controller!.isARSupported();
    if (!supported) return;

    await _controller!.initialize(
      ARSessionConfig(planeDetection: true, lightEstimation: true),
    );

    // React to detected planes
    _controller!.planesStream.listen((planes) {
      debugPrint('Detected ${planes.length} planes');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

### 2. Place Objects via Hit Test

Tap a detected surface to place a 3D object:

```dart
final results = await _controller!.hitTest(screenX, screenY);
if (results.isNotEmpty) {
  await _controller!.addNode(
    ARNode(
      id: 'sphere_1',
      type: NodeType.sphere,
      position: results.first.position,
      scale: Vector3(0.1, 0.1, 0.1),
    ),
  );
}
```

### 3. Load Custom 3D Models

```dart
// From Flutter assets
await _controller!.addModelFromAsset(
  id: 'ship',
  assetPath: 'assets/models/spaceship.glb',
  position: Vector3(0, 0, -1),
  scale: Vector3(0.1, 0.1, 0.1),
);

// From a URL
await _controller!.addModelFromUrl(
  id: 'building',
  url: 'https://example.com/models/building.glb',
  position: Vector3(1, 0, -2),
  modelFormat: ModelFormat.glb,
);
```

**Recommended formats:** GLB for Android, USDZ for iOS. GLTF and OBJ are also supported.

## Web Marker-Based AR

Augen runs in the browser via Flutter Web (Wasm or JS) and detects square visual
markers in the live camera feed using an **image-template matching detector**
implemented in JavaScript with `dart:js_interop` bindings.

> **Status:** The detector matches PNG/JPG marker templates with multi-scale
> normalized cross-correlation (NCC). Pose translation is computed from
> apparent marker size and the configured physical width; rotation is currently
> identity. For full 6-DoF pose, a future release will bundle ARToolKit Wasm or
> OpenCV.js POSIT. Three.js rendering integration is also planned — the
> renderer already maintains scene state and marker transforms, but does not
> yet draw geometry. Contributions welcome.

### Browser Support

| Browser | Support |
| --- | --- |
| Chrome (desktop & Android) | ✅ Full |
| Edge | ✅ Full |
| Safari | ⚠️ Partial (WebRTC limitations) |
| Firefox | ⚠️ Partial (WebAssembly SIMD varies) |

### Requirements

- **Flutter Wasm:** `flutter run -d chrome --wasm`
- **HTTPS** required for `getUserMedia` camera access (localhost is exempt)
- Camera permission must be granted by the user
- Server must serve `.wasm` files with `Content-Type: application/wasm`
- For `SharedArrayBuffer` (optional perf boost): set `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers

### Marker Target Types

| Type | Description | Status |
| --- | --- | --- |
| `ARMarkerType.pattern` (with `imagePath`) | PNG/JPG image template matched via NCC | ✅ Implemented |
| `ARMarkerType.pattern` (with `patternPath`) | Classic ARToolKit `.patt` file | ⚠️ Planned (ARToolKit Wasm) |
| `ARMarkerType.barcode` | Numeric barcode markers | ⚠️ Planned |
| `ARMarkerType.aruco` | ArUco dictionary markers | ⚠️ Planned |

### Quick Start

```dart
AugenView(
  config: const ARSessionConfig(
    markerTracking: true,
    planeDetection: false,
  ),
  onViewCreated: (controller) async {
    await controller.initialize(
      const ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(
          maxDetectionFps: 20,
          debug: true,
        ),
      ),
    );

    // Use a PNG/JPG image as the marker template.
    await controller.addMarkerTarget(
      const ARMarkerTarget(
        id: 'hiro',
        name: 'Hiro marker',
        type: ARMarkerType.pattern,
        imagePath: 'assets/markers/Hiro_marker.png',
        physicalWidth: 0.08, // 8 cm
      ),
    );

    await controller.setMarkerTrackingEnabled(true);

    controller.trackedMarkersStream.listen((markers) {
      for (final marker in markers) {
        if (marker.isTracked && marker.isReliable) {
          // Anchor content to the marker
        }
      }
    });
  },
);
```

A standalone runnable demo lives at `example/web_marker_ar/`:

```bash
cd example/web_marker_ar
flutter run -d chrome --wasm
```

### Supported vs Unsupported Web Features

| Feature | Web Support |
| --- | --- |
| Marker tracking (PNG/JPG image templates) | ✅ |
| Camera feed rendering | ✅ |
| `trackedMarkersStream` & marker pose updates | ✅ |
| 3D node anchoring to markers (scene-graph state) | ✅ |
| Three.js geometry rendering | ⚠️ Planned |
| Full 6-DoF pose (rotation) | ⚠️ Planned (ARToolKit Wasm) |
| `.patt` / barcode / ArUco marker types | ⚠️ Planned |
| Plane detection | ❌ Mobile only |
| Image tracking (ARCore/ARKit style) | ❌ Mobile only |
| Face tracking | ❌ Mobile only |
| Cloud anchors | ❌ Mobile only |
| Occlusion / Physics / LiDAR | ❌ Mobile only |

### Performance Tips

- Set `maxDetectionFps` to 15–20 to balance accuracy and CPU usage
- Use small marker pattern files (< 10 KB)
- Print markers at the configured `physicalWidth` for correct scale
- Prefer Chrome/Edge for best WebAssembly performance
- Use `debug: false` in production to disable visual overlays

### Troubleshooting

- **Camera not starting:** Ensure HTTPS (or localhost) and that the user granted camera permission.
- **Marker not detected:** Verify the `imagePath` (PNG/JPG) is declared in `pubspec.yaml` assets and the printed marker matches `physicalWidth`. Ensure adequate lighting and that the marker fills a reasonable portion of the camera frame.
- **Camera hangs at "Initializing…":** On laptops with no rear camera, `facingMode: 'environment'` falls back to any available camera automatically. If it still hangs, close other apps/tabs holding the webcam.
- **Wasm not loading:** Confirm the server serves `.wasm` with `Content-Type: application/wasm`.
- **`SharedArrayBuffer` errors:** Add COOP/COEP headers to your web server.
- **Low FPS:** Reduce `maxDetectionFps`, close other tabs, or use a device with better GPU.

## Architecture Overview

```
augen/
  lib/
    augen.dart                  # Public barrel export
    src/
      augen_controller.dart     # AugenController — all AR operations
      augen_view.dart           # AugenView widget
      models/                   # Data classes (ARNode, ARPlane, Vector3, etc.)
  android/                      # Kotlin — ARCore integration
  ios/                          # Swift — RealityKit / ARKit integration
  example/                      # Full-featured demo app
  test/                         # Unit and integration tests
```

**How it works:** `AugenView` creates a platform view (Android: `PlatformViewLink`, iOS: `UiKitView`) that hosts the native AR renderer. All communication between Dart and native happens through Flutter method channels, abstracted behind `AugenController`.

### Key Classes

| Class | Purpose |
| ----- | ------- |
| `AugenView` | Widget that displays the AR camera + scene |
| `AugenController` | Controls the AR session — add/remove nodes, hit test, manage anchors, animations, physics, etc. |
| `ARSessionConfig` | Session options: plane detection, light estimation, depth data, auto focus |
| `ARNode` | A 3D object in the scene (primitives or custom models) |
| `ARPlane` | A detected surface (horizontal/vertical) |
| `ARAnchor` | A fixed point in world space |
| `ARHitResult` | Result of a raycast against detected geometry |
| `Vector3` / `Quaternion` | 3D position and rotation types |

### Reactive Streams

`AugenController` exposes streams for all AR state updates. Subscribe to stay in sync:

```dart
_controller.planesStream          // detected planes
_controller.anchorsStream         // anchors
_controller.trackedImagesStream   // image tracking results
_controller.facesStream           // face tracking results
_controller.errorStream           // errors
_controller.physicsBodiesStream   // physics body updates
_controller.lightsStream          // light changes
// ... and more — see Documentation.md for the full list
```

## Example Apps

The `example/` directory contains a complete demo app with tabs for every feature (planes, nodes, images, faces, cloud anchors, occlusion, physics, multi-user, lighting, probes, animations).

```bash
cd example
flutter run
```

### Web Marker AR Example

A standalone web example demonstrating marker-based AR is available at [`example/web_marker_ar/`](example/web_marker_ar/):

```bash
cd example/web_marker_ar
flutter run -d chrome --wasm
```

See the [Web Marker AR README](example/web_marker_ar/README.md) for details on setup and usage.

## Testing

```bash
# Run all tests
flutter test

# Run specific test suites
flutter test test/augen_controller_test.dart
flutter test test/augen_animation_test.dart

# Integration tests (requires a device or simulator)
cd example
flutter test integration_test/plugin_integration_test.dart
```

## Troubleshooting

**Android — ARCore not working:**
- Verify the device [supports ARCore](https://developers.google.com/ar/devices)
- Ensure Google Play Services for AR is installed
- Confirm `minSdkVersion >= 24`

**iOS — ARKit not available:**
- Requires A9 chip or later (iPhone 6s+)
- Confirm deployment target is iOS 13.0+
- Ensure the `arkit` capability is declared in Info.plist

**Camera permission denied (both platforms):**
- Add the required permission entries listed in the setup sections above
- Request runtime permission before showing the AR view

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

## License

MIT — see [LICENSE](LICENSE) for details.

## Links

- [pub.dev package](https://pub.dev/packages/augen)
- [GitHub repository](https://github.com/AminMemariani/augen)
- [Full documentation](Documentation.md)
- [Issue tracker](https://github.com/AminMemariani/augen/issues)

## Support

If Augen has helped your project, you can support continued development with a
tip on Solana:

[![Solana](https://img.shields.io/badge/Solana-Donate-9945FF?style=for-the-badge&logo=solana&logoColor=white)](https://solscan.io/account/ApeGNaqfRM3HJocYHfdZ88GmFj2wqVCxUzm5MGvGNrWy)

**Solana wallet address:**

```
ApeGNaqfRM3HJocYHfdZ88GmFj2wqVCxUzm5MGvGNrWy
```

SOL and SPL tokens (USDC, etc.) on Solana mainnet are welcome. Thanks for your support! 🙏
