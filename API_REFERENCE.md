# Augen API Reference

Complete API reference for the Augen Flutter AR plugin.

## Table of Contents

- [Core Classes](#core-classes)
  - [AugenView](#augenview)
  - [AugenController](#augencontroller)
- [Configuration](#configuration)
  - [ARSessionConfig](#arsessionconfig)
- [Models](#models)
  - [ARNode](#arnode)
  - [ARAnchor](#aranchor)
  - [ARPlane](#arplane)
  - [ARHitResult](#arhitresult)
  - [Vector3](#vector3)
  - [Quaternion](#quaternion)
- [Enums](#enums)

---

## Core Classes

### AugenView

The main widget for displaying AR content.

```dart
class AugenView extends StatefulWidget
```

#### Constructor

```dart
AugenView({
  Key? key,
  required AugenViewCreatedCallback onViewCreated,
  ARSessionConfig config = const ARSessionConfig(),
})
```

**Parameters:**
- `onViewCreated`: Callback invoked when the AR view is created, providing the `AugenController`
- `config`: Configuration for the AR session (optional, defaults to default config)

**Example:**

```dart
AugenView(
  onViewCreated: (controller) {
    _controller = controller;
    _initializeAR();
  },
  config: ARSessionConfig(
    planeDetection: true,
    lightEstimation: true,
  ),
)
```

---

### AugenController

Controller for managing the AR session and interacting with AR content.

```dart
class AugenController
```

#### Properties

##### planesStream

```dart
Stream<List<ARPlane>> get planesStream
```

Stream that emits updates when planes are detected or updated.

**Example:**

```dart
_controller.planesStream.listen((planes) {
  print('Detected ${planes.length} planes');
  for (var plane in planes) {
    print('Plane type: ${plane.type}');
  }
});
```

##### anchorsStream

```dart
Stream<List<ARAnchor>> get anchorsStream
```

Stream that emits updates when anchors are added, updated, or removed.

##### errorStream

```dart
Stream<String> get errorStream
```

Stream that emits AR-related errors.

**Example:**

```dart
_controller.errorStream.listen((error) {
  print('AR Error: $error');
  // Handle error
});
```

#### Methods

##### isARSupported

```dart
Future<bool> isARSupported()
```

Checks if AR is supported on the current device.

**Returns:** `true` if AR is supported, `false` otherwise

**Example:**

```dart
final isSupported = await _controller.isARSupported();
if (!isSupported) {
  print('AR not supported on this device');
}
```

##### initialize

```dart
Future<void> initialize(ARSessionConfig config)
```

Initializes the AR session with the specified configuration.

**Parameters:**
- `config`: Configuration for the AR session

**Throws:** `PlatformException` if initialization fails

**Example:**

```dart
await _controller.initialize(
  ARSessionConfig(
    planeDetection: true,
    lightEstimation: true,
    depthData: false,
    autoFocus: true,
  ),
);
```

##### addNode

```dart
Future<void> addNode(ARNode node)
```

Adds a 3D node to the AR scene.

**Parameters:**
- `node`: The AR node to add

**Throws:** `PlatformException` if the operation fails

**Example:**

```dart
await _controller.addNode(
  ARNode(
    id: 'sphere_1',
    type: NodeType.sphere,
    position: Vector3(0, 0, -0.5),
    scale: Vector3(0.1, 0.1, 0.1),
  ),
);
```

##### removeNode

```dart
Future<void> removeNode(String nodeId)
```

Removes a node from the AR scene.

**Parameters:**
- `nodeId`: ID of the node to remove

**Throws:** `PlatformException` if the node doesn't exist or removal fails

**Example:**

```dart
await _controller.removeNode('sphere_1');
```

##### updateNode

```dart
Future<void> updateNode(ARNode node)
```

Updates an existing node in the AR scene.

**Parameters:**
- `node`: The updated node (must have same ID as existing node)

**Throws:** `PlatformException` if the node doesn't exist or update fails

**Example:**

```dart
await _controller.updateNode(
  existingNode.copyWith(
    position: Vector3(0.1, 0.1, -0.5),
  ),
);
```

##### hitTest

```dart
Future<List<ARHitResult>> hitTest(double x, double y)
```

Performs a hit test at the specified screen coordinates to detect AR surfaces.

**Parameters:**
- `x`: X coordinate on the screen
- `y`: Y coordinate on the screen

**Returns:** List of hit test results, ordered by distance from camera

**Example:**

```dart
final results = await _controller.hitTest(
  screenWidth / 2,
  screenHeight / 2,
);

if (results.isNotEmpty) {
  final firstHit = results.first;
  print('Hit at position: ${firstHit.position}');
}
```

##### addAnchor

```dart
Future<ARAnchor?> addAnchor(Vector3 position)
```

Adds an anchor at the specified position in world space.

**Parameters:**
- `position`: Position in world coordinates

**Returns:** The created anchor, or `null` if creation fails

**Example:**

```dart
final anchor = await _controller.addAnchor(
  Vector3(0, 0, -0.5),
);
if (anchor != null) {
  print('Anchor created: ${anchor.id}');
}
```

##### removeAnchor

```dart
Future<void> removeAnchor(String anchorId)
```

Removes an anchor from the AR session.

**Parameters:**
- `anchorId`: ID of the anchor to remove

**Throws:** `PlatformException` if the anchor doesn't exist

##### pause

```dart
Future<void> pause()
```

Pauses the AR session. Call this when the app goes to background.

**Example:**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _controller.pause();
  }
}
```

##### resume

```dart
Future<void> resume()
```

Resumes a paused AR session.

**Example:**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _controller.resume();
  }
}
```

##### reset

```dart
Future<void> reset()
```

Resets the AR session, removing all nodes and anchors.

**Example:**

```dart
await _controller.reset();
```

##### dispose

```dart
void dispose()
```

Disposes the controller and cleans up resources. Call this in your widget's dispose method.

**Example:**

```dart
@override
void dispose() {
  _controller?.dispose();
  super.dispose();
}
```

---

## Configuration

### ARSessionConfig

Configuration options for the AR session.

```dart
class ARSessionConfig
```

#### Constructor

```dart
const ARSessionConfig({
  bool planeDetection = true,
  bool lightEstimation = true,
  bool depthData = false,
  bool autoFocus = true,
})
```

**Parameters:**
- `planeDetection`: Enable detection of horizontal and vertical planes
- `lightEstimation`: Enable light estimation for realistic rendering
- `depthData`: Enable depth data (requires compatible hardware)
- `autoFocus`: Enable automatic camera focus

#### Methods

##### copyWith

```dart
ARSessionConfig copyWith({
  bool? planeDetection,
  bool? lightEstimation,
  bool? depthData,
  bool? autoFocus,
})
```

Creates a copy with modified fields.

---

## Models

### ARNode

Represents a 3D object in the AR scene.

```dart
class ARNode
```

#### Constructor

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

**Parameters:**
- `id`: Unique identifier for the node
- `type`: Type of 3D object (sphere, cube, cylinder, model)
- `position`: Position in world coordinates
- `rotation`: Rotation as a quaternion (optional, defaults to identity)
- `scale`: Scale factors for x, y, z axes (optional, defaults to 1,1,1)
- `properties`: Additional properties (optional)

#### Methods

##### copyWith

```dart
ARNode copyWith({
  String? id,
  NodeType? type,
  Vector3? position,
  Quaternion? rotation,
  Vector3? scale,
  Map<String, dynamic>? properties,
})
```

---

### ARAnchor

Represents an anchor in the AR scene.

```dart
class ARAnchor
```

#### Properties

- `String id`: Unique identifier
- `Vector3 position`: Position in world coordinates
- `Quaternion rotation`: Rotation as a quaternion
- `DateTime timestamp`: Creation timestamp

---

### ARPlane

Represents a detected plane in the AR scene.

```dart
class ARPlane
```

#### Properties

- `String id`: Unique identifier
- `Vector3 center`: Center point of the plane
- `Vector3 extent`: Dimensions of the plane (width, height, depth)
- `PlaneType type`: Type of plane (horizontal, vertical, unknown)

---

### ARHitResult

Result from a hit test operation.

```dart
class ARHitResult
```

#### Properties

- `Vector3 position`: World position of the hit
- `Quaternion rotation`: Rotation at the hit point
- `double distance`: Distance from camera to hit point
- `String? planeId`: ID of the plane that was hit (if any)

---

### Vector3

Represents a 3D vector.

```dart
class Vector3
```

#### Constructor

```dart
const Vector3(double x, double y, double z)
```

#### Factory Constructors

```dart
factory Vector3.zero()  // Creates (0, 0, 0)
```

#### Properties

- `double x`: X component
- `double y`: Y component
- `double z`: Z component

---

### Quaternion

Represents a rotation using quaternions.

```dart
class Quaternion
```

#### Constructor

```dart
const Quaternion(double x, double y, double z, double w)
```

#### Factory Constructors

```dart
factory Quaternion.identity()  // Creates (0, 0, 0, 1)
```

#### Properties

- `double x`: X component
- `double y`: Y component
- `double z`: Z component
- `double w`: W (scalar) component

---

## Enums

### NodeType

Types of 3D objects that can be created.

```dart
enum NodeType {
  sphere,
  cube,
  cylinder,
  model,
}
```

### PlaneType

Types of detected planes.

```dart
enum PlaneType {
  horizontal,
  vertical,
  unknown,
}
```

---

## Type Definitions

### AugenViewCreatedCallback

```dart
typedef AugenViewCreatedCallback = void Function(AugenController controller);
```

Callback invoked when the AR view is created.

---

## Error Handling

All async methods may throw `PlatformException` on failure. Always wrap calls in try-catch blocks:

```dart
try {
  await _controller.addNode(node);
} on PlatformException catch (e) {
  print('Failed to add node: ${e.message}');
}
```

Alternatively, listen to the error stream:

```dart
_controller.errorStream.listen((error) {
  // Handle error
});
```

---

## Platform-Specific Notes

### Android (ARCore)

- Requires API level 24+
- Device must support ARCore
- Google Play Services for AR must be installed

### iOS (RealityKit/ARKit)

- Requires iOS 13.0+
- Device must have A9 chip or later
- ARKit must be supported

---

For more examples and usage patterns, see the [example app](../example/) and [README](../README.md).

