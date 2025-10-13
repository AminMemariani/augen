# Custom 3D Model Loading Guide

This guide explains how to load custom 3D models in your AR applications using Augen.

## Supported Model Formats

Augen supports the following 3D model formats on both platforms:

| Format | Android (ARCore) | iOS (RealityKit) | File Extension |
|--------|------------------|------------------|----------------|
| GLTF   | ✅ Yes           | ⚠️ Convert to USDZ | `.gltf`       |
| GLB    | ✅ Yes           | ⚠️ Convert to USDZ | `.glb`        |
| OBJ    | ✅ Yes           | ⚠️ Convert to USDZ | `.obj`        |
| USDZ   | ⚠️ Convert to GLB | ✅ Yes           | `.usdz`       |

### Platform Recommendations

- **Android**: Use GLB (binary GLTF) for best performance and smaller file sizes
- **iOS**: Use USDZ for native support and best performance
- **Cross-platform**: Maintain both GLB and USDZ versions, or use runtime conversion

## Quick Start

### 1. Add Model to Assets

First, add your 3D model file to your Flutter project's assets:

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/models/spaceship.glb
    - assets/models/spaceship.usdz  # Optional: iOS-optimized version
```

### 2. Load Model from Asset

```dart
import 'package:augen/augen.dart';

// Simple way using ARNode.fromModel
final model = ARNode.fromModel(
  id: 'spaceship_1',
  modelPath: 'assets/models/spaceship.glb',
  position: Vector3(0, 0, -1),  // 1 meter in front of camera
  scale: Vector3(0.1, 0.1, 0.1),  // Scale down to 10%
);

await controller.addNode(model);
```

### 3. Load Model from URL

```dart
// Load from network
final model = ARNode.fromModel(
  id: 'spaceship_2',
  modelPath: 'https://example.com/models/spaceship.glb',
  position: Vector3(1, 0, -1),
  modelFormat: ModelFormat.glb,  // Explicitly specify format
);

await controller.addNode(model);
```

## Advanced Usage

### Using addModelFromAsset Helper

```dart
await controller.addModelFromAsset(
  id: 'character_1',
  assetPath: 'assets/models/character.glb',
  position: Vector3(0, 0, -2),
  rotation: Quaternion(0, 0.707, 0, 0.707),  // 90° rotation around Y axis
  scale: Vector3(0.5, 0.5, 0.5),
  properties: {
    'animation': 'walk',
    'interactive': true,
  },
);
```

### Using addModelFromUrl Helper

```dart
await controller.addModelFromUrl(
  id: 'building_1',
  url: 'https://cdn.example.com/models/building.glb',
  position: Vector3(-2, 0, -3),
  scale: Vector3(2.0, 2.0, 2.0),
  modelFormat: ModelFormat.glb,
);
```

### Manual Node Creation

```dart
// Full control over model node
final modelNode = ARNode(
  id: 'custom_model',
  type: NodeType.model,
  modelPath: 'assets/models/object.glb',
  modelFormat: ModelFormat.glb,
  position: Vector3(0, 0, -1.5),
  rotation: Quaternion.identity(),
  scale: Vector3(1, 1, 1),
  properties: {
    'name': 'My Custom Object',
    'category': 'furniture',
  },
);

await controller.addNode(modelNode);
```

## Model Format Detection

Augen can automatically detect model formats from file extensions:

```dart
// Format is auto-detected from .glb extension
final node = ARNode.fromModel(
  id: 'auto_detect',
  modelPath: 'assets/models/car.glb',  // ModelFormat.glb is auto-detected
  position: Vector3(0, 0, -1),
);
```

Supported auto-detection:
- `.gltf` → `ModelFormat.gltf`
- `.glb` → `ModelFormat.glb`
- `.obj` → `ModelFormat.obj`
- `.usdz` → `ModelFormat.usdz`

## Platform-Specific Considerations

### Android (ARCore + Filament)

Android uses Filament (Google's rendering engine) for 3D model rendering:

- **Best Format**: GLB (binary GLTF)
- **Supported Features**:
  - PBR materials
  - Skeletal animations
  - Morph targets
  - Multiple textures
- **File Size**: Keep models under 10MB for smooth loading

### iOS (RealityKit)

iOS uses RealityKit's native model loading:

- **Best Format**: USDZ (Universal Scene Description)
- **Supported Features**:
  - PBR materials
  - Animations
  - Physics properties
  - Environmental lighting
- **File Size**: Keep models under 10MB for smooth loading

### Converting Between Formats

**GLB to USDZ** (for iOS):
```bash
# Using Reality Converter (macOS only)
# Download from: https://developer.apple.com/augmented-reality/tools/

# Or using USD tools
usdcat input.glb --out output.usdz
```

**USDZ to GLB** (for Android):
```bash
# Using Blender
blender --background --python convert.py -- input.usdz output.glb
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

class CustomModelARScreen extends StatefulWidget {
  @override
  State<CustomModelARScreen> createState() => _CustomModelARScreenState();
}

