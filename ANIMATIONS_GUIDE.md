# Model Animations Guide

Complete guide for using model animations and skeletal animations in Augen AR.

## Overview

Augen supports full animation playback for 3D models, including:
- ✅ Skeletal (bone-based) animations
- ✅ Morph target animations
- ✅ Transform animations
- ✅ Multiple animations per model
- ✅ Animation blending and transitions
- ✅ Speed control
- ✅ Loop modes (once, loop, ping-pong)
- ✅ Time seeking and scrubbing

## Supported Platforms

| Platform | Animation Support | Format Recommendation |
|----------|------------------|----------------------|
| **Android** | ✅ Full (via Filament) | GLB with animations |
| **iOS** | ✅ Full (via RealityKit) | USDZ with animations |

## Quick Start

### 1. Load an Animated Model

```dart
import 'package:augen/augen.dart';

// Load model with animations
final character = ARNode.fromModel(
  id: 'character_1',
  modelPath: 'assets/models/character.glb',
  position: Vector3(0, 0, -1),
  scale: Vector3(0.1, 0.1, 0.1),
  animations: [
    const ARAnimation(
      id: 'walk',
      name: 'walk',           // Animation name from 3D model
      speed: 1.0,
      loopMode: AnimationLoopMode.loop,
      autoPlay: true,         // Start playing immediately
    ),
  ],
);

await controller.addNode(character);
```

### 2. Control Animation Playback

```dart
// Play an animation
await controller.playAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
  speed: 1.0,
  loopMode: AnimationLoopMode.loop,
);

// Pause the animation
await controller.pauseAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
);

// Resume after pause
await controller.resumeAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
);

// Stop the animation (resets to first frame)
await controller.stopAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
);
```

### 3. Change Animation Speed

```dart
// Speed up animation (2x speed)
await controller.setAnimationSpeed(
  nodeId: 'character_1',
  animationId: 'walk',
  speed: 2.0,
);

// Slow down (half speed)
await controller.setAnimationSpeed(
  nodeId: 'character_1',
  animationId: 'walk',
  speed: 0.5,
);
```

### 4. Seek to Specific Time

```dart
// Jump to 2.5 seconds into the animation
await controller.seekAnimation(
  nodeId: 'character_1',
  animationId: 'walk',
  time: 2.5,
);
```

### 5. Get Available Animations

```dart
// Query what animations are available for a model
final animations = await controller.getAvailableAnimations('character_1');
print('Available animations: $animations');
// Output: [walk, run, idle, jump]
```

## Animation Loop Modes

### AnimationLoopMode.once
Play the animation once and stop at the last frame.

```dart
const ARAnimation(
  id: 'jump',
  name: 'jump',
  loopMode: AnimationLoopMode.once,
)
```

### AnimationLoopMode.loop
Loop the animation indefinitely.

```dart
const ARAnimation(
  id: 'idle',
  name: 'idle',
  loopMode: AnimationLoopMode.loop,  // Default
)
```

### AnimationLoopMode.pingPong
Play forward, then backward, and repeat.

```dart
const ARAnimation(
  id: 'wave',
  name: 'wave_hand',
  loopMode: AnimationLoopMode.pingPong,
)
```

## Advanced Usage

### Multiple Animations per Model

```dart
final character = ARNode.fromModel(
  id: 'player',
  modelPath: 'assets/models/player.glb',
  position: Vector3(0, 0, -2),
  animations: [
    const ARAnimation(
      id: 'idle',
      name: 'idle',
      loopMode: AnimationLoopMode.loop,
      autoPlay: true,           // Start with idle
    ),
    const ARAnimation(
      id: 'walk',
      name: 'walk',
      loopMode: AnimationLoopMode.loop,
      autoPlay: false,          // Don't start automatically
    ),
    const ARAnimation(
      id: 'attack',
      name: 'attack',
      loopMode: AnimationLoopMode.once,
      autoPlay: false,
    ),
  ],
);

await controller.addNode(character);

// Switch between animations
await controller.stopAnimation(nodeId: 'player', animationId: 'idle');
await controller.playAnimation(nodeId: 'player', animationId: 'walk');
```

### Animation with Time Constraints

```dart
const ARAnimation(
  id: 'partial_walk',
  name: 'walk',
  startTime: 0.5,      // Start at 0.5 seconds
  endTime: 2.5,        // End at 2.5 seconds
  loopMode: AnimationLoopMode.loop,
)
```

### Listen to Animation Status

