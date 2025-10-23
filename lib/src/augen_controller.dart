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
import 'models/ar_face.dart';
import 'models/ar_cloud_anchor.dart';
import 'models/ar_occlusion.dart';
import 'models/ar_physics.dart';
import 'models/ar_multi_user.dart';

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
  final StreamController<List<ARFace>> _facesController =
      StreamController<List<ARFace>>.broadcast();
  final StreamController<List<ARCloudAnchor>> _cloudAnchorsController =
      StreamController<List<ARCloudAnchor>>.broadcast();
  final StreamController<CloudAnchorStatus> _cloudAnchorStatusController =
      StreamController<CloudAnchorStatus>.broadcast();
  final StreamController<List<AROcclusion>> _occlusionsController =
      StreamController<List<AROcclusion>>.broadcast();
  final StreamController<OcclusionStatus> _occlusionStatusController =
      StreamController<OcclusionStatus>.broadcast();
  final StreamController<List<ARPhysicsBody>> _physicsBodiesController =
      StreamController<List<ARPhysicsBody>>.broadcast();
  final StreamController<List<PhysicsConstraint>>
  _physicsConstraintsController =
      StreamController<List<PhysicsConstraint>>.broadcast();
  final StreamController<PhysicsStatus> _physicsStatusController =
      StreamController<PhysicsStatus>.broadcast();

  // Multi-user stream controllers
  final StreamController<ARMultiUserSession> _multiUserSessionController =
      StreamController<ARMultiUserSession>.broadcast();
  final StreamController<List<MultiUserParticipant>>
  _multiUserParticipantsController =
      StreamController<List<MultiUserParticipant>>.broadcast();
  final StreamController<List<MultiUserSharedObject>>
  _multiUserSharedObjectsController =
      StreamController<List<MultiUserSharedObject>>.broadcast();
  final StreamController<MultiUserSessionStatus>
  _multiUserSessionStatusController =
      StreamController<MultiUserSessionStatus>.broadcast();

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

  /// Stream of tracked faces
  Stream<List<ARFace>> get facesStream => _facesController.stream;

  /// Stream of cloud anchors
  Stream<List<ARCloudAnchor>> get cloudAnchorsStream =>
      _cloudAnchorsController.stream;

  /// Stream of cloud anchor status updates
  Stream<CloudAnchorStatus> get cloudAnchorStatusStream =>
      _cloudAnchorStatusController.stream;

  /// Stream of occlusions
  Stream<List<AROcclusion>> get occlusionsStream =>
      _occlusionsController.stream;

  /// Stream of occlusion status updates
  Stream<OcclusionStatus> get occlusionStatusStream =>
      _occlusionStatusController.stream;

  /// Stream of physics bodies updates
  Stream<List<ARPhysicsBody>> get physicsBodiesStream =>
      _physicsBodiesController.stream;

  /// Stream of physics constraints updates
  Stream<List<PhysicsConstraint>> get physicsConstraintsStream =>
      _physicsConstraintsController.stream;

  /// Stream of physics status updates
  Stream<PhysicsStatus> get physicsStatusStream =>
      _physicsStatusController.stream;

  // Multi-user streams
  Stream<ARMultiUserSession> get multiUserSessionStream =>
      _multiUserSessionController.stream;
  Stream<List<MultiUserParticipant>> get multiUserParticipantsStream =>
      _multiUserParticipantsController.stream;
  Stream<List<MultiUserSharedObject>> get multiUserSharedObjectsStream =>
      _multiUserSharedObjectsController.stream;
  Stream<MultiUserSessionStatus> get multiUserSessionStatusStream =>
      _multiUserSessionStatusController.stream;

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
      case 'onFacesUpdated':
        final facesData = call.arguments as List;
        final faces = facesData.map((e) => ARFace.fromMap(e as Map)).toList();
        _facesController.add(faces);
        break;
      case 'onCloudAnchorsUpdated':
        final anchorsData = call.arguments as List;
        final anchors = anchorsData
            .map((e) => ARCloudAnchor.fromMap(e as Map))
            .toList();
        _cloudAnchorsController.add(anchors);
        break;
      case 'onCloudAnchorStatusUpdated':
        final statusData = call.arguments as Map;
        final status = CloudAnchorStatus.fromMap(statusData);
        _cloudAnchorStatusController.add(status);
        break;
      case 'onOcclusionsUpdated':
        final occlusionsData = call.arguments as List;
        final occlusions = occlusionsData
            .map((e) => AROcclusion.fromMap(e as Map<String, dynamic>))
            .toList();
        _occlusionsController.add(occlusions);
        break;
      case 'onOcclusionStatusUpdated':
        final statusData = call.arguments as Map<String, dynamic>;
        final status = OcclusionStatus.fromMap(statusData);
        _occlusionStatusController.add(status);
        break;
      case 'onPhysicsBodiesUpdated':
        final bodiesData = call.arguments as List;
        final bodies = bodiesData
            .map((e) => ARPhysicsBody.fromMap(e as Map<String, dynamic>))
            .toList();
        _physicsBodiesController.add(bodies);
        break;
      case 'onPhysicsConstraintsUpdated':
        final constraintsData = call.arguments as List;
        final constraints = constraintsData
            .map((e) => PhysicsConstraint.fromMap(e as Map<String, dynamic>))
            .toList();
        _physicsConstraintsController.add(constraints);
        break;
      case 'onPhysicsStatusUpdated':
        final statusData = call.arguments as Map<String, dynamic>;
        final status = PhysicsStatus.fromMap(statusData);
        _physicsStatusController.add(status);
        break;
      case 'onMultiUserSessionUpdated':
        final sessionData = call.arguments as Map<String, dynamic>;
        final session = ARMultiUserSession.fromMap(sessionData);
        _multiUserSessionController.add(session);
        break;
      case 'onMultiUserParticipantsUpdated':
        final participantsData = call.arguments as List;
        final participants = participantsData
            .map((e) => MultiUserParticipant.fromMap(e as Map<String, dynamic>))
            .toList();
        _multiUserParticipantsController.add(participants);
        break;
      case 'onMultiUserSharedObjectsUpdated':
        final objectsData = call.arguments as List;
        final objects = objectsData
            .map(
              (e) => MultiUserSharedObject.fromMap(e as Map<String, dynamic>),
            )
            .toList();
        _multiUserSharedObjectsController.add(objects);
        break;
      case 'onMultiUserSessionStatusUpdated':
        final statusData = call.arguments as Map<String, dynamic>;
        final status = MultiUserSessionStatus.fromMap(statusData);
        _multiUserSessionStatusController.add(status);
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

  // Face Tracking Methods

  /// Enable or disable face tracking
  Future<void> setFaceTrackingEnabled(bool enabled) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setFaceTrackingEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set face tracking: ${e.message}');
      rethrow;
    }
  }

  /// Check if face tracking is enabled
  Future<bool> isFaceTrackingEnabled() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<bool>('isFaceTrackingEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to check face tracking status: ${e.message}',
      );
      return false;
    }
  }

  /// Get currently tracked faces
  Future<List<ARFace>> getTrackedFaces() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getTrackedFaces');
      return result?.map((e) => ARFace.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get tracked faces: ${e.message}');
      return [];
    }
  }

  /// Add a node anchored to a tracked face
  Future<void> addNodeToTrackedFace({
    required String nodeId,
    required String faceId,
    required ARNode node,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('addNodeToTrackedFace', {
        'nodeId': nodeId,
        'faceId': faceId,
        'node': node.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to add node to tracked face: ${e.message}');
      rethrow;
    }
  }

  /// Remove a node from a tracked face
  Future<void> removeNodeFromTrackedFace({
    required String nodeId,
    required String faceId,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeNodeFromTrackedFace', {
        'nodeId': nodeId,
        'faceId': faceId,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to remove node from tracked face: ${e.message}',
      );
      rethrow;
    }
  }

  /// Get face landmarks for a specific face
  Future<List<FaceLandmark>> getFaceLandmarks(String faceId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('getFaceLandmarks', {
        'faceId': faceId,
      });
      return result?.map((e) => FaceLandmark.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get face landmarks: ${e.message}');
      return [];
    }
  }

  /// Set face tracking configuration
  Future<void> setFaceTrackingConfig({
    bool detectLandmarks = true,
    bool detectExpressions = true,
    double minFaceSize = 0.1,
    double maxFaceSize = 1.0,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setFaceTrackingConfig', {
        'detectLandmarks': detectLandmarks,
        'detectExpressions': detectExpressions,
        'minFaceSize': minFaceSize,
        'maxFaceSize': maxFaceSize,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set face tracking config: ${e.message}');
      rethrow;
    }
  }

  // ===== Cloud Anchor Methods =====

  /// Create a cloud anchor from a local anchor
  Future<String> createCloudAnchor(String localAnchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('createCloudAnchor', {
        'localAnchorId': localAnchorId,
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to create cloud anchor: ${e.message}');
      rethrow;
    }
  }

  /// Resolve a cloud anchor by its ID
  Future<void> resolveCloudAnchor(String cloudAnchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('resolveCloudAnchor', {
        'cloudAnchorId': cloudAnchorId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to resolve cloud anchor: ${e.message}');
      rethrow;
    }
  }

  /// Get all cloud anchors
  Future<List<ARCloudAnchor>> getCloudAnchors() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getCloudAnchors');
      final anchorsData = result as List;
      return anchorsData.map((e) => ARCloudAnchor.fromMap(e as Map)).toList();
    } on PlatformException catch (e) {
      _errorController.add('Failed to get cloud anchors: ${e.message}');
      rethrow;
    }
  }

  /// Get a specific cloud anchor by ID
  Future<ARCloudAnchor?> getCloudAnchor(String cloudAnchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getCloudAnchor', {
        'cloudAnchorId': cloudAnchorId,
      });
      if (result == null) return null;
      return ARCloudAnchor.fromMap(result as Map);
    } on PlatformException catch (e) {
      _errorController.add('Failed to get cloud anchor: ${e.message}');
      rethrow;
    }
  }

  /// Delete a cloud anchor
  Future<void> deleteCloudAnchor(String cloudAnchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('deleteCloudAnchor', {
        'cloudAnchorId': cloudAnchorId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to delete cloud anchor: ${e.message}');
      rethrow;
    }
  }

  /// Check if cloud anchors are supported
  Future<bool> isCloudAnchorsSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('isCloudAnchorsSupported');
      return result as bool;
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to check cloud anchors support: ${e.message}',
      );
      return false;
    }
  }

  /// Set cloud anchor configuration
  Future<void> setCloudAnchorConfig({
    int maxCloudAnchors = 10,
    Duration timeout = const Duration(seconds: 30),
    bool enableSharing = true,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setCloudAnchorConfig', {
        'maxCloudAnchors': maxCloudAnchors,
        'timeoutMs': timeout.inMilliseconds,
        'enableSharing': enableSharing,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set cloud anchor config: ${e.message}');
      rethrow;
    }
  }

  /// Share a cloud anchor with other users
  Future<String> shareCloudAnchor(String cloudAnchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('shareCloudAnchor', {
        'cloudAnchorId': cloudAnchorId,
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to share cloud anchor: ${e.message}');
      rethrow;
    }
  }

  /// Join a shared cloud anchor session
  Future<void> joinCloudAnchorSession(String sessionId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('joinCloudAnchorSession', {
        'sessionId': sessionId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to join cloud anchor session: ${e.message}');
      rethrow;
    }
  }

  /// Leave the current cloud anchor session
  Future<void> leaveCloudAnchorSession() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('leaveCloudAnchorSession');
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to leave cloud anchor session: ${e.message}',
      );
      rethrow;
    }
  }

  // ===== Occlusion Methods =====

  /// Enable or disable occlusion
  Future<void> setOcclusionEnabled(bool enabled) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setOcclusionEnabled', {'enabled': enabled});
    } on PlatformException catch (e) {
      _errorController.add('Failed to set occlusion enabled: ${e.message}');
      rethrow;
    }
  }

  /// Check if occlusion is enabled
  Future<bool> isOcclusionEnabled() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('isOcclusionEnabled');
      return result as bool;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check occlusion enabled: ${e.message}');
      rethrow;
    }
  }

  /// Set occlusion configuration
  Future<void> setOcclusionConfig({
    required OcclusionType type,
    double confidence = 0.7,
    bool enablePersonOcclusion = true,
    bool enablePlaneOcclusion = true,
    bool enableDepthOcclusion = true,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setOcclusionConfig', {
        'type': type.name,
        'confidence': confidence,
        'enablePersonOcclusion': enablePersonOcclusion,
        'enablePlaneOcclusion': enablePlaneOcclusion,
        'enableDepthOcclusion': enableDepthOcclusion,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set occlusion config: ${e.message}');
      rethrow;
    }
  }

  /// Get all active occlusions
  Future<List<AROcclusion>> getOcclusions() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getOcclusions');
      final occlusionsData = result as List;
      return occlusionsData
          .map((e) => AROcclusion.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PlatformException catch (e) {
      _errorController.add('Failed to get occlusions: ${e.message}');
      rethrow;
    }
  }

  /// Get a specific occlusion by ID
  Future<AROcclusion?> getOcclusion(String occlusionId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getOcclusion', {
        'occlusionId': occlusionId,
      });
      if (result == null) return null;
      return AROcclusion.fromMap(Map<String, dynamic>.from(result as Map));
    } on PlatformException catch (e) {
      _errorController.add('Failed to get occlusion: ${e.message}');
      rethrow;
    }
  }

  /// Create a new occlusion
  Future<String> createOcclusion({
    required OcclusionType type,
    required Vector3 position,
    required Quaternion rotation,
    required Vector3 scale,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('createOcclusion', {
        'type': type.name,
        'position': position.toMap(),
        'rotation': rotation.toMap(),
        'scale': scale.toMap(),
        'metadata': metadata ?? {},
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to create occlusion: ${e.message}');
      rethrow;
    }
  }

  /// Update an existing occlusion
  Future<void> updateOcclusion({
    required String occlusionId,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateOcclusion', {
        'occlusionId': occlusionId,
        if (position != null) 'position': position.toMap(),
        if (rotation != null) 'rotation': rotation.toMap(),
        if (scale != null) 'scale': scale.toMap(),
        if (metadata != null) 'metadata': metadata,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to update occlusion: ${e.message}');
      rethrow;
    }
  }

  /// Remove an occlusion
  Future<void> removeOcclusion(String occlusionId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeOcclusion', {
        'occlusionId': occlusionId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove occlusion: ${e.message}');
      rethrow;
    }
  }

  /// Check if occlusion is supported on the current device
  Future<bool> isOcclusionSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('isOcclusionSupported');
      return result as bool;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check occlusion support: ${e.message}');
      rethrow;
    }
  }

  /// Get occlusion capabilities
  Future<Map<String, dynamic>> getOcclusionCapabilities() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getOcclusionCapabilities');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to get occlusion capabilities: ${e.message}',
      );
      rethrow;
    }
  }

  // ===== Physics Methods =====
  /// Check if physics simulation is supported
  Future<bool> isPhysicsSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('isPhysicsSupported');
      return result as bool;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check physics support: ${e.message}');
      rethrow;
    }
  }

  /// Initialize physics world with configuration
  Future<void> initializePhysics(PhysicsWorldConfig config) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('initializePhysics', config.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize physics: ${e.message}');
      rethrow;
    }
  }

  /// Start physics simulation
  Future<void> startPhysics() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('startPhysics');
    } on PlatformException catch (e) {
      _errorController.add('Failed to start physics: ${e.message}');
      rethrow;
    }
  }

  /// Stop physics simulation
  Future<void> stopPhysics() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('stopPhysics');
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop physics: ${e.message}');
      rethrow;
    }
  }

  /// Pause physics simulation
  Future<void> pausePhysics() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('pausePhysics');
    } on PlatformException catch (e) {
      _errorController.add('Failed to pause physics: ${e.message}');
      rethrow;
    }
  }

  /// Resume physics simulation
  Future<void> resumePhysics() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('resumePhysics');
    } on PlatformException catch (e) {
      _errorController.add('Failed to resume physics: ${e.message}');
      rethrow;
    }
  }

  /// Create a physics body for a node
  Future<String> createPhysicsBody({
    required String nodeId,
    required PhysicsBodyType type,
    required PhysicsMaterial material,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    double? mass,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('createPhysicsBody', {
        'nodeId': nodeId,
        'type': type.name,
        'material': material.toMap(),
        if (position != null) 'position': position.toMap(),
        if (rotation != null) 'rotation': rotation.toMap(),
        if (scale != null) 'scale': scale.toMap(),
        if (mass != null) 'mass': mass,
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to create physics body: ${e.message}');
      rethrow;
    }
  }

  /// Remove a physics body
  Future<void> removePhysicsBody(String bodyId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removePhysicsBody', {'bodyId': bodyId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove physics body: ${e.message}');
      rethrow;
    }
  }

  /// Apply force to a physics body
  Future<void> applyForce({
    required String bodyId,
    required Vector3 force,
    Vector3? point,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('applyForce', {
        'bodyId': bodyId,
        'force': force.toMap(),
        if (point != null) 'point': point.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to apply force: ${e.message}');
      rethrow;
    }
  }

  /// Apply impulse to a physics body
  Future<void> applyImpulse({
    required String bodyId,
    required Vector3 impulse,
    Vector3? point,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('applyImpulse', {
        'bodyId': bodyId,
        'impulse': impulse.toMap(),
        if (point != null) 'point': point.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to apply impulse: ${e.message}');
      rethrow;
    }
  }

  /// Set velocity of a physics body
  Future<void> setVelocity({
    required String bodyId,
    required Vector3 velocity,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setVelocity', {
        'bodyId': bodyId,
        'velocity': velocity.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set velocity: ${e.message}');
      rethrow;
    }
  }

  /// Set angular velocity of a physics body
  Future<void> setAngularVelocity({
    required String bodyId,
    required Vector3 angularVelocity,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setAngularVelocity', {
        'bodyId': bodyId,
        'angularVelocity': angularVelocity.toMap(),
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set angular velocity: ${e.message}');
      rethrow;
    }
  }

  /// Create a physics constraint between two bodies
  Future<String> createPhysicsConstraint({
    required String bodyAId,
    required String bodyBId,
    required PhysicsConstraintType type,
    Vector3? anchorA,
    Vector3? anchorB,
    Vector3? axisA,
    Vector3? axisB,
    double? lowerLimit,
    double? upperLimit,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('createPhysicsConstraint', {
        'bodyAId': bodyAId,
        'bodyBId': bodyBId,
        'type': type.name,
        if (anchorA != null) 'anchorA': anchorA.toMap(),
        if (anchorB != null) 'anchorB': anchorB.toMap(),
        if (axisA != null) 'axisA': axisA.toMap(),
        if (axisB != null) 'axisB': axisB.toMap(),
        if (lowerLimit != null) 'lowerLimit': lowerLimit,
        if (upperLimit != null) 'upperLimit': upperLimit,
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to create physics constraint: ${e.message}');
      rethrow;
    }
  }

  /// Remove a physics constraint
  Future<void> removePhysicsConstraint(String constraintId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removePhysicsConstraint', {
        'constraintId': constraintId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove physics constraint: ${e.message}');
      rethrow;
    }
  }

  /// Get all physics bodies
  Future<List<ARPhysicsBody>> getPhysicsBodies() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getPhysicsBodies');
      final bodiesData = result as List;
      return bodiesData
          .map(
            (e) => ARPhysicsBody.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } on PlatformException catch (e) {
      _errorController.add('Failed to get physics bodies: ${e.message}');
      rethrow;
    }
  }

  /// Get all physics constraints
  Future<List<PhysicsConstraint>> getPhysicsConstraints() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getPhysicsConstraints');
      final constraintsData = result as List;
      return constraintsData
          .map(
            (e) =>
                PhysicsConstraint.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } on PlatformException catch (e) {
      _errorController.add('Failed to get physics constraints: ${e.message}');
      rethrow;
    }
  }

  /// Get physics world configuration
  Future<PhysicsWorldConfig> getPhysicsWorldConfig() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getPhysicsWorldConfig');
      return PhysicsWorldConfig.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } on PlatformException catch (e) {
      _errorController.add('Failed to get physics world config: ${e.message}');
      rethrow;
    }
  }

  /// Update physics world configuration
  Future<void> updatePhysicsWorldConfig(PhysicsWorldConfig config) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updatePhysicsWorldConfig', config.toMap());
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to update physics world config: ${e.message}',
      );
      rethrow;
    }
  }

  // ===== Multi-User Methods =====

  /// Check if multi-user AR is supported
  Future<bool> isMultiUserSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('isMultiUserSupported');
      return result as bool;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check multi-user support: ${e.message}');
      rethrow;
    }
  }

  /// Create a new multi-user session
  Future<String> createMultiUserSession({
    required String name,
    int maxParticipants = 8,
    bool isPrivate = false,
    String? password,
    List<MultiUserCapability> capabilities = const [
      MultiUserCapability.spatialSharing,
      MultiUserCapability.objectSynchronization,
      MultiUserCapability.realTimeCollaboration,
    ],
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('createMultiUserSession', {
        'name': name,
        'maxParticipants': maxParticipants,
        'isPrivate': isPrivate,
        'password': password,
        'capabilities': capabilities.map((c) => c.name).toList(),
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to create multi-user session: ${e.message}');
      rethrow;
    }
  }

  /// Join an existing multi-user session
  Future<void> joinMultiUserSession({
    required String sessionId,
    String? password,
    String displayName = 'User',
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('joinMultiUserSession', {
        'sessionId': sessionId,
        'password': password,
        'displayName': displayName,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to join multi-user session: ${e.message}');
      rethrow;
    }
  }

  /// Leave the current multi-user session
  Future<void> leaveMultiUserSession() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('leaveMultiUserSession');
    } on PlatformException catch (e) {
      _errorController.add('Failed to leave multi-user session: ${e.message}');
      rethrow;
    }
  }

  /// Get current multi-user session
  Future<ARMultiUserSession?> getMultiUserSession() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getMultiUserSession');
      if (result == null) return null;
      return ARMultiUserSession.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } on PlatformException catch (e) {
      _errorController.add('Failed to get multi-user session: ${e.message}');
      rethrow;
    }
  }

  /// Get all participants in the current session
  Future<List<MultiUserParticipant>> getMultiUserParticipants() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getMultiUserParticipants');
      final participantsData = result as List;
      return participantsData
          .map(
            (e) => MultiUserParticipant.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to get multi-user participants: ${e.message}',
      );
      rethrow;
    }
  }

  /// Share an object with other participants
  Future<String> shareObject({
    required String nodeId,
    bool isLocked = false,
    bool isVisible = true,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('shareObject', {
        'nodeId': nodeId,
        'isLocked': isLocked,
        'isVisible': isVisible,
      });
      return result as String;
    } on PlatformException catch (e) {
      _errorController.add('Failed to share object: ${e.message}');
      rethrow;
    }
  }

  /// Unshare an object (remove from shared objects)
  Future<void> unshareObject(String sharedObjectId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('unshareObject', {
        'sharedObjectId': sharedObjectId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to unshare object: ${e.message}');
      rethrow;
    }
  }

  /// Update a shared object's properties
  Future<void> updateSharedObject({
    required String sharedObjectId,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    bool? isLocked,
    bool? isVisible,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateSharedObject', {
        'sharedObjectId': sharedObjectId,
        'position': position?.toMap(),
        'rotation': rotation?.toMap(),
        'scale': scale?.toMap(),
        'isLocked': isLocked,
        'isVisible': isVisible,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to update shared object: ${e.message}');
      rethrow;
    }
  }

  /// Get all shared objects in the current session
  Future<List<MultiUserSharedObject>> getMultiUserSharedObjects() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod('getMultiUserSharedObjects');
      final objectsData = result as List;
      return objectsData
          .map(
            (e) => MultiUserSharedObject.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to get multi-user shared objects: ${e.message}',
      );
      rethrow;
    }
  }

  /// Set participant role
  Future<void> setParticipantRole({
    required String participantId,
    required MultiUserRole role,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('setParticipantRole', {
        'participantId': participantId,
        'role': role.name,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to set participant role: ${e.message}');
      rethrow;
    }
  }

  /// Kick a participant from the session
  Future<void> kickParticipant(String participantId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('kickParticipant', {
        'participantId': participantId,
      });
    } on PlatformException catch (e) {
      _errorController.add('Failed to kick participant: ${e.message}');
      rethrow;
    }
  }

  /// Update participant display name
  Future<void> updateParticipantDisplayName({
    required String participantId,
    required String displayName,
  }) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateParticipantDisplayName', {
        'participantId': participantId,
        'displayName': displayName,
      });
    } on PlatformException catch (e) {
      _errorController.add(
        'Failed to update participant display name: ${e.message}',
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
    _facesController.close();
    _cloudAnchorsController.close();
    _cloudAnchorStatusController.close();
    _occlusionsController.close();
    _occlusionStatusController.close();
    _physicsBodiesController.close();
    _physicsConstraintsController.close();
    _physicsStatusController.close();
    _multiUserSessionController.close();
    _multiUserParticipantsController.close();
    _multiUserSharedObjectsController.close();
    _multiUserSessionStatusController.close();
    _channel.setMethodCallHandler(null);
  }
}
