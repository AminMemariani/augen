# Getting Started with Augen

This guide will help you create your first AR application using Augen in just a few minutes!

## Prerequisites

Before you begin, make sure you have:

- ✅ Flutter SDK installed (3.3.0 or higher)
- ✅ Dart SDK (3.9.2 or higher)
- ✅ For Android: Android Studio with API level 24+
- ✅ For iOS: Xcode 13+ with iOS 13.0+ deployment target
- ✅ A physical device (AR doesn't work well in simulators/emulators)

## Step 1: Create a New Flutter Project

```bash
flutter create my_ar_app
cd my_ar_app
```

## Step 2: Add Augen Dependency

Open `pubspec.yaml` and add Augen:

```yaml
dependencies:
  flutter:
    sdk: flutter
  augen: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Step 3: Platform Setup

### Android Setup

Open `android/app/src/main/AndroidManifest.xml` and add these permissions and features:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera.ar" android:required="true" />
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    
    <application>
        <!-- Your existing application code -->
        
        <!-- Add ARCore metadata -->
        <meta-data android:name="com.google.ar.core" android:value="required" />
    </application>
</manifest>
```

Also, ensure your `android/app/build.gradle` has `minSdkVersion` set to at least 24:

```gradle
android {
    defaultConfig {
        minSdkVersion 24  // Set to 24 or higher
    }
}
```

### iOS Setup

Open `ios/Runner/Info.plist` and add camera permission and ARKit requirement:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for AR features</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>
```

Ensure your deployment target is iOS 13.0+. Open `ios/Podfile` and check:

```ruby
platform :ios, '13.0'
```

## Step 4: Create Your First AR App

Replace the contents of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

void main() {
  runApp(const MyARApp());
}

class MyARApp extends StatelessWidget {
  const MyARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My First AR App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ARScreen(),
    );
  }
}

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  AugenController? _controller;
  bool _isInitialized = false;
  int _objectCount = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onARViewCreated(AugenController controller) {
    _controller = controller;
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    if (_controller == null) return;

    // Check if AR is supported
    final isSupported = await _controller!.isARSupported();
    if (!isSupported) {
      _showMessage('AR is not supported on this device');
      return;
    }

    // Initialize AR session
    try {
      await _controller!.initialize(
        const ARSessionConfig(
          planeDetection: true,
          lightEstimation: true,
          autoFocus: true,
        ),
      );

      setState(() {
        _isInitialized = true;
      });

      _showMessage('AR initialized! Tap screen to place objects');

      // Listen to plane detection
      _controller!.planesStream.listen((planes) {
        print('Detected ${planes.length} planes');
      });

      // Listen to errors
      _controller!.errorStream.listen((error) {
        _showMessage('Error: $error');
      });
    } catch (e) {
      _showMessage('Failed to initialize AR: $e');
    }
  }

  Future<void> _addObject() async {
    if (_controller == null || !_isInitialized) return;

    final size = MediaQuery.of(context).size;
    
    // Hit test at screen center
    final results = await _controller!.hitTest(
      size.width / 2,
      size.height / 2,
    );

    if (results.isEmpty) {
      _showMessage('No surface detected. Move your device to scan the area.');
      return;
    }

    // Add a sphere at the detected position
    final hit = results.first;
    await _controller!.addNode(
      ARNode(
        id: 'object_$_objectCount',
        type: NodeType.sphere,
        position: hit.position,
        rotation: hit.rotation,
        scale: const Vector3(0.1, 0.1, 0.1),
      ),
    );

    setState(() {
      _objectCount++;
    });

    _showMessage('Object $_objectCount placed!');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My First AR App'),
      ),
      body: Stack(
        children: [
          // AR View
          AugenView(
            onViewCreated: _onARViewCreated,
            config: const ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
            ),
          ),

          // Status text
          if (_isInitialized)
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap + to place an object',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Object counter
          if (_objectCount > 0)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Objects placed: $_objectCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              onPressed: _addObject,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
```

## Step 5: Run Your App

**Important**: AR requires a physical device. It won't work in simulators/emulators.

```bash
# For Android
flutter run

# For iOS
flutter run
```

## What Just Happened?

Your AR app:

1. ✅ **Initializes the AR session** when the app starts
2. ✅ **Detects surfaces** (floors, tables, walls) automatically
3. ✅ **Places 3D spheres** when you tap the + button
4. ✅ **Tracks objects** as you move around

## Next Steps

### 1. Try Different Object Types

Change `NodeType.sphere` to:
- `NodeType.cube` - for cubes
- `NodeType.cylinder` - for cylinders

### 2. Customize Object Appearance

```dart
ARNode(
  id: 'my_object',
  type: NodeType.cube,
  position: hit.position,
  scale: const Vector3(0.2, 0.2, 0.2),  // Make it bigger!
  properties: {
    'color': 'red',  // Custom properties
  },
)
```

### 3. Listen to Plane Detection

```dart
_controller!.planesStream.listen((planes) {
  for (var plane in planes) {
    print('Found ${plane.type} plane at ${plane.center}');
  }
});
```

### 4. Add Anchors

```dart
final anchor = await _controller!.addAnchor(
  Vector3(0, 0, -0.5), // 0.5m in front of camera
);
```

## Common Issues

### Android

**Problem**: "ARCore not installed"
- **Solution**: Install Google Play Services for AR from the Play Store

**Problem**: "Camera permission denied"
- **Solution**: Go to Settings → Apps → Your App → Permissions and enable Camera

### iOS

**Problem**: "ARKit not supported"
- **Solution**: Make sure you're using iPhone 6s or newer

**Problem**: App crashes on launch
- **Solution**: Check that you added the camera permission to Info.plist

## Tips for Best AR Experience

1. 🔦 **Good Lighting**: AR works best in well-lit environments
2. 📱 **Move Slowly**: Move your device slowly to help detect surfaces
3. 🎯 **Flat Surfaces**: Start with flat surfaces like tables or floors
4. 🔄 **Scan the Area**: Move your device around to detect more surfaces

## Learn More

- 📖 [Full API Reference](API_REFERENCE.md)
- 📚 [Complete Documentation](README.md)
- 💡 [Example App](example/)
- 🤝 [Contributing Guide](CONTRIBUTING.md)

## Need Help?

- 🐛 [Report a Bug](https://github.com/yourusername/augen/issues)
- 💬 [Ask a Question](https://github.com/yourusername/augen/discussions)
- 📧 Contact the maintainers

---

**Congratulations! 🎉** You've created your first AR app with Augen!

Now go build something amazing! 🚀

