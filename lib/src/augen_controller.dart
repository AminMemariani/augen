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
import 'models/animation_blend.dart';
import 'models/animation_transition.dart';
import 'models/animation_state_machine.dart';
import 'models/animation_blend_tree.dart';
import 'models/ar_image_target.dart';
import 'models/ar_tracked_image.dart';

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
  final StreamController<TransitionStatus> _transitionStatusController =
      StreamController<TransitionStatus>.broadcast();
  final StreamController<StateMachineStatus> _stateMachineStatusController =
      StreamController<StateMachineStatus>.broadcast();
  final StreamController<List<ARImageTarget>> _imageTargetsController =
      StreamController<List<ARImageTarget>>.broadcast();
  final StreamController<List<ARTrackedImage>> _trackedImagesController =
      StreamController<List<ARTrackedImage>>.broadcast();

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

  /// Stream of animation transition status updates
  Stream<TransitionStatus> get transitionStatusStream =>
      _transitionStatusController.stream;

  /// Stream of animation state machine status updates
  Stream<StateMachineStatus> get stateMachineStatusStream =>
      _stateMachineStatusController.stream;

  /// Stream of image targets
  Stream<List<ARImageTarget>> get imageTargetsStream =>
      _imageTargetsController.stream;

  /// Stream of tracked images
  Stream<List<ARTrackedImage>> get trackedImagesStream =>
      _trackedImagesController.stream;

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
      case 'onTransitionStatus':
        final statusData = call.arguments as Map;
        final status = TransitionStatus.fromMap(statusData);
        _transitionStatusController.add(status);
        break;
      case 'onStateMachineStatus':
        final statusData = call.arguments as Map;
        final status = StateMachineStatus.fromMap(statusData);
        _stateMachineStatusController.add(status);
        break;
      case 'onImageTargetsUpdated':
        final targetsData = call.arguments as List;
        final targets = targetsData
            .map((e) => ARImageTarget.fromMap(e as Map))
            .toList();
        _imageTargetsController.add(targets);
        break;
      case 'onTrackedImagesUpdated':
        final trackedData = call.arguments as List;
        final trackedImages = trackedData
            .map((e) => ARTrackedImage.fromMap(e as Map))
            .toList();
        _trackedImagesController.add(trackedImages);
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

  // ===== ANIMATION BLENDING METHODS =====

  /// Play a blend set on a node
  Future<void> playBlendSet({
    required String nodeId,
    required AnimationBlendSet blendSet,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('playBlendSet', {
        'nodeId': nodeId,
        'blendSet': blendSet.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to play blend set: ${e.message}');
      rethrow;
    }
  }

  /// Stop a blend set on a node
  Future<void> stopBlendSet({
    required String nodeId,
    required String blendSetId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopBlendSet', {
        'nodeId': nodeId,
        'blendSetId': blendSetId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop blend set: ${e.message}');
      rethrow;
    }
  }

  /// Update blend weights in a running blend set
  Future<void> updateBlendWeights({
    required String nodeId,
    required String blendSetId,
    required Map<String, double> weights,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateBlendWeights', {
        'nodeId': nodeId,
        'blendSetId': blendSetId,
        'weights': weights,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to update blend weights: ${e.message}');
      rethrow;
    }
  }

  /// Start a crossfade transition between two animations
  Future<void> startCrossfadeTransition({
    required String nodeId,
    required CrossfadeTransition transition,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('startCrossfadeTransition', {
        'nodeId': nodeId,
        'transition': transition.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to start crossfade transition: ${e.message}',
      );
      rethrow;
    }
  }

  /// Stop a running transition
  Future<void> stopTransition({
    required String nodeId,
    required String transitionId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopTransition', {
        'nodeId': nodeId,
        'transitionId': transitionId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop transition: ${e.message}');
      rethrow;
    }
  }

  /// Start an animation state machine on a node
  Future<void> startStateMachine({
    required String nodeId,
    required AnimationStateMachine stateMachine,
    Map<String, dynamic>? initialParameters,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('startStateMachine', {
        'nodeId': nodeId,
        'stateMachine': stateMachine.toMap(),
        if (initialParameters != null) 'initialParameters': initialParameters,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to start state machine: ${e.message}');
      rethrow;
    }
  }

  /// Stop an animation state machine
  Future<void> stopStateMachine({
    required String nodeId,
    required String stateMachineId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopStateMachine', {
        'nodeId': nodeId,
        'stateMachineId': stateMachineId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop state machine: ${e.message}');
      rethrow;
    }
  }

  /// Update parameters in a running state machine
  Future<void> updateStateMachineParameters({
    required String nodeId,
    required String stateMachineId,
    required Map<String, dynamic> parameters,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateStateMachineParameters', {
        'nodeId': nodeId,
        'stateMachineId': stateMachineId,
        'parameters': parameters,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to update state machine parameters: ${e.message}',
      );
      rethrow;
    }
  }

  /// Trigger a transition in a state machine
  Future<void> triggerStateMachineTransition({
    required String nodeId,
    required String stateMachineId,
    required String targetStateId,
    Map<String, dynamic>? parameters,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('triggerStateMachineTransition', {
        'nodeId': nodeId,
        'stateMachineId': stateMachineId,
        'targetStateId': targetStateId,
        if (parameters != null) 'parameters': parameters,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to trigger state machine transition: ${e.message}',
      );
      rethrow;
    }
  }

  /// Start a blend tree on a node
  Future<void> startBlendTree({
    required String nodeId,
    required AnimationBlendTree blendTree,
    Map<String, dynamic>? initialParameters,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('startBlendTree', {
        'nodeId': nodeId,
        'blendTree': blendTree.toMap(),
        if (initialParameters != null) 'initialParameters': initialParameters,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to start blend tree: ${e.message}');
      rethrow;
    }
  }

  /// Stop a blend tree
  Future<void> stopBlendTree({
    required String nodeId,
    required String blendTreeId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopBlendTree', {
        'nodeId': nodeId,
        'blendTreeId': blendTreeId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop blend tree: ${e.message}');
      rethrow;
    }
  }

  /// Update parameters in a running blend tree
  Future<void> updateBlendTreeParameters({
    required String nodeId,
    required String blendTreeId,
    required Map<String, dynamic> parameters,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateBlendTreeParameters', {
        'nodeId': nodeId,
        'blendTreeId': blendTreeId,
        'parameters': parameters,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to update blend tree parameters: ${e.message}',
      );
      rethrow;
    }
  }

  /// Set animation layer weight
  Future<void> setAnimationLayerWeight({
    required String nodeId,
    required int layer,
    required double weight,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setAnimationLayerWeight', {
        'nodeId': nodeId,
        'layer': layer,
        'weight': weight,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to set animation layer weight: ${e.message}',
      );
      rethrow;
    }
  }

  /// Get current animation layers for a node
  Future<List<Map<String, dynamic>>> getAnimationLayers(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getAnimationLayers', {
        'nodeId': nodeId,
      });
      return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
          [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get animation layers: ${e.message}');
      return [];
    }
  }

  /// Play additive animation on top of base layer
  Future<void> playAdditiveAnimation({
    required String nodeId,
    required String animationId,
    required int targetLayer,
    double weight = 1.0,
    AnimationLoopMode loopMode = AnimationLoopMode.loop,
    List<String>? boneMask,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('playAdditiveAnimation', {
        'nodeId': nodeId,
        'animationId': animationId,
        'targetLayer': targetLayer,
        'weight': weight,
        'loopMode': loopMode.name,
        if (boneMask != null) 'boneMask': boneMask,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to play additive animation: ${e.message}');
      rethrow;
    }
  }

  /// Set bone mask for an animation layer
  Future<void> setAnimationBoneMask({
    required String nodeId,
    required int layer,
    required List<String> boneMask,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setAnimationBoneMask', {
        'nodeId': nodeId,
        'layer': layer,
        'boneMask': boneMask,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set animation bone mask: ${e.message}');
      rethrow;
    }
  }

  /// Get bone hierarchy for a model
  Future<List<String>> getBoneHierarchy(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getBoneHierarchy', {
        'nodeId': nodeId,
      });
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get bone hierarchy: ${e.message}');
      return [];
    }
  }

  /// Create and play a simple crossfade between two animations
  Future<void> crossfadeToAnimation({
    required String nodeId,
    required String fromAnimationId,
    required String toAnimationId,
    double duration = 0.3,
    TransitionCurve curve = TransitionCurve.linear,
  }) async {
    final transition = CrossfadeTransition(
      id: 'crossfade_${DateTime.now().millisecondsSinceEpoch}',
      fromAnimationId: fromAnimationId,
      toAnimationId: toAnimationId,
      duration: duration,
      curve: curve,
    );

    await startCrossfadeTransition(nodeId: nodeId, transition: transition);
  }

  /// Create and play a blend between multiple animations with weights
  Future<void> blendAnimations({
    required String nodeId,
    required Map<String, double> animationWeights,
    String? blendSetId,
    BlendType blendType = BlendType.linear,
    double fadeInDuration = 0.3,
  }) async {
    final blends = animationWeights.entries.map((entry) {
      return AnimationBlend(animationId: entry.key, weight: entry.value);
    }).toList();

    final blendSet = AnimationBlendSet(
      id: blendSetId ?? 'blend_${DateTime.now().millisecondsSinceEpoch}',
      animations: blends,
      blendType: blendType,
      fadeInDuration: fadeInDuration,
    );

    await playBlendSet(nodeId: nodeId, blendSet: blendSet);
  }

  // ===== IMAGE TRACKING METHODS =====

  /// Add an image target for tracking
  Future<void> addImageTarget(ARImageTarget target) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('addImageTarget', target.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to add image target: ${e.message}');
      rethrow;
    }
  }

  /// Remove an image target
  Future<void> removeImageTarget(String targetId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeImageTarget', {'targetId': targetId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove image target: ${e.message}');
      rethrow;
    }
  }

  /// Get all registered image targets
  Future<List<ARImageTarget>> getImageTargets() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getImageTargets');
      return result?.map((e) => ARImageTarget.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get image targets: ${e.message}');
      return [];
    }
  }

  /// Get currently tracked images
  Future<List<ARTrackedImage>> getTrackedImages() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getTrackedImages');
      return result?.map((e) => ARTrackedImage.fromMap(e as Map)).toList() ??
          [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get tracked images: ${e.message}');
      return [];
    }
  }

  /// Enable or disable image tracking
  Future<void> setImageTrackingEnabled(bool enabled) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setImageTrackingEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set image tracking: ${e.message}');
      rethrow;
    }
  }

  /// Check if image tracking is enabled
  Future<bool> isImageTrackingEnabled() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<bool>(
        'isImageTrackingEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to check image tracking status: ${e.message}',
      );
      return false;
    }
  }

  /// Add a node anchored to a tracked image
  Future<void> addNodeToTrackedImage({
    required String nodeId,
    required String trackedImageId,
    required ARNode node,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final nodeData = node.toMap();
      nodeData['trackedImageId'] = trackedImageId;

      // If it's a model node with an asset path, load the asset data
      if (node.type == NodeType.model &&
          node.modelPath != null &&
          !node.modelPath!.startsWith('http')) {
        final modelBytes = await _loadAsset(node.modelPath!);
        nodeData['modelData'] = modelBytes;
      }

      await _channel.invokeMethod('addNodeToTrackedImage', {
        'nodeId': nodeId,
        'nodeData': nodeData,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to add node to tracked image: ${e.message}');
      rethrow;
    }
  }

  /// Remove a node from a tracked image
  Future<void> removeNodeFromTrackedImage(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeNodeFromTrackedImage', {
        'nodeId': nodeId,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to remove node from tracked image: ${e.message}',
      );
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
    _transitionStatusController.close();
    _stateMachineStatusController.close();
    _imageTargetsController.close();
    _trackedImagesController.close();
    _channel.setMethodCallHandler(null);
  }
}
