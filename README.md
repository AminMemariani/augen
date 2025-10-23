# Augen - Flutter AR Plugin

[![pub package](https://img.shields.io/pub/v/augen.svg)](https://pub.dev/packages/augen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/tests-368%20passing-brightgreen.svg)](test/)
[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen.svg)](Documentation.md#6-testing)

**Augen** is a comprehensive Flutter plugin that enables pure Dart AR (Augmented Reality) development for both Android and iOS platforms. Build AR applications without writing any native code!

## Features

✨ **Cross-Platform**: Uses ARCore on Android and RealityKit on iOS  
🎯 **Pure Dart**: No need to write native code  
📦 **Easy to Use**: Simple, intuitive API  
🔍 **Plane Detection**: Automatically detect horizontal and vertical surfaces  
🖼️ **Image Tracking**: Track specific images and anchor content to them  
👤 **Face Tracking**: Detect and track human faces with facial landmarks  
☁️ **Cloud Anchors**: Create persistent AR experiences that can be shared across sessions  
👁️ **Occlusion**: Realistic rendering with depth, person, and plane occlusion  
⚛️ **Physics Simulation**: Realistic interactions with dynamic, static, and kinematic bodies, materials, and constraints  
👥 **Multi-User AR**: Shared AR experiences with real-time collaboration, participant management, and object synchronization  
🎨 **3D Objects**: Add spheres, cubes, cylinders, and custom models  
🎭 **Custom 3D Models**: Load GLTF, GLB, OBJ, and USDZ models from assets or URLs  
🎬 **Animations**: Full skeletal animation support with advanced blending, transitions, and state machines  
⚓ **Anchors**: Place and manage AR anchors  
🎯 **Hit Testing**: Detect surfaces with touch/tap interactions  
📍 **Position Tracking**: Real-time tracking of AR objects  
💡 **Light Estimation**: Realistic lighting for AR objects  

## Documentation

📚 **[Complete Documentation](Documentation.md)** - All-in-one comprehensive guide covering:
- Getting Started
- API Reference
- Custom 3D Models
- Image Tracking
- Face Tracking
- Cloud Anchors
- Occlusion
- Physics Simulation
- Multi-User AR
- Animations & Advanced Blending
- Testing
- Examples & Best Practices

For an in-depth guide on advanced animation features, see the comprehensive [Documentation.md](Documentation.md).

## Platform Support

| Platform | Minimum Version | AR Framework |
|----------|----------------|--------------|
| Android  | API 24 (Android 7.0) | ARCore |
| iOS      | iOS 13.0       | RealityKit & ARKit |

## Installation

Add `augen` to your `pubspec.yaml`:

```yaml
dependencies:
  augen: ^0.10.0
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

### Image Tracking

```dart
// Set up image tracking
Future<void> _setupImageTracking() async {
  // Add an image target
  final target = ARImageTarget(
    id: 'poster1',
    name: 'Movie Poster',
    imagePath: 'assets/images/poster.jpg',
    physicalSize: const ImageTargetSize(0.3, 0.4), // 30cm x 40cm
  );
  
  await _controller!.addImageTarget(target);
  await _controller!.setImageTrackingEnabled(true);
  
  // Listen for tracked images
  _controller!.trackedImagesStream.listen((trackedImages) {
    for (final trackedImage in trackedImages) {
      if (trackedImage.isTracked && trackedImage.isReliable) {
        // Add 3D content to the tracked image
        final character = ARNode.fromModel(
          id: 'character_${trackedImage.id}',
          modelPath: 'assets/models/character.glb',
          position: const Vector3(0, 0, 0.1), // 10cm above the image
        );
        
        _controller!.addNodeToTrackedImage(
          nodeId: 'character_${trackedImage.id}',
          trackedImageId: trackedImage.id,
          node: character,
        );
      }
    }
  });
}
```

### Face Tracking

```dart
// Set up face tracking
Future<void> _setupFaceTracking() async {
  // Enable face tracking
  await _controller!.setFaceTrackingEnabled(true);
  
  // Configure face tracking
  await _controller!.setFaceTrackingConfig(
    detectLandmarks: true,
    detectExpressions: true,
    minFaceSize: 0.1,
    maxFaceSize: 1.0,
  );
  
  // Listen for tracked faces
  _controller!.facesStream.listen((faces) {
    for (final face in faces) {
      if (face.isTracked && face.isReliable) {
        // Add 3D content to the tracked face
        final glasses = ARNode.fromModel(
          id: 'glasses_${face.id}',
          modelPath: 'assets/models/glasses.glb',
          position: const Vector3(0, 0, 0.1), // 10cm in front of face
          scale: const Vector3(0.1, 0.1, 0.1),
        );
        
        _controller!.addNodeToTrackedFace(
          nodeId: 'glasses_${face.id}',
          faceId: face.id,
          node: glasses,
        );
        
        // Get face landmarks
        final landmarks = await _controller!.getFaceLandmarks(face.id);
        for (final landmark in landmarks) {
          print('Landmark ${landmark.name}: ${landmark.position}');
        }
      }
    }
  });
}
```

**Supported Model Formats:**
- GLB (recommended for Android)
- GLTF
- OBJ
- USDZ (recommended for iOS)

See [Documentation.md - Custom 3D Models](Documentation.md#3-custom-3d-models) for detailed instructions.

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

See [Documentation.md - Animations](Documentation.md#4-animations) for comprehensive animation documentation.

**New!** For advanced animation features including blending, transitions, state machines, and blend trees, see [Documentation.md - Advanced Animation Blending](Documentation.md#5-advanced-animation-blending---complete-guide) for a comprehensive in-depth guide.

### Managing Anchors

```dart
// Add an anchor
final anchor = await _controller!.addAnchor(
  Vector3(0, 0, -0.5), // Position in front of camera
);

// Remove an anchor
await _controller!.removeAnchor(anchor!.id);
```

### Cloud Anchors

```dart
// Set up cloud anchors
Future<void> _setupCloudAnchors() async {
  // Check if cloud anchors are supported
  final isSupported = await _controller!.isCloudAnchorsSupported();
  if (!isSupported) {
    print('Cloud anchors not supported on this device');
    return;
  }

  // Configure cloud anchors
  await _controller!.setCloudAnchorConfig(
    maxCloudAnchors: 10,
    timeout: Duration(seconds: 30),
    enableSharing: true,
  );

  // Listen for cloud anchor updates
  _controller!.cloudAnchorsStream.listen((anchors) {
    for (final anchor in anchors) {
      if (anchor.isActive && anchor.isReliable) {
        print('Active cloud anchor: ${anchor.id}');
      }
    }
  });

  // Listen for status updates
  _controller!.cloudAnchorStatusStream.listen((status) {
    if (status.isComplete) {
      if (status.isSuccessful) {
        print('Cloud anchor ready!');
      } else {
        print('Failed: ${status.errorMessage}');
      }
    }
  });
}

// Create a cloud anchor
Future<void> _createCloudAnchor() async {
  // Create a local anchor first
  final localAnchor = ARAnchor(
    id: 'local_anchor_1',
    position: Vector3(0, 0, -1),
    rotation: Quaternion(0, 0, 0, 1),
  );

  await _controller!.addAnchor(localAnchor);

  // Convert to cloud anchor
  final cloudAnchorId = await _controller!.createCloudAnchor(localAnchor.id);
  print('Cloud anchor created: $cloudAnchorId');
}

// Share a cloud anchor session
Future<void> _shareCloudAnchor() async {
  final sessionId = await _controller!.shareCloudAnchor('cloud_anchor_123');
  print('Share this session ID: $sessionId');
}

// Join a shared session
Future<void> _joinSession() async {
  await _controller!.joinCloudAnchorSession('session_123');
}
```

### Occlusion

```dart
// Set up occlusion
Future<void> _setupOcclusion() async {
  // Check if occlusion is supported
  final isSupported = await _controller!.isOcclusionSupported();
  if (!isSupported) {
    print('Occlusion not supported on this device');
    return;
  }

  // Configure occlusion
  await _controller!.setOcclusionConfig(
    type: OcclusionType.depth,
    enableDepthOcclusion: true,
    enablePersonOcclusion: true,
    enablePlaneOcclusion: true,
  );

  // Enable occlusion
  await _controller!.setOcclusionEnabled(true);

  // Listen for occlusion updates
  _controller!.occlusionsStream.listen((occlusions) {
    for (final occlusion in occlusions) {
      if (occlusion.isActive && occlusion.isReliable) {
        print('Active occlusion: ${occlusion.type.name}');
      }
    }
  });

  // Listen for status updates
  _controller!.occlusionStatusStream.listen((status) {
    if (status.isComplete) {
      if (status.isSuccessful) {
        print('Occlusion ready!');
      } else {
        print('Failed: ${status.errorMessage}');
      }
    }
  });
}

// Create an occlusion
Future<void> _createOcclusion() async {
  final occlusionId = await _controller!.createOcclusion(
    type: OcclusionType.depth,
    position: Vector3(0, 0, -1),
    rotation: Quaternion(0, 0, 0, 1),
    scale: Vector3(1, 1, 1),
  );
  print('Occlusion created: $occlusionId');
}

// Get all active occlusions
Future<void> _getOcclusions() async {
  final occlusions = await _controller!.getOcclusions();
  print('Active occlusions: ${occlusions.length}');
  
  for (final occlusion in occlusions) {
    print('${occlusion.type.name} occlusion at ${occlusion.position}');
  }
}
```

### Physics Simulation

Create realistic physics interactions with dynamic, static, and kinematic bodies.

#### Setting Up Physics

```dart
// Check if physics is supported
final supported = await controller.isPhysicsSupported();
if (supported) {
  // Initialize physics world
  const config = PhysicsWorldConfig(
    gravity: Vector3(0, -9.81, 0),
    timeStep: 1.0 / 60.0,
    maxSubSteps: 10,
    enableSleeping: true,
    enableContinuousCollision: true,
  );
  
  await controller.initializePhysics(config);
  await controller.startPhysics();
}
```

#### Creating Physics Bodies

```dart
// Create a dynamic physics body
const material = PhysicsMaterial(
  density: 1.0,
  friction: 0.5,
  restitution: 0.3,
  linearDamping: 0.1,
  angularDamping: 0.1,
);

final bodyId = await controller.createPhysicsBody(
  nodeId: 'physics_node',
  type: PhysicsBodyType.dynamic,
  material: material,
  position: Vector3(0, 2, -1),
  mass: 1.0,
);
```

#### Applying Forces and Impulses

```dart
// Apply continuous force
await controller.applyForce(
  bodyId: bodyId,
  force: Vector3(0, 0, -5),
);

// Apply impulse (instantaneous force)
await controller.applyImpulse(
  bodyId: bodyId,
  impulse: Vector3(0, 10, 0),
);

// Set velocity directly
await controller.setVelocity(
  bodyId: bodyId,
  velocity: Vector3(0, 0, -2),
);
```

#### Physics Constraints

```dart
// Create a hinge constraint between two bodies
final constraintId = await controller.createPhysicsConstraint(
  bodyAId: 'body1',
  bodyBId: 'body2',
  type: PhysicsConstraintType.hinge,
  anchorA: Vector3(0, 0, 0),
  anchorB: Vector3(1, 0, 0),
  axisA: Vector3(0, 1, 0),
  axisB: Vector3(0, 1, 0),
);
```

#### Monitoring Physics

```dart
// Listen to physics updates
controller.physicsBodiesStream.listen((bodies) {
  for (final body in bodies) {
    print('${body.type.name} body at ${body.position}');
  }
});

controller.physicsConstraintsStream.listen((constraints) {
  for (final constraint in constraints) {
    print('${constraint.type.name} constraint active: ${constraint.isActive}');
  }
});

controller.physicsStatusStream.listen((status) {
  print('Physics status: ${status.status} (${(status.progress * 100).toInt()}%)');
});
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
- `Stream<List<ARImageTarget>> imageTargetsStream` - Stream of image targets
- `Stream<List<ARTrackedImage>> trackedImagesStream` - Stream of tracked images
- `Stream<List<ARFace>> facesStream` - Stream of tracked faces
- `Stream<List<ARCloudAnchor>> cloudAnchorsStream` - Stream of cloud anchors
- `Stream<CloudAnchorStatus> cloudAnchorStatusStream` - Stream of cloud anchor status updates
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
- ✅ 14 face tracking tests (ARFace, FaceLandmark, FaceTrackingState)
- ✅ 13 cloud anchor tests (ARCloudAnchor, CloudAnchorState, CloudAnchorStatus)
- ✅ 30 controller tests (all AugenController methods, streams, and animation controls)
- ✅ 11 integration tests (full AR workflows)

**Total: 243 passing tests** with full coverage of all features including advanced animation blending, face tracking, and cloud anchors!

See [Documentation.md - Testing](Documentation.md#6-testing) for detailed coverage information.

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

### 🐛 Help Us Improve!

We're constantly working to make Augen better! **Your feedback is invaluable.**

#### Found a Bug?
Please report it! Include:
- Device information (OS version, model)
- Steps to reproduce
- Expected vs actual behavior
- Error logs or screenshots

[**Report a Bug →**](https://github.com/AminMemariani/augen/issues/new?labels=bug&template=bug_report.md)

#### Testing the New Features?

We've just released **advanced animation blending and transitions** (v0.4.0)! We'd love your feedback:
- Test animation blending and crossfade transitions
- Try state machines and blend trees
- Experiment with layered and additive animations
- Test with different model formats (GLB, GLTF, OBJ, USDZ)
- Report any compatibility issues
- Share your use cases and suggestions

[**Share Feedback →**](https://github.com/AminMemariani/augen/issues/new?labels=feedback)

#### Want a Feature?
Have an idea for improvement? Let us know!

[**Request a Feature →**](https://github.com/AminMemariani/augen/issues/new?labels=enhancement)

**Your contributions help make Augen better for everyone!** ⭐ Star the repo if you find it useful!

## Roadmap

- [x] Custom 3D model loading (GLTF, GLB, OBJ, USDZ) ✅ **v0.2.0**
- [x] Model animations and skeletal animation support ✅ **v0.3.0**
- [x] Advanced animation blending and transitions ✅ **v0.4.0**
- [x] Image tracking and recognition ✅ **v0.5.0**
- [x] Face tracking capabilities ✅ **v0.6.0**
- [x] Cloud anchors for persistent AR ✅ **v0.7.0**
- [x] Occlusion for realistic rendering ✅ **v0.8.0**
- [x] Physics simulation for AR objects ✅ **v0.9.0**
- [ ] Multi-user AR experiences
- [ ] Real-time lighting and shadows
- [ ] Environmental probes and reflections

---

**Made with ❤️ for the Flutter community**