```dart
controller.animationStatusStream.listen((status) {
  print('Animation: ${status.animationId}');
  print('State: ${status.state}');
  print('Current Time: ${status.currentTime}s');
  print('Duration: ${status.duration}s');
  print('Is Looping: ${status.isLooping}');
  
  // React to animation state changes
  if (status.state == AnimationState.stopped) {
    print('Animation finished!');
  }
});
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

class AnimatedCharacterScreen extends StatefulWidget {
  @override
  State<AnimatedCharacterScreen> createState() =>
      _AnimatedCharacterScreenState();
}

class _AnimatedCharacterScreenState extends State<AnimatedCharacterScreen> {
  AugenController? _controller;
  String _currentAnimation = 'idle';
  List<String> _availableAnimations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Animated Character')),
      body: Stack(
        children: [
          // AR View
          AugenView(
            onViewCreated: _onARViewCreated,
            config: ARSessionConfig(planeDetection: true),
          ),
          
          // Animation controls
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildAnimationControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationControls() {
    if (_availableAnimations.isEmpty) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: $_currentAnimation',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _availableAnimations.map((anim) {
                return ElevatedButton(
                  onPressed: () => _playAnimation(anim),
                  child: Text(anim),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: anim == _currentAnimation
                        ? Colors.blue
                        : Colors.grey,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.pause),
                  onPressed: () => _pauseCurrentAnimation(),
                  tooltip: 'Pause',
                ),
                IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () => _resumeCurrentAnimation(),
                  tooltip: 'Resume',
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: () => _stopCurrentAnimation(),
                  tooltip: 'Stop',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onARViewCreated(AugenController controller) async {
    _controller = controller;
    
    // Initialize AR
    final isSupported = await controller.isARSupported();
    if (!isSupported) return;
    
    await controller.initialize(ARSessionConfig());
    
    // Add animated character
    await _addAnimatedCharacter();
    
    // Listen to animation status
    controller.animationStatusStream.listen((status) {
      print('Animation ${status.animationId}: ${status.state}');
    });
  }

  Future<void> _addAnimatedCharacter() async {
    if (_controller == null) return;

    try {
      // Add character with multiple animations
      await _controller!.addModelFromAsset(
        id: 'character_1',
        assetPath: 'assets/models/character_animated.glb',
        position: Vector3(0, 0, -1.5),
        scale: Vector3(0.01, 0.01, 0.01),
      );

      // Get available animations from the model
      final animations = await _controller!.getAvailableAnimations('character_1');
      setState(() {
        _availableAnimations = animations;
        if (animations.isNotEmpty) {
          _currentAnimation = animations.first;
        }
      });

      // Play first animation
      if (animations.isNotEmpty) {
        await _playAnimation(animations.first);
      }
    } catch (e) {
      print('Failed to add character: $e');
    }
  }

  Future<void> _playAnimation(String animationName) async {
    if (_controller == null) return;

    try {
      // Stop current animation
      if (_currentAnimation.isNotEmpty) {
        await _controller!.stopAnimation(
          nodeId: 'character_1',
          animationId: _currentAnimation,
        );
      }

      // Play new animation
      await _controller!.playAnimation(
        nodeId: 'character_1',
        animationId: animationName,
        speed: 1.0,
        loopMode: AnimationLoopMode.loop,
      );

      setState(() {
        _currentAnimation = animationName;
      });
    } catch (e) {
      print('Failed to play animation: $e');
    }
  }

  Future<void> _pauseCurrentAnimation() async {
    if (_controller == null || _currentAnimation.isEmpty) return;
    
    await _controller!.pauseAnimation(
      nodeId: 'character_1',
      animationId: _currentAnimation,
    );
  }

  Future<void> _resumeCurrentAnimation() async {
    if (_controller == null || _currentAnimation.isEmpty) return;
    
    await _controller!.resumeAnimation(
      nodeId: 'character_1',
      animationId: _currentAnimation,
    );
  }

  Future<void> _stopCurrentAnimation() async {
    if (_controller == null || _currentAnimation.isEmpty) return;
    
    await _controller!.stopAnimation(
      nodeId: 'character_1',
      animationId: _currentAnimation,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

## Animation Configuration

### ARAnimation Class

```dart
const ARAnimation({
  required String id,              // Unique identifier for this animation config
  String? name,                    // Animation name from model file (null = first animation)
  double? duration,                // Override animation duration
  double speed = 1.0,              // Playback speed multiplier
  AnimationLoopMode loopMode = AnimationLoopMode.loop,
  bool autoPlay = true,            // Start playing on load
  double startTime = 0.0,          // Start offset in seconds
  double? endTime,                 // End time (null = full duration)
})
```

### Animation States

- **AnimationState.stopped** - Animation is stopped (at first frame)
- **AnimationState.playing** - Animation is currently playing
- **AnimationState.paused** - Animation is paused (maintains current frame)

## Best Practices

### 1. Preload Animations

```dart
// Define animations when creating the node
final model = ARNode.fromModel(
  id: 'character',
  modelPath: 'assets/models/character.glb',
  position: Vector3(0, 0, -1),
  animations: [
    const ARAnimation(id: 'idle', name: 'idle'),
    const ARAnimation(id: 'walk', name: 'walk'),
    const ARAnimation(id: 'run', name: 'run'),
  ],
);
```

### 2. Handle Animation Transitions Smoothly

```dart
Future<void> transitionAnimation(
  String from,
  String to,
  {double transitionTime = 0.3}
) async {
  // Gradually slow down current animation
  await controller.setAnimationSpeed(
    nodeId: 'character',
    animationId: from,
    speed: 0.5,
  );
  
  await Future.delayed(Duration(milliseconds: (transitionTime * 1000).toInt()));
  
  // Stop old, start new
  await controller.stopAnimation(nodeId: 'character', animationId: from);
  await controller.playAnimation(
    nodeId: 'character',
    animationId: to,
    speed: 1.0,
  );
}
```

### 3. Create Animation State Machine

```dart
class AnimationStateMachine {
  final AugenController controller;
  final String nodeId;
  String currentState = 'idle';
  
