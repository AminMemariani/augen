import 'dart:async';
import 'package:flutter/services.dart';
import 'models/ar_anchor.dart';
import 'models/ar_node.dart';
import 'models/ar_plane.dart';
import 'models/ar_hit_result.dart';
import 'models/ar_session_config.dart';
import 'models/vector3.dart';
import 'models/quaternion.dart';
import 'models/ar_animation.dart';
import 'dart:typed_data';

/// Controller for managing AR session
class AugenController {
  final MethodChannel _channel;
  final int viewId;

  final StreamController<List<ARPlane>> _planesController =
      StreamController<List<ARPlane>>.broadcast();
  final StreamController<List<ARAnchor>> _anchorsController =
      StreamController<List<ARAnchor>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<AnimationStatus> _animationStatusController =
      StreamController<AnimationStatus>.broadcast();

  bool _isDisposed = false;

  AugenController(this.viewId) : _channel = MethodChannel('augen_$viewId') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Stream of detected planes
  Stream<List<ARPlane>> get planesStream => _planesController.stream;

  /// Stream of AR anchors
  Stream<List<ARAnchor>> get anchorsStream => _anchorsController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Stream of animation status updates
  Stream<AnimationStatus> get animationStatusStream =>
      _animationStatusController.stream;

  /// Initialize AR session with configuration
  Future<void> initialize(ARSessionConfig config) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('initialize', config.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize AR: ${e.message}');
      rethrow;
    }
  }

  /// Check if AR is supported on this device
  Future<bool> isARSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<bool>('isARSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check AR support: ${e.message}');
      return false;
    }
  }

  /// Add a node to the AR scene
  Future<void> addNode(ARNode node) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final nodeData = node.toMap();

      // If it's a model node with an asset path, load the asset data
      if (node.type == NodeType.model &&
          node.modelPath != null &&
          !node.modelPath!.startsWith('http')) {
        final modelBytes = await _loadAsset(node.modelPath!);
        nodeData['modelData'] = modelBytes;
      }

      await _channel.invokeMethod('addNode', nodeData);
    } on PlatformException catch (e) {
      _errorController.add('Failed to add node: ${e.message}');
      rethrow;
    }
  }

  /// Load asset file as bytes
  Future<Uint8List> _loadAsset(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  /// Add a custom 3D model from asset
  Future<void> addModelFromAsset({
    required String id,
    required String assetPath,
    required Vector3 position,
    Quaternion rotation = const Quaternion(0, 0, 0, 1),
    Vector3 scale = const Vector3(1, 1, 1),
    ModelFormat? modelFormat,
    Map<String, dynamic>? properties,
  }) async {
    final node = ARNode.fromModel(
      id: id,
      modelPath: assetPath,
      position: position,
      rotation: rotation,
      scale: scale,
      modelFormat: modelFormat,
      properties: properties,
    );
    await addNode(node);
  }

  /// Add a custom 3D model from URL
  Future<void> addModelFromUrl({
    required String id,
    required String url,
    required Vector3 position,
    Quaternion rotation = const Quaternion(0, 0, 0, 1),
    Vector3 scale = const Vector3(1, 1, 1),
    ModelFormat? modelFormat,
    Map<String, dynamic>? properties,
  }) async {
    final node = ARNode.fromModel(
      id: id,
      modelPath: url,
      position: position,
      rotation: rotation,
      scale: scale,
      modelFormat: modelFormat,
      properties: properties,
    );
    await addNode(node);
  }

  /// Remove a node from the AR scene
  Future<void> removeNode(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeNode', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove node: ${e.message}');
      rethrow;
    }
  }

  /// Update an existing node
  Future<void> updateNode(ARNode node) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateNode', node.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to update node: ${e.message}');
      rethrow;
    }
  }

  /// Perform hit test at screen coordinates
  Future<List<ARHitResult>> hitTest(double x, double y) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('hitTest', {
        'x': x,
        'y': y,
      });
      return result?.map((e) => ARHitResult.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to perform hit test: ${e.message}');
      return [];
    }
  }

  /// Add an anchor at the specified position
  Future<ARAnchor?> addAnchor(Vector3 position) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<Map>(
        'addAnchor',
        position.toMap(),
      );
      return result != null ? ARAnchor.fromMap(result) : null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to add anchor: ${e.message}');
      return null;
    }
  }

  /// Remove an anchor
  Future<void> removeAnchor(String anchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeAnchor', {'anchorId': anchorId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove anchor: ${e.message}');
      rethrow;
    }
  }

  /// Pause AR session
  Future<void> pause() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException catch (e) {
      _errorController.add('Failed to pause AR: ${e.message}');
      rethrow;
    }
  }

  /// Resume AR session
  Future<void> resume() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('resume');
    } on PlatformException catch (e) {
      _errorController.add('Failed to resume AR: ${e.message}');
      rethrow;
    }
  }

  /// Reset AR session
  Future<void> reset() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('reset');
    } on PlatformException catch (e) {
      _errorController.add('Failed to reset AR: ${e.message}');
      rethrow;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_isDisposed) return;

    switch (call.method) {
      case 'onPlanesUpdated':
        final planesData = call.arguments as List;
        final planes = planesData
            .map((e) => ARPlane.fromMap(e as Map))
            .toList();
        _planesController.add(planes);
        break;
      case 'onAnchorsUpdated':
        final anchorsData = call.arguments as List;
        final anchors = anchorsData
            .map((e) => ARAnchor.fromMap(e as Map))
            .toList();
        _anchorsController.add(anchors);
        break;
      case 'onError':
        final error = call.arguments as String;
        _errorController.add(error);
        break;
      case 'onAnimationStatus':
        final statusData = call.arguments as Map;
        final status = AnimationStatus.fromMap(statusData);
        _animationStatusController.add(status);
        break;
    }
  }

  /// Play an animation on a node
  Future<void> playAnimation({
    required String nodeId,
    required String animationId,
    double speed = 1.0,
    AnimationLoopMode loopMode = AnimationLoopMode.loop,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('playAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
        'speed': speed,
        'loopMode': loopMode.name,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to play animation: ${e.message}');
      rethrow;
    }
  }

  /// Pause an animation on a node
  Future<void> pauseAnimation({
    required String nodeId,
    required String animationId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('pauseAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to pause animation: ${e.message}');
      rethrow;
    }
  }

  /// Stop an animation on a node
  Future<void> stopAnimation({
    required String nodeId,
    required String animationId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop animation: ${e.message}');
      rethrow;
    }
  }

  /// Resume an animation on a node
  Future<void> resumeAnimation({
    required String nodeId,
    required String animationId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('resumeAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to resume animation: ${e.message}');
      rethrow;
    }
  }

  /// Seek to a specific time in an animation
  Future<void> seekAnimation({
    required String nodeId,
    required String animationId,
    required double time,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('seekAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
        'time': time,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to seek animation: ${e.message}');
      rethrow;
    }
  }

  /// Get available animations for a model node
  Future<List<String>> getAvailableAnimations(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>(
        'getAvailableAnimations',
        {'nodeId': nodeId},
      );
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get animations: ${e.message}');
      return [];
    }
  }

  /// Set animation speed
  Future<void> setAnimationSpeed({
    required String nodeId,
    required String animationId,
    required double speed,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setAnimationSpeed', {
        'nodeId': nodeId,
        'animationId': animationId,
        'speed': speed,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set animation speed: ${e.message}');
      rethrow;
    }
  }

  /// Dispose the controller
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _planesController.close();
    _anchorsController.close();
    _errorController.close();
    _animationStatusController.close();
    _channel.setMethodCallHandler(null);
  }
}