class _CustomModelARScreenState extends State<CustomModelARScreen> {
  AugenController? _controller;
  int _modelCounter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Custom 3D Models')),
      body: Stack(
        children: [
          AugenView(
            onViewCreated: _onARViewCreated,
            config: ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addModelFromAsset,
            child: Icon(Icons.add),
            tooltip: 'Add Model from Asset',
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _addModelFromUrl,
            child: Icon(Icons.cloud_download),
            tooltip: 'Add Model from URL',
          ),
        ],
      ),
    );
  }

  void _onARViewCreated(AugenController controller) async {
    _controller = controller;
    
    // Initialize AR
    final isSupported = await controller.isARSupported();
    if (isSupported) {
      await controller.initialize(ARSessionConfig(
        planeDetection: true,
        lightEstimation: true,
      ));
    }
  }

  Future<void> _addModelFromAsset() async {
    if (_controller == null) return;

    try {
      // Perform hit test to find surface
      final size = MediaQuery.of(context).size;
      final results = await _controller!.hitTest(
        size.width / 2,
        size.height / 2,
      );

      if (results.isEmpty) {
        _showMessage('No surface detected');
        return;
      }

      // Add model at detected surface
      await _controller!.addModelFromAsset(
        id: 'model_${_modelCounter++}',
        assetPath: 'assets/models/object.glb',
        position: results.first.position,
        scale: Vector3(0.1, 0.1, 0.1),
      );

      _showMessage('Model added!');
    } catch (e) {
      _showMessage('Failed to add model: $e');
    }
  }

  Future<void> _addModelFromUrl() async {
    if (_controller == null) return;

    try {
      // Add model in front of camera
      await _controller!.addModelFromUrl(
        id: 'model_${_modelCounter++}',
        url: 'https://example.com/models/sample.glb',
        position: Vector3(0, 0, -1),
        scale: Vector3(0.2, 0.2, 0.2),
      );

      _showMessage('Loading model from URL...');
    } catch (e) {
      _showMessage('Failed to load model: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

## Best Practices

### 1. Optimize Model Size
- Keep polygon count reasonable (< 100K triangles)
- Use texture atlases to reduce draw calls
- Compress textures (use JPEG for diffuse, PNG for alpha)
- Remove unnecessary data (animations, materials not used)

### 2. Model Placement
```dart
// Use hit testing for accurate placement
final results = await controller.hitTest(screenX, screenY);
if (results.isNotEmpty) {
  await controller.addModelFromAsset(
    id: 'placed_model',
    assetPath: 'assets/models/furniture.glb',
    position: results.first.position,
    rotation: results.first.rotation,  // Match surface orientation
  );
}
```

### 3. Scale Appropriately
```dart
// Real-world scale (1 unit = 1 meter)
final realWorldScale = Vector3(1, 1, 1);

// Miniature scale (10cm)
final miniScale = Vector3(0.1, 0.1, 0.1);

// Large scale (5 meters)
final largeScale = Vector3(5, 5, 5);
```

### 4. Handle Loading States
```dart
Future<void> addModelWithLoading() async {
  setState(() => _isLoading = true);
  
  try {
    await controller.addModelFromUrl(
      id: 'model_1',
      url: modelUrl,
      position: Vector3(0, 0, -1),
    );
    _showMessage('Model loaded successfully');
  } catch (e) {
    _showMessage('Failed to load model');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 5. Manage Memory
```dart
// Remove models when no longer needed
await controller.removeNode('model_1');

// Reset session to clear all models
await controller.reset();
```

## Troubleshooting

### Model Not Appearing

1. **Check file path**: Ensure the asset path is correct and listed in `pubspec.yaml`
2. **Check model size**: Very large models may take time to load
3. **Check position**: Model might be behind or too far from camera
4. **Check scale**: Model might be too small or too large

```dart
// Debug: Add a primitive shape at the same position
await controller.addNode(ARNode(
  id: 'debug_cube',
  type: NodeType.cube,
  position: modelPosition,  // Same position as model
));
```

### Model Appears Distorted

- Check that scale is uniform: `Vector3(0.1, 0.1, 0.1)` not `Vector3(0.1, 1.0, 0.1)`
- Verify model orientation in the 3D modeling tool
- Apply correct rotation using Quaternion

### Performance Issues

- Reduce polygon count in 3D modeling software
- Use LOD (Level of Detail) models
- Limit number of simultaneous models
- Use texture compression
- Profile with Flutter DevTools

## Resources

### Tools for Creating/Converting Models
- **Blender** (Free): https://www.blender.org/
- **Reality Converter** (macOS): Convert to USDZ
- **glTF Tools**: https://github.com/KhronosGroup/glTF
- **USD Tools**: https://graphics.pixar.com/usd/

### Model Libraries
- **Sketchfab**: https://sketchfab.com/ (Download GLB/GLTF)
- **Poly Haven**: https://polyhaven.com/
- **TurboSquid**: https://www.turbosquid.com/
- **CGTrader**: https://www.cgtrader.com/

### Learning Resources
- **glTF 2.0 Specification**: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- **USDZ Format**: https://developer.apple.com/augmented-reality/quick-look/
- **ARCore Guidelines**: https://developers.google.com/ar
- **RealityKit Documentation**: https://developer.apple.com/documentation/realitykit

## API Reference

See [API_REFERENCE.md](API_REFERENCE.md) for complete API documentation.

## Need Help?

If you encounter issues or have questions:
1. Check the [FAQ](README.md#troubleshooting)
2. Search existing [GitHub Issues](https://github.com/AminMemariani/augen/issues)
3. Create a new issue with model details and error messages