  AnimationStateMachine(this.controller, this.nodeId);
  
  Future<void> transition(String newState) async {
    if (currentState == newState) return;
    
    // Define valid transitions
    final validTransitions = {
      'idle': ['walk', 'run'],
      'walk': ['idle', 'run'],
      'run': ['walk', 'idle'],
    };
    
    if (!validTransitions[currentState]!.contains(newState)) {
      print('Invalid transition: $currentState -> $newState');
      return;
    }
    
    await controller.stopAnimation(
      nodeId: nodeId,
      animationId: currentState,
    );
    
    await controller.playAnimation(
      nodeId: nodeId,
      animationId: newState,
      loopMode: AnimationLoopMode.loop,
    );
    
    currentState = newState;
  }
}
```

### 4. Sync Animation with Game State

```dart
void updateCharacterAnimation(double speed) {
  if (speed == 0) {
    _playAnimation('idle');
  } else if (speed < 5) {
    _playAnimation('walk');
  } else {
    _playAnimation('run');
    // Adjust animation speed based on movement speed
    controller.setAnimationSpeed(
      nodeId: 'character',
      animationId: 'run',
      speed: speed / 5.0,  // Normalize
    );
  }
}
```

### 5. Monitor Animation Progress

```dart
controller.animationStatusStream.listen((status) {
  if (status.state == AnimationState.playing) {
    final progress = status.currentTime / (status.duration ?? 1.0);
    print('Animation progress: ${(progress * 100).toStringAsFixed(1)}%');
    
    // Trigger events at specific points
    if (progress > 0.5 && !_halfwayTriggered) {
      onAnimationHalfway();
      _halfwayTriggered = true;
    }
  }
  
  if (status.state == AnimationState.stopped) {
    onAnimationComplete();
  }
});
```

## Creating Animated Models

### Export from Blender

1. **Create/Import your 3D model**
2. **Add Armature** (for skeletal animation)
3. **Create animations** in the Timeline/Dope Sheet
4. **Export as GLB**:
   - File → Export → glTF 2.0
   - Format: glTF Binary (.glb)
   - Include: Animations ✓
   - Animation Mode: Actions

### Export from Maya

1. **Create animations** using joints/bones
2. **Export as FBX** first
3. **Convert FBX to GLB** using:
   - Blender (import FBX → export GLB)
   - or online converters

### Export for iOS (USDZ)

1. **Use Reality Converter** (macOS):
   - Import GLB/FBX
   - Export as USDZ
   - Animations are preserved

2. **Or use USD tools**:
```bash
usdcat input.glb --out output.usdz
```

## Platform-Specific Details

### Android (ARCore + Filament)

**Animation System:**
- Uses Filament's `Animator` class
- Supports skeletal animations
- Multiple animations can run simultaneously
- Bone transformations in real-time

**Example Implementation (in native code):**
```kotlin
// Load model with animations
val asset = FilamentAsset.load(modelData)
val animator = asset.getInstance().getAnimator()

