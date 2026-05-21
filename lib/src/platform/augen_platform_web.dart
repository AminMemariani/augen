import 'dart:async';
import 'package:web/web.dart' as web;
import 'augen_platform_backend.dart';
import '../web/augen_web_plugin.dart';
import '../web/web_camera_service.dart';
import '../web/wasm_marker_detector.dart';
import '../web/web_scene_renderer.dart';
import '../web/web_marker_anchor_manager.dart';
import '../web/web_asset_loader.dart';
import '../models/ar_marker_config.dart';
import '../models/ar_marker_target.dart';

/// Web implementation using JS interop and Wasm marker detection.
class AugenPlatformWeb extends AugenPlatformBackend {
  final int viewId;

  final WebCameraService _camera = WebCameraService();
  final WebAssetLoader _assetLoader = WebAssetLoader();
  late final WasmMarkerDetector _markerDetector;
  late final WebSceneRenderer _sceneRenderer;
  late final WebMarkerAnchorManager _anchorManager;

  bool _initialized = false;
  bool _disposed = false;
  StreamSubscription<dynamic>? _markerSub;
  StreamSubscription<String>? _errorSub;

  AugenPlatformWeb(this.viewId) {
    _markerDetector = WasmMarkerDetector();
    _sceneRenderer = WebSceneRenderer();
    _anchorManager = WebMarkerAnchorManager(_sceneRenderer);
  }

  web.HTMLElement? get _container {
    // Prefer the static registry (works even inside shadow DOM).
    final registered = AugenWebPlugin.viewRegistry[viewId];
    if (registered != null) return registered;
    // Fallback: DOM lookup.
    final el = web.document.getElementById('augen_ar_view_$viewId');
    return el as web.HTMLElement?;
  }

  static Never _unsupportedWeb(String feature) {
    throw UnsupportedError('$feature is not yet supported on web.');
  }

