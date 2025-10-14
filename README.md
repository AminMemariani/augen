# Augen - Flutter AR Plugin

[![pub package](https://img.shields.io/pub/v/augen.svg)](https://pub.dev/packages/augen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/tests-87%20passing-brightgreen.svg)](test/)
[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen.svg)](TEST_COVERAGE.md)

**Augen** is a comprehensive Flutter plugin that enables pure Dart AR (Augmented Reality) development for both Android and iOS platforms. Build AR applications without writing any native code!

## Features

✨ **Cross-Platform**: Uses ARCore on Android and RealityKit on iOS  
🎯 **Pure Dart**: No need to write native code  
📦 **Easy to Use**: Simple, intuitive API  
🔍 **Plane Detection**: Automatically detect horizontal and vertical surfaces  
🎨 **3D Objects**: Add spheres, cubes, cylinders, and custom models  
🎭 **Custom 3D Models**: Load GLTF, GLB, OBJ, and USDZ models from assets or URLs  
🎬 **Animations**: Full skeletal and model animation support with playback control  
⚓ **Anchors**: Place and manage AR anchors  
🎯 **Hit Testing**: Detect surfaces with touch/tap interactions  
📍 **Position Tracking**: Real-time tracking of AR objects  
💡 **Light Estimation**: Realistic lighting for AR objects  

## Platform Support

| Platform | Minimum Version | AR Framework |
|----------|----------------|--------------|
| Android  | API 24 (Android 7.0) | ARCore |
| iOS      | iOS 13.0       | RealityKit & ARKit |

## Installation

Add `augen` to your `pubspec.yaml`:

```yaml
dependencies:
  augen: ^0.1.0
```

Run:
```bash
flutter pub get
```

## Platform-Specific Setup

### Android

Add the following to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Camera permission for AR -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- ARCore requires OpenGL ES 3.0 -->
    <uses-feature android:name="android.hardware.camera.ar" android:required="true" />
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    
    <application>
        <!-- ARCore metadata -->
        <meta-data android:name="com.google.ar.core" android:value="required" />
    </application>
</manifest>
```

**Note**: Make sure your app's `minSdkVersion` is at least 24.

### iOS

Add camera permission to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for AR features</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>
```

**Note**: Make sure your deployment target is at least iOS 13.0.

## Quick Start

### Basic Usage

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
        onViewCreated: _onARViewCreated,
        config: ARSessionConfig(
          planeDetection: true,
          lightEstimation: true,
          depthData: false,
          autoFocus: true,
        ),
      ),
    );
  }

  void _onARViewCreated(AugenController controller) {
    _controller = controller;
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    // Check AR support
    final isSupported = await _controller!.isARSupported();
    if (!isSupported) {
      print('AR is not supported on this device');
      return;
    }

    // Initialize AR session
    await _controller!.initialize(
      ARSessionConfig(
        planeDetection: true,
        lightEstimation: true,
      ),
    );

    // Listen to detected planes
    _controller!.planesStream.listen((planes) {
      print('Detected ${planes.length} planes');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

### Adding 3D Objects

```dart
// Add primitive shapes
final results = await _controller!.hitTest(screenX, screenY);

if (results.isNotEmpty) {
  // Add a sphere at the hit position
  await _controller!.addNode(
    ARNode(
      id: 'sphere_1',
      type: NodeType.sphere,
      position: results.first.position,
      rotation: results.first.rotation,
      scale: Vector3(1, 1, 1),
    ),
  );
}
```

### Loading Custom 3D Models

```dart
// Load model from Flutter assets
await _controller!.addModelFromAsset(
  id: 'spaceship_1',
  assetPath: 'assets/models/spaceship.glb',
  position: Vector3(0, 0, -1),
  scale: Vector3(0.1, 0.1, 0.1),
);

// Load model from URL
await _controller!.addModelFromUrl(
  id: 'building_1',
  url: 'https://example.com/models/building.glb',
  position: Vector3(1, 0, -2),
  modelFormat: ModelFormat.glb,
);

// Or use ARNode.fromModel
final customModel = ARNode.fromModel(
  id: 'custom_1',
  modelPath: 'assets/models/object.glb',
  position: Vector3(0, 0, -1.5),
  scale: Vector3(0.2, 0.2, 0.2),
);
await _controller!.addNode(customModel);
```

**Supported Model Formats:**
- GLB (recommended for Android)
- GLTF
- OBJ
- USDZ (recommended for iOS)

See [CUSTOM_MODELS_GUIDE.md](CUSTOM_MODELS_GUIDE.md) for detailed instructions.

### Model Animations

```dart
// Load model with animations
final character = ARNode.fromModel(
  id: 'character_1',
  modelPath: 'assets/models/character.glb',
  position: Vector3(0, 0, -1.5),
  animations: [
    const ARAnimation(
      id: 'walk',
      name: 'walk',
      loopMode: AnimationLoopMode.loop,
      autoPlay: true,
    ),
  ],
);
await _controller!.addNode(character);

// Control animation playback
await _controller!.playAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
  speed: 1.0,
  loopMode: AnimationLoopMode.loop,
);

// Pause/resume animations
await _controller!.pauseAnimation(nodeId: 'character_1', animationId: 'walk');
await _controller!.resumeAnimation(nodeId: 'character_1', animationId: 'walk');

// Change animation speed
await _controller!.setAnimationSpeed(
  nodeId: 'character_1',
  animationId: 'walk',
  speed: 1.5,  // 1.5x speed
);

// Get available animations
final animations = await _controller!.getAvailableAnimations('character_1');
print('Available: $animations');  // [walk, run, idle, jump]
```

See [ANIMATIONS_GUIDE.md](ANIMATIONS_GUIDE.md) for comprehensive animation documentation.

### Managing Anchors

```dart
// Add an anchor
final anchor = await _controller!.addAnchor(
  Vector3(0, 0, -0.5), // Position in front of camera
);

// Remove an anchor
await _controller!.removeAnchor(anchor!.id);
```

## API Reference

### AugenView

The main AR view widget.

```dart
AugenView({
  required AugenViewCreatedCallback onViewCreated,
  ARSessionConfig config = const ARSessionConfig(),
})
```

### AugenController

Controller for managing the AR session.

#### Methods

- `Future<bool> isARSupported()` - Check if AR is supported
- `Future<void> initialize(ARSessionConfig config)` - Initialize AR session
- `Future<void> addNode(ARNode node)` - Add a 3D node to the scene
- `Future<void> removeNode(String nodeId)` - Remove a node
- `Future<void> updateNode(ARNode node)` - Update an existing node
- `Future<List<ARHitResult>> hitTest(double x, double y)` - Perform hit test
- `Future<ARAnchor?> addAnchor(Vector3 position)` - Add an anchor
- `Future<void> removeAnchor(String anchorId)` - Remove an anchor
- `Future<void> pause()` - Pause AR session
- `Future<void> resume()` - Resume AR session
- `Future<void> reset()` - Reset AR session
- `void dispose()` - Clean up resources

#### Streams

- `Stream<List<ARPlane>> planesStream` - Stream of detected planes
- `Stream<List<ARAnchor>> anchorsStream` - Stream of AR anchors
- `Stream<String> errorStream` - Stream of errors

### ARSessionConfig

Configuration for the AR session.

```dart
ARSessionConfig({
  bool planeDetection = true,
  bool lightEstimation = true,
  bool depthData = false,
  bool autoFocus = true,
})
```

### ARNode

Represents a 3D object in the AR scene.

```dart
ARNode({
  required String id,
  required NodeType type,
  required Vector3 position,
  Quaternion rotation = const Quaternion(0, 0, 0, 1),
  Vector3 scale = const Vector3(1, 1, 1),
  Map<String, dynamic>? properties,
})
```

**NodeType**: `sphere`, `cube`, `cylinder`, `model`

### Vector3

Represents a 3D vector.

```dart
Vector3(double x, double y, double z)
```

### Quaternion

Represents a rotation quaternion.

```dart
Quaternion(double x, double y, double z, double w)
```

## Advanced Usage

### Listening to Plane Detection

```dart
_controller!.planesStream.listen((planes) {
  for (var plane in planes) {
    print('Plane ${plane.id}:');
    print('  Type: ${plane.type}');
    print('  Center: ${plane.center}');
    print('  Extent: ${plane.extent}');
  }
});
```

### Error Handling

```dart
_controller!.errorStream.listen((error) {
  print('AR Error: $error');
  // Handle error appropriately
});
```

### Session Management

```dart
// Pause when app goes to background
await _controller!.pause();

// Resume when app comes back
await _controller!.resume();

// Reset to clear all objects
await _controller!.reset();
```

## Example App

Check out the [example app](example/) for a complete demonstration of Augen's features, including:

- AR initialization and configuration
- Plane detection visualization
- Adding and removing 3D objects
- Hit testing for object placement
- Session management

To run the example:

```bash
cd example
flutter run
```

## Requirements

- Flutter SDK: >=3.3.0
- Dart SDK: >=3.9.2
- Android: API level 24+ with ARCore support
- iOS: iOS 13.0+ with ARKit support

## Testing

Augen comes with comprehensive test coverage including unit tests, controller tests, and integration tests.

### Run All Tests

```bash
flutter test
```

### Run Specific Tests

```bash
# Model tests
flutter test test/augen_test.dart

# Controller tests
flutter test test/augen_controller_test.dart

# Integration tests (requires device/simulator)
cd example
flutter test integration_test/plugin_integration_test.dart
```

### Test Coverage

The project maintains 100% coverage of the public API:
- ✅ 40 model tests (Vector3, Quaternion, ARNode, ARPlane, ARAnchor, ARHitResult, ARSessionConfig, ModelFormat)
- ✅ 16 animation tests (ARAnimation, AnimationStatus, AnimationState, AnimationLoopMode)
- ✅ 30 controller tests (all AugenController methods, streams, and animation controls)
- ✅ 11 integration tests (full AR workflows)

**Total: 87 passing tests** with full coverage of 3D models and animations!

See [TEST_COVERAGE.md](TEST_COVERAGE.md) for detailed coverage information.

## Troubleshooting

### Android

**Issue**: ARCore not supported
- Ensure the device supports ARCore
- Check that Google Play Services for AR is installed
- Verify `minSdkVersion` is at least 24

**Issue**: Camera permission denied
- Make sure camera permission is added to AndroidManifest.xml
- Request runtime permission if needed

### iOS

**Issue**: ARKit not available
- Ensure device has A9 chip or later (iPhone 6s and newer)
- Check deployment target is iOS 13.0+
- Verify ARKit capability is added

**Issue**: Camera permission denied
- Add NSCameraUsageDescription to Info.plist
- Request camera permission at runtime

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [ARCore](https://developers.google.com/ar) for Android
- Built with [RealityKit](https://developer.apple.com/documentation/realitykit) and [ARKit](https://developer.apple.com/documentation/arkit) for iOS

## Support

If you encounter any issues or have questions, please [file an issue](https://github.com/AminMemariani/augen/issues) on GitHub.

## Roadmap

- [x] Custom 3D model loading (GLTF, GLB, OBJ, USDZ) ✅ **v0.2.0**
- [x] Model animations and skeletal animation support ✅ **v0.3.0**
- [ ] Advanced animation blending and transitions
- [ ] Image tracking and recognition
- [ ] Face tracking capabilities
- [ ] Cloud anchors for persistent AR
- [ ] Occlusion for realistic rendering
- [ ] Physics simulation for AR objects
- [ ] Multi-user AR experiences
- [ ] Real-time lighting and shadows
- [ ] Environmental probes and reflections

---

**Made with ❤️ for the Flutter community**