// Play animation
animator.applyAnimation(animationIndex)
animator.updateBoneMatrices()

// In render loop
animator.advanceTime(deltaTime)
```

### iOS (RealityKit)

**Animation System:**
- Uses `AnimationResource` and `AnimationPlaybackController`
- Native USDZ animation support
- Smooth animation blending
- Timeline-based control

**Example Implementation (in native code):**
```swift
// Play animation
if let modelEntity = node.children.first as? ModelEntity {
    let animation = modelEntity.availableAnimations.first(where: { $0.name == "walk" })
    if let animation = animation {
        let controller = modelEntity.playAnimation(
            animation.repeat(count: .infinity)
        )
        controller.speed = 1.0
    }
}
```

## Troubleshooting

### Animation Not Playing

**Check Model Has Animations:**
```dart
final animations = await controller.getAvailableAnimations('node_id');
if (animations.isEmpty) {
  print('Model has no animations');
}
```

**Verify Animation Name:**
```dart
// List all available animations
final available = await controller.getAvailableAnimations('character');
print('Available: $available');

// Play first available animation
if (available.isNotEmpty) {
  await controller.playAnimation(
    nodeId: 'character',
    animationId: available.first,
  );
}
```

### Animation Playing Too Fast/Slow

```dart
// Adjust speed
await controller.setAnimationSpeed(
  nodeId: 'character',
  animationId: 'walk',
  speed: 1.0,  // Try different values: 0.5, 1.0, 1.5, 2.0
);
```

### Animation Looks Jerky

- **Increase FPS**: Ensure model has smooth keyframes
- **Check File Size**: Large models may cause performance issues
- **Reduce Polygon Count**: Optimize mesh in 3D software
- **Check Device Performance**: Test on different devices

### Multiple Animations Conflict

```dart
// Stop all animations before playing new one
for (final anim in ['walk', 'run', 'idle']) {
  await controller.stopAnimation(
    nodeId: 'character',
    animationId: anim,
  );
}

// Now play the desired animation
await controller.playAnimation(
  nodeId: 'character',
  animationId: 'jump',
);
```

## Performance Tips

1. **Limit Active Animations**: Don't play too many animations simultaneously
2. **Use LOD**: Different models for different distances
3. **Optimize Keyframes**: Remove redundant keyframes
4. **Compress Textures**: Reduce texture sizes for animated models
5. **Profile**: Use Flutter DevTools to monitor performance

## Animation File Size Guidelines

| Animation Type | Recommended Size | Max Size |
|---------------|-----------------|----------|
| Simple (walk) | < 500 KB | 1 MB |
| Complex (full body) | < 2 MB | 5 MB |
| Multiple animations | < 5 MB | 10 MB |

## API Reference

### Controller Methods

```dart
// Play animation
Future<void> playAnimation({
  required String nodeId,
  required String animationId,
  double speed = 1.0,
  AnimationLoopMode loopMode = AnimationLoopMode.loop,
})

// Pause animation
Future<void> pauseAnimation({
  required String nodeId,
  required String animationId,
})

// Stop animation
Future<void> stopAnimation({
  required String nodeId,
  required String animationId,
})

// Resume animation
Future<void> resumeAnimation({
  required String nodeId,
  required String animationId,
})

// Seek to time
Future<void> seekAnimation({
  required String nodeId,
  required String animationId,
  required double time,
})

// Get available animations
Future<List<String>> getAvailableAnimations(String nodeId)

// Set speed
Future<void> setAnimationSpeed({
  required String nodeId,
  required String animationId,
  required double speed,
})
```

### Streams

```dart
// Listen to animation status updates
Stream<AnimationStatus> get animationStatusStream
```

## Resources

- **Blender Animations**: https://www.blender.org/features/animation/
- **glTF Animation**: https://github.com/KhronosGroup/glTF-Tutorials/blob/master/gltfTutorial/gltfTutorial_007_Animations.md
- **RealityKit Animations**: https://developer.apple.com/documentation/realitykit/animating-entities
- **Filament Animator**: https://google.github.io/filament/Filament.html#animations

## Examples

Check the [example app](example/) for complete working examples of:
- Loading animated models
- Switching between animations
- Animation state management
- Speed control
- Interactive animation controls

---

**Need help?** [File an issue](https://github.com/AminMemariani/augen/issues) on GitHub!