  // ===== Generic fallback =====

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    // Dispatch to typed implementations where possible, so callers using
    // the generic invokeMethod path still reach real web implementations.
    switch (method) {
      // Lifecycle
      case 'initialize':
        await initialize(Map<String, dynamic>.from(arguments as Map));
        return null;
      case 'isARSupported':
        return await isARSupported() as T;
      case 'pause':
        await pause();
        return null;
      case 'resume':
        await resume();
        return null;
      case 'reset':
        await reset();
        return null;

      // Nodes
      case 'addNode':
        await addNode(Map<String, dynamic>.from(arguments as Map));
        return null;
      case 'removeNode':
        final args = arguments as Map;
        await removeNode(args['nodeId'] as String);
        return null;
      case 'updateNode':
        await updateNode(Map<String, dynamic>.from(arguments as Map));
        return null;

      // Marker tracking
      case 'addMarkerTarget':
        await addMarkerTarget(Map<String, dynamic>.from(arguments as Map));
        return null;
      case 'removeMarkerTarget':
        final args = arguments as Map;
        await removeMarkerTarget(args['targetId'] as String? ?? args['id'] as String);
        return null;
      case 'getMarkerTargets':
        return await getMarkerTargets() as T;
      case 'setMarkerTrackingEnabled':
        final args = arguments as Map;
        await setMarkerTrackingEnabled(args['enabled'] as bool);
        return null;
      case 'isMarkerTrackingEnabled':
        return await isMarkerTrackingEnabled() as T;
      case 'getTrackedMarkers':
        return await getTrackedMarkers() as T;
      case 'setMarkerDetectionOptions':
        await setMarkerDetectionOptions(Map<String, dynamic>.from(arguments as Map));
        return null;
      case 'addNodeToTrackedMarker':
        await addNodeToTrackedMarker(Map<String, dynamic>.from(arguments as Map));
        return null;
      case 'removeNodeFromTrackedMarker':
        final args = arguments as Map;
        await removeNodeFromTrackedMarker(args['nodeId'] as String);
        return null;

      default:
        _unsupportedWeb(method);
    }
  }

  // ===== Lifecycle =====

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (_initialized) return;
    if (_disposed) throw StateError('Web backend is disposed');
    final container = _container;
    if (container == null) {
      throw StateError('AR view container not found for viewId: $viewId');
    }

    // Load bridge JS (may already be loaded via index.html)
    try {
      await _assetLoader.loadBridgeScript();
    } catch (e) {
      onPlatformCallback?.call('onError', 'Bridge script: $e');
    }

    // Start camera — catch errors so detector/renderer can still init
    bool cameraOk = false;
    try {
      await _camera.start(container: container);
      cameraOk = true;
    } catch (e) {
      // Surface the error through the platform callback so the UI can show it
      onPlatformCallback?.call('onError', 'Camera: $e');
    }

    // Initialize detector and renderer (independent of camera success)
    try {
      await _markerDetector.initialize();
    } catch (e) {
      onPlatformCallback?.call('onError', 'Detector: $e');
    }

    try {
      await _sceneRenderer.initialize(container: container);
    } catch (e) {
      onPlatformCallback?.call('onError', 'Renderer: $e');
    }

    // Set up stream subscription BEFORE starting detection loop (B6)
    _markerSub = _markerDetector.trackedMarkersStream.listen((markers) {
      _anchorManager.updateTrackedMarkers(markers);
      _sceneRenderer.render();
      // W14: Pass typed objects directly. The controller has a fast-path
      // for List<ARTrackedMarker> that skips the toMap/fromMap round-trip.
      onPlatformCallback?.call('onTrackedMarkersUpdated', markers);
    });

    // BUG-1: Subscribe to detector error stream
    _errorSub = _markerDetector.errorStream.listen((e) {
      onPlatformCallback?.call('onError', 'Detector: $e');
    });

    // Start detection loop after subscription is ready
    if (cameraOk && _camera.videoElement != null) {
      _markerDetector.startDetectionLoop(_camera.videoElement!);
    }

    // B2: Auto-enable marker tracking if config requests it
    if (config['markerTracking'] == true) {
      _markerDetector.setEnabled(true);
    }

    // Gate _initialized on detector success
    if (!_markerDetector.isInitialized) return;
    _initialized = true;
  }

  @override
  Future<bool> isARSupported() async {
    // Web AR is supported if getUserMedia is available
    try {
      web.window.navigator.mediaDevices.getSupportedConstraints();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _markerDetector.stopDetectionLoop();
    _camera.videoElement?.pause();
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    if (_camera.videoElement != null) {
      _camera.videoElement!.play();
      _markerDetector.startDetectionLoop(_camera.videoElement!);
    }
  }

  @override
  Future<void> reset() async {
    final wasEnabled = _markerDetector.isEnabled;
    _markerDetector.stopDetectionLoop();
    _markerDetector.setEnabled(false);
    if (_camera.videoElement != null) {
      _markerDetector.startDetectionLoop(_camera.videoElement!);
      _markerDetector.setEnabled(wasEnabled);
    }
  }

  // ===== Nodes =====

  @override
  Future<void> addNode(Map<String, dynamic> nodeData) async {
    _sceneRenderer.addNode(nodeData);
  }

  @override
  Future<void> removeNode(String id) async {
    _sceneRenderer.removeNode(id);
  }

  @override
  Future<void> updateNode(Map<String, dynamic> nodeData) async {
    _sceneRenderer.updateNode(nodeData);
  }

  // ===== Hit testing =====

  @override
  Future<List<Map<String, dynamic>>> hitTest(double x, double y) async =>
      _unsupportedWeb('hitTest');

  // ===== Anchors =====

  @override
  Future<Map<String, dynamic>?> addAnchor(
          Map<String, dynamic> position) async =>
      _unsupportedWeb('addAnchor');

  @override
  Future<void> removeAnchor(String id) async =>
      _unsupportedWeb('removeAnchor');

  // ===== Image tracking =====

  @override
  Future<void> addImageTarget(Map<String, dynamic> target) async =>
      _unsupportedWeb('addImageTarget');

  @override
  Future<void> removeImageTarget(String id) async =>
      _unsupportedWeb('removeImageTarget');

  @override
  Future<List<Map<String, dynamic>>> getImageTargets() async =>
      _unsupportedWeb('getImageTargets');

  @override
  Future<List<Map<String, dynamic>>> getTrackedImages() async =>
      _unsupportedWeb('getTrackedImages');

  @override
  Future<void> setImageTrackingEnabled(bool enabled) async =>
      _unsupportedWeb('setImageTrackingEnabled');

  @override
  Future<bool> isImageTrackingEnabled() async =>
      _unsupportedWeb('isImageTrackingEnabled');

  @override
  Future<void> addNodeToTrackedImage(Map<String, dynamic> args) async =>
      _unsupportedWeb('addNodeToTrackedImage');

  @override
  Future<void> removeNodeFromTrackedImage(String nodeId) async =>
      _unsupportedWeb('removeNodeFromTrackedImage');

  // ===== Marker tracking =====

  @override
  Future<void> addMarkerTarget(Map<String, dynamic> target) async {
    final markerTarget = _buildMarkerTarget(target);
    _markerDetector.addTarget(markerTarget);
  }

  @override
  Future<void> removeMarkerTarget(String id) async {
    _markerDetector.removeTarget(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getMarkerTargets() async {
    return _markerDetector.getTargets().map((t) => t.toMap()).toList();
  }

  @override
  Future<void> setMarkerTrackingEnabled(bool enabled) async {
    _markerDetector.setEnabled(enabled);
  }

  @override
  Future<bool> isMarkerTrackingEnabled() async {
    return _markerDetector.isEnabled;
  }

  @override
  Future<List<Map<String, dynamic>>> getTrackedMarkers() async {
    // Return empty; real-time tracking is via stream
    return [];
  }

  @override
  Future<void> setMarkerDetectionOptions(
          Map<String, dynamic> options) async {
    _markerDetector.setOptions(ARMarkerDetectionOptions.fromMap(options));
  }

  @override
  Future<void> addNodeToTrackedMarker(Map<String, dynamic> args) async {
    final nodeId = args['nodeId'] as String;
    final markerId = args['markerId'] as String;
    _anchorManager.attachNodeToMarker(nodeId, markerId);
  }

  @override
  Future<void> removeNodeFromTrackedMarker(String nodeId) async {
    _anchorManager.detachNode(nodeId);
  }

  // ===== Animation =====

  @override
  Future<void> playAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('playAnimation');

  @override
  Future<void> pauseAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('pauseAnimation');

  @override
  Future<void> stopAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('stopAnimation');

  @override
  Future<void> resumeAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('resumeAnimation');

  @override
  Future<void> seekAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('seekAnimation');

  @override
  Future<void> setAnimationSpeed(Map<String, dynamic> args) async =>
      _unsupportedWeb('setAnimationSpeed');

  @override
  Future<List<String>> getAvailableAnimations(String nodeId) async =>
      _unsupportedWeb('getAvailableAnimations');

  // ===== Animation blending =====

  @override
  Future<void> playBlendSet(Map<String, dynamic> args) async =>
      _unsupportedWeb('playBlendSet');

  @override
  Future<void> stopBlendSet(Map<String, dynamic> args) async =>
      _unsupportedWeb('stopBlendSet');

  @override
  Future<void> updateBlendWeights(Map<String, dynamic> args) async =>
      _unsupportedWeb('updateBlendWeights');

  @override
  Future<void> startCrossfadeTransition(Map<String, dynamic> args) async =>
      _unsupportedWeb('startCrossfadeTransition');

  @override
  Future<void> stopTransition(Map<String, dynamic> args) async =>
      _unsupportedWeb('stopTransition');

  @override
  Future<void> startStateMachine(Map<String, dynamic> args) async =>
      _unsupportedWeb('startStateMachine');

  @override
  Future<void> stopStateMachine(Map<String, dynamic> args) async =>
      _unsupportedWeb('stopStateMachine');

  @override
  Future<void> updateStateMachineParameters(
          Map<String, dynamic> args) async =>
      _unsupportedWeb('updateStateMachineParameters');

  @override
  Future<void> triggerStateMachineTransition(
          Map<String, dynamic> args) async =>
      _unsupportedWeb('triggerStateMachineTransition');

  @override
  Future<void> startBlendTree(Map<String, dynamic> args) async =>
      _unsupportedWeb('startBlendTree');

  @override
  Future<void> stopBlendTree(Map<String, dynamic> args) async =>
      _unsupportedWeb('stopBlendTree');

  @override
  Future<void> updateBlendTreeParameters(
          Map<String, dynamic> args) async =>
      _unsupportedWeb('updateBlendTreeParameters');

  @override
  Future<void> setAnimationLayerWeight(Map<String, dynamic> args) async =>
      _unsupportedWeb('setAnimationLayerWeight');

  @override
  Future<List<Map<String, dynamic>>> getAnimationLayers(
          String nodeId) async =>
      _unsupportedWeb('getAnimationLayers');

  @override
  Future<void> playAdditiveAnimation(Map<String, dynamic> args) async =>
      _unsupportedWeb('playAdditiveAnimation');

  @override
  Future<void> setAnimationBoneMask(Map<String, dynamic> args) async =>
      _unsupportedWeb('setAnimationBoneMask');

  @override
  Future<List<String>> getBoneHierarchy(String nodeId) async =>
      _unsupportedWeb('getBoneHierarchy');

  // ===== Face tracking =====

  @override
  Future<void> setFaceTrackingEnabled(bool enabled) async =>
      _unsupportedWeb('setFaceTrackingEnabled');

  @override
  Future<bool> isFaceTrackingEnabled() async =>
      _unsupportedWeb('isFaceTrackingEnabled');

  @override
  Future<List<Map<String, dynamic>>> getTrackedFaces() async =>
      _unsupportedWeb('getTrackedFaces');

  @override
  Future<void> addNodeToTrackedFace(Map<String, dynamic> args) async =>
      _unsupportedWeb('addNodeToTrackedFace');

  @override
  Future<void> removeNodeFromTrackedFace(Map<String, dynamic> args) async =>
      _unsupportedWeb('removeNodeFromTrackedFace');

  @override
  Future<List<Map<String, dynamic>>> getFaceLandmarks(
          String faceId) async =>
      _unsupportedWeb('getFaceLandmarks');

  @override
  Future<void> setFaceTrackingConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setFaceTrackingConfig');

  // ===== Cloud anchors =====

  @override
  Future<String> createCloudAnchor(String localAnchorId) async =>
      _unsupportedWeb('createCloudAnchor');

  @override
  Future<void> resolveCloudAnchor(String cloudAnchorId) async =>
      _unsupportedWeb('resolveCloudAnchor');

  @override
  Future<List<Map<String, dynamic>>> getCloudAnchors() async =>
      _unsupportedWeb('getCloudAnchors');

  @override
  Future<Map<String, dynamic>?> getCloudAnchor(
          String cloudAnchorId) async =>
      _unsupportedWeb('getCloudAnchor');

  @override
  Future<void> deleteCloudAnchor(String cloudAnchorId) async =>
      _unsupportedWeb('deleteCloudAnchor');

  @override
  Future<bool> isCloudAnchorsSupported() async =>
      _unsupportedWeb('isCloudAnchorsSupported');

  @override
  Future<void> setCloudAnchorConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setCloudAnchorConfig');

  @override
  Future<String> shareCloudAnchor(String cloudAnchorId) async =>
      _unsupportedWeb('shareCloudAnchor');

  @override
  Future<void> joinCloudAnchorSession(String sessionId) async =>
      _unsupportedWeb('joinCloudAnchorSession');

  @override
  Future<void> leaveCloudAnchorSession() async =>
      _unsupportedWeb('leaveCloudAnchorSession');

  // ===== Occlusion =====

  @override
  Future<void> setOcclusionEnabled(bool enabled) async =>
      _unsupportedWeb('setOcclusionEnabled');

  @override
  Future<bool> isOcclusionEnabled() async =>
      _unsupportedWeb('isOcclusionEnabled');

  @override
  Future<void> setOcclusionConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setOcclusionConfig');

  @override
  Future<List<Map<String, dynamic>>> getOcclusions() async =>
      _unsupportedWeb('getOcclusions');

  @override
  Future<Map<String, dynamic>?> getOcclusion(String occlusionId) async =>
      _unsupportedWeb('getOcclusion');

  @override
  Future<String> createOcclusion(Map<String, dynamic> args) async =>
      _unsupportedWeb('createOcclusion');

  @override
  Future<void> updateOcclusion(Map<String, dynamic> args) async =>
      _unsupportedWeb('updateOcclusion');

  @override
  Future<void> removeOcclusion(String occlusionId) async =>
      _unsupportedWeb('removeOcclusion');

  // ===== Physics =====

  @override
  Future<void> setPhysicsEnabled(bool enabled) async =>
      _unsupportedWeb('setPhysicsEnabled');

  @override
  Future<bool> isPhysicsEnabled() async =>
      _unsupportedWeb('isPhysicsEnabled');

  @override
  Future<void> setPhysicsConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setPhysicsConfig');

  @override
  Future<String> addPhysicsBody(Map<String, dynamic> args) async =>
      _unsupportedWeb('addPhysicsBody');

  @override
  Future<void> removePhysicsBody(String bodyId) async =>
      _unsupportedWeb('removePhysicsBody');

  @override
  Future<void> updatePhysicsBody(Map<String, dynamic> args) async =>
      _unsupportedWeb('updatePhysicsBody');

  @override
  Future<List<Map<String, dynamic>>> getPhysicsBodies() async =>
      _unsupportedWeb('getPhysicsBodies');

  @override
  Future<Map<String, dynamic>?> getPhysicsBody(String bodyId) async =>
      _unsupportedWeb('getPhysicsBody');

  @override
  Future<void> applyForce(Map<String, dynamic> args) async =>
      _unsupportedWeb('applyForce');

  @override
  Future<void> applyImpulse(Map<String, dynamic> args) async =>
      _unsupportedWeb('applyImpulse');

  @override
  Future<void> applyTorque(Map<String, dynamic> args) async =>
      _unsupportedWeb('applyTorque');

  @override
  Future<String> addPhysicsConstraint(Map<String, dynamic> args) async =>
      _unsupportedWeb('addPhysicsConstraint');

  @override
  Future<void> removePhysicsConstraint(String constraintId) async =>
      _unsupportedWeb('removePhysicsConstraint');

  @override
  Future<List<Map<String, dynamic>>> getPhysicsConstraints() async =>
      _unsupportedWeb('getPhysicsConstraints');

  @override
  Future<List<Map<String, dynamic>>> raycast(
          Map<String, dynamic> args) async =>
      _unsupportedWeb('raycast');

  // ===== Multi-user =====

  @override
  Future<void> createMultiUserSession(Map<String, dynamic> config) async =>
      _unsupportedWeb('createMultiUserSession');

  @override
  Future<void> joinMultiUserSession(String sessionId, {String? displayName, String? password}) async =>
      _unsupportedWeb('joinMultiUserSession');

  @override
  Future<void> leaveMultiUserSession() async =>
      _unsupportedWeb('leaveMultiUserSession');

  @override
  Future<Map<String, dynamic>?> getMultiUserSession() async =>
      _unsupportedWeb('getMultiUserSession');

  @override
  Future<List<Map<String, dynamic>>> getMultiUserParticipants() async =>
      _unsupportedWeb('getMultiUserParticipants');

  @override
  Future<void> shareObject(Map<String, dynamic> args) async =>
      _unsupportedWeb('shareObject');

  @override
  Future<void> unshareObject(String objectId) async =>
      _unsupportedWeb('unshareObject');

  @override
  Future<List<Map<String, dynamic>>> getSharedObjects() async =>
      _unsupportedWeb('getSharedObjects');

  @override
  Future<void> sendMultiUserMessage(Map<String, dynamic> args) async =>
      _unsupportedWeb('sendMultiUserMessage');

  @override
  Future<void> setMultiUserConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setMultiUserConfig');

  // ===== Lighting =====

  @override
  Future<void> setLightingEnabled(bool enabled) async =>
      _unsupportedWeb('setLightingEnabled');

  @override
  Future<bool> isLightingEnabled() async =>
      _unsupportedWeb('isLightingEnabled');

  @override
  Future<void> setLightingConfig(Map<String, dynamic> config) async =>
      _unsupportedWeb('setLightingConfig');

  @override
  Future<Map<String, dynamic>?> getLightingConfig() async =>
      _unsupportedWeb('getLightingConfig');

  @override
  Future<dynamic> addLight(Map<String, dynamic> args) async =>
      _unsupportedWeb('addLight');

  @override
  Future<void> removeLight(String lightId) async =>
      _unsupportedWeb('removeLight');

  @override
  Future<void> updateLight(Map<String, dynamic> args) async =>
      _unsupportedWeb('updateLight');

  @override
  Future<List<Map<String, dynamic>>> getLights() async =>
      _unsupportedWeb('getLights');

  @override
  Future<Map<String, dynamic>?> getLight(String lightId) async =>
      _unsupportedWeb('getLight');

  @override
  Future<void> setAmbientLight(Map<String, dynamic> args) async =>
      _unsupportedWeb('setAmbientLight');

  @override
  Future<Map<String, dynamic>?> getAmbientLight() async =>
      _unsupportedWeb('getAmbientLight');

  @override
  Future<void> setEnvironmentMap(Map<String, dynamic> args) async =>
      _unsupportedWeb('setEnvironmentMap');

  @override
  Future<Map<String, dynamic>?> getEnvironmentMap() async =>
      _unsupportedWeb('getEnvironmentMap');

  // ===== Environmental probes =====

  @override
  Future<void> setEnvironmentalProbesEnabled(bool enabled) async =>
      _unsupportedWeb('setEnvironmentalProbesEnabled');

  @override
  Future<bool> isEnvironmentalProbesEnabled() async =>
      _unsupportedWeb('isEnvironmentalProbesEnabled');

  @override
  Future<void> setEnvironmentalProbeConfig(
          Map<String, dynamic> config) async =>
      _unsupportedWeb('setEnvironmentalProbeConfig');

  @override
  Future<Map<String, dynamic>?> getEnvironmentalProbeConfig() async =>
      _unsupportedWeb('getEnvironmentalProbeConfig');

  @override
  Future<dynamic> addEnvironmentalProbe(Map<String, dynamic> args) async =>
      _unsupportedWeb('addEnvironmentalProbe');

  @override
  Future<void> removeEnvironmentalProbe(String probeId) async =>
      _unsupportedWeb('removeEnvironmentalProbe');

  @override
  Future<void> updateEnvironmentalProbe(Map<String, dynamic> args) async =>
      _unsupportedWeb('updateEnvironmentalProbe');

  @override
  Future<List<Map<String, dynamic>>> getEnvironmentalProbes() async =>
      _unsupportedWeb('getEnvironmentalProbes');

  @override
  Future<Map<String, dynamic>?> getEnvironmentalProbe(
          String probeId) async =>
      _unsupportedWeb('getEnvironmentalProbe');

  @override
  Future<void> forceEnvironmentalProbeUpdate(String probeId) async =>
      _unsupportedWeb('forceEnvironmentalProbeUpdate');

  @override
  Future<void> clearEnvironmentalProbes() async =>
      _unsupportedWeb('clearEnvironmentalProbes');

  // ===== Dispose =====

  @override
  void dispose() {
    _disposed = true;
    _markerSub?.cancel();
    _errorSub?.cancel();
    AugenWebPlugin.viewRegistry.remove(viewId);
    _markerDetector.dispose();
    _sceneRenderer.dispose();
    _anchorManager.dispose();
    _camera.dispose();
  }

  // ===== Helpers =====

  ARMarkerTarget _buildMarkerTarget(Map<String, dynamic> map) {
    return ARMarkerTarget.fromMap(map);
  }
}
