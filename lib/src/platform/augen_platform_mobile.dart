import 'package:flutter/services.dart';

import 'augen_platform_backend.dart';

/// Mobile implementation wrapping MethodChannel.
class AugenPlatformMobile extends AugenPlatformBackend {
  final MethodChannel _channel;

  AugenPlatformMobile(int viewId)
      : _channel = MethodChannel('augen_$viewId') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    onPlatformCallback?.call(call.method, call.arguments);
  }

  // ===== Generic fallback =====

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  // ===== Lifecycle =====

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    await _channel.invokeMethod('initialize', config);
  }

  @override
  Future<bool> isARSupported() async {
    final result = await _channel.invokeMethod<bool>('isARSupported');
    return result ?? false;
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  @override
  Future<void> resume() async {
    await _channel.invokeMethod('resume');
  }

  @override
  Future<void> reset() async {
    await _channel.invokeMethod('reset');
  }

  // ===== Nodes =====

  @override
  Future<void> addNode(Map<String, dynamic> nodeData) async {
    await _channel.invokeMethod('addNode', nodeData);
  }

  @override
  Future<void> removeNode(String id) async {
    await _channel.invokeMethod('removeNode', {'nodeId': id});
  }

  @override
  Future<void> updateNode(Map<String, dynamic> nodeData) async {
    await _channel.invokeMethod('updateNode', nodeData);
  }

  // ===== Hit testing =====

  @override
  Future<List<Map<String, dynamic>>> hitTest(double x, double y) async {
    final result = await _channel.invokeMethod<List>('hitTest', {
      'x': x,
      'y': y,
    });
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  // ===== Anchors =====

  @override
  Future<Map<String, dynamic>?> addAnchor(
      Map<String, dynamic> position) async {
    final result = await _channel.invokeMethod<Map>('addAnchor', position);
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  @override
  Future<void> removeAnchor(String id) async {
    await _channel.invokeMethod('removeAnchor', {'anchorId': id});
  }

  // ===== Image tracking =====

  @override
  Future<void> addImageTarget(Map<String, dynamic> target) async {
    await _channel.invokeMethod('addImageTarget', target);
  }

  @override
  Future<void> removeImageTarget(String id) async {
    await _channel.invokeMethod('removeImageTarget', {'targetId': id});
  }

  @override
  Future<List<Map<String, dynamic>>> getImageTargets() async {
    final result = await _channel.invokeMethod<List>('getImageTargets');
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTrackedImages() async {
    final result = await _channel.invokeMethod<List>('getTrackedImages');
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  @override
  Future<void> setImageTrackingEnabled(bool enabled) async {
    await _channel
        .invokeMethod('setImageTrackingEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isImageTrackingEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('isImageTrackingEnabled');
    return result ?? false;
  }

  @override
  Future<void> addNodeToTrackedImage(Map<String, dynamic> args) async {
    await _channel.invokeMethod('addNodeToTrackedImage', args);
  }

  @override
  Future<void> removeNodeFromTrackedImage(String nodeId) async {
    await _channel
        .invokeMethod('removeNodeFromTrackedImage', {'nodeId': nodeId});
  }

  // ===== Marker tracking (unsupported on mobile) =====

  static Never _unsupportedMarker() {
    throw UnsupportedError(
      'Marker tracking is not supported on this platform. '
      'Use image tracking instead, or run on web.',
    );
  }

  @override
  Future<void> addMarkerTarget(Map<String, dynamic> target) async =>
      _unsupportedMarker();

  @override
  Future<void> removeMarkerTarget(String id) async => _unsupportedMarker();

  @override
  Future<List<Map<String, dynamic>>> getMarkerTargets() async =>
      _unsupportedMarker();

  @override
  Future<void> setMarkerTrackingEnabled(bool enabled) async =>
      _unsupportedMarker();

  @override
  Future<bool> isMarkerTrackingEnabled() async => _unsupportedMarker();

  @override
  Future<List<Map<String, dynamic>>> getTrackedMarkers() async =>
      _unsupportedMarker();

  @override
  Future<void> setMarkerDetectionOptions(Map<String, dynamic> options) async =>
      _unsupportedMarker();

  @override
  Future<void> addNodeToTrackedMarker(Map<String, dynamic> args) async =>
      _unsupportedMarker();

  @override
  Future<void> removeNodeFromTrackedMarker(String nodeId) async =>
      _unsupportedMarker();

  // ===== Animation =====

  @override
  Future<void> playAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('playAnimation', args);
  }

  @override
  Future<void> pauseAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('pauseAnimation', args);
  }

  @override
  Future<void> stopAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('stopAnimation', args);
  }

  @override
  Future<void> resumeAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('resumeAnimation', args);
  }

  @override
  Future<void> seekAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('seekAnimation', args);
  }

  @override
  Future<void> setAnimationSpeed(Map<String, dynamic> args) async {
    await _channel.invokeMethod('setAnimationSpeed', args);
  }

  @override
  Future<List<String>> getAvailableAnimations(String nodeId) async {
    final result = await _channel.invokeMethod<List>(
      'getAvailableAnimations',
      {'nodeId': nodeId},
    );
    return result?.cast<String>() ?? [];
  }

  // ===== Animation blending =====

  @override
  Future<void> playBlendSet(Map<String, dynamic> args) async {
    await _channel.invokeMethod('playBlendSet', args);
  }

  @override
  Future<void> stopBlendSet(Map<String, dynamic> args) async {
    await _channel.invokeMethod('stopBlendSet', args);
  }

  @override
  Future<void> updateBlendWeights(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateBlendWeights', args);
  }

  @override
  Future<void> startCrossfadeTransition(Map<String, dynamic> args) async {
    await _channel.invokeMethod('startCrossfadeTransition', args);
  }

  @override
  Future<void> stopTransition(Map<String, dynamic> args) async {
    await _channel.invokeMethod('stopTransition', args);
  }

  @override
  Future<void> startStateMachine(Map<String, dynamic> args) async {
    await _channel.invokeMethod('startStateMachine', args);
  }

  @override
  Future<void> stopStateMachine(Map<String, dynamic> args) async {
    await _channel.invokeMethod('stopStateMachine', args);
  }

  @override
  Future<void> updateStateMachineParameters(
      Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateStateMachineParameters', args);
  }

  @override
  Future<void> triggerStateMachineTransition(
      Map<String, dynamic> args) async {
    await _channel.invokeMethod('triggerStateMachineTransition', args);
  }

  @override
  Future<void> startBlendTree(Map<String, dynamic> args) async {
    await _channel.invokeMethod('startBlendTree', args);
  }

  @override
  Future<void> stopBlendTree(Map<String, dynamic> args) async {
    await _channel.invokeMethod('stopBlendTree', args);
  }

  @override
  Future<void> updateBlendTreeParameters(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateBlendTreeParameters', args);
  }

  @override
  Future<void> setAnimationLayerWeight(Map<String, dynamic> args) async {
    await _channel.invokeMethod('setAnimationLayerWeight', args);
  }

  @override
  Future<List<Map<String, dynamic>>> getAnimationLayers(
      String nodeId) async {
    final result = await _channel.invokeMethod<List>('getAnimationLayers', {
      'nodeId': nodeId,
    });
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  @override
  Future<void> playAdditiveAnimation(Map<String, dynamic> args) async {
    await _channel.invokeMethod('playAdditiveAnimation', args);
  }

  @override
  Future<void> setAnimationBoneMask(Map<String, dynamic> args) async {
    await _channel.invokeMethod('setAnimationBoneMask', args);
  }

  @override
  Future<List<String>> getBoneHierarchy(String nodeId) async {
    final result = await _channel.invokeMethod<List>('getBoneHierarchy', {
      'nodeId': nodeId,
    });
    return result?.cast<String>() ?? [];
  }

  // ===== Face tracking =====

  @override
  Future<void> setFaceTrackingEnabled(bool enabled) async {
    await _channel
        .invokeMethod('setFaceTrackingEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isFaceTrackingEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('isFaceTrackingEnabled');
    return result ?? false;
  }

  @override
  Future<List<Map<String, dynamic>>> getTrackedFaces() async {
    final result = await _channel.invokeMethod<List>('getTrackedFaces');
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  @override
  Future<void> addNodeToTrackedFace(Map<String, dynamic> args) async {
    await _channel.invokeMethod('addNodeToTrackedFace', args);
  }

  @override
  Future<void> removeNodeFromTrackedFace(Map<String, dynamic> args) async {
    await _channel.invokeMethod('removeNodeFromTrackedFace', args);
  }

  @override
  Future<List<Map<String, dynamic>>> getFaceLandmarks(String faceId) async {
    final result = await _channel.invokeMethod<List>('getFaceLandmarks', {
      'faceId': faceId,
    });
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  @override
  Future<void> setFaceTrackingConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setFaceTrackingConfig', config);
  }

  // ===== Cloud anchors =====

  @override
  Future<String> createCloudAnchor(String localAnchorId) async {
    final result = await _channel.invokeMethod('createCloudAnchor', {
      'localAnchorId': localAnchorId,
    });
    return result as String;
  }

  @override
  Future<void> resolveCloudAnchor(String cloudAnchorId) async {
    await _channel.invokeMethod('resolveCloudAnchor', {
      'cloudAnchorId': cloudAnchorId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getCloudAnchors() async {
    final result = await _channel.invokeMethod('getCloudAnchors');
    final anchorsData = result as List;
    return anchorsData
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getCloudAnchor(
      String cloudAnchorId) async {
    final result = await _channel.invokeMethod('getCloudAnchor', {
      'cloudAnchorId': cloudAnchorId,
    });
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> deleteCloudAnchor(String cloudAnchorId) async {
    await _channel.invokeMethod('deleteCloudAnchor', {
      'cloudAnchorId': cloudAnchorId,
    });
  }

  @override
  Future<bool> isCloudAnchorsSupported() async {
    final result = await _channel.invokeMethod('isCloudAnchorsSupported');
    return result as bool;
  }

  @override
  Future<void> setCloudAnchorConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setCloudAnchorConfig', config);
  }

  @override
  Future<String> shareCloudAnchor(String cloudAnchorId) async {
    final result = await _channel.invokeMethod('shareCloudAnchor', {
      'cloudAnchorId': cloudAnchorId,
    });
    return result as String;
  }

  @override
  Future<void> joinCloudAnchorSession(String sessionId) async {
    await _channel.invokeMethod('joinCloudAnchorSession', {
      'sessionId': sessionId,
    });
  }

  @override
  Future<void> leaveCloudAnchorSession() async {
    await _channel.invokeMethod('leaveCloudAnchorSession');
  }

  // ===== Occlusion =====

  @override
  Future<void> setOcclusionEnabled(bool enabled) async {
    await _channel
        .invokeMethod('setOcclusionEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isOcclusionEnabled() async {
    final result = await _channel.invokeMethod('isOcclusionEnabled');
    return result as bool;
  }

  @override
  Future<void> setOcclusionConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setOcclusionConfig', config);
  }

  @override
  Future<List<Map<String, dynamic>>> getOcclusions() async {
    final result = await _channel.invokeMethod('getOcclusions');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getOcclusion(String occlusionId) async {
    final result = await _channel.invokeMethod('getOcclusion', {
      'occlusionId': occlusionId,
    });
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<String> createOcclusion(Map<String, dynamic> args) async {
    final result = await _channel.invokeMethod('createOcclusion', args);
    return result as String;
  }

  @override
  Future<void> updateOcclusion(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateOcclusion', args);
  }

  @override
  Future<void> removeOcclusion(String occlusionId) async {
    await _channel.invokeMethod('removeOcclusion', {
      'occlusionId': occlusionId,
    });
  }

  // ===== Physics =====

  @override
  Future<void> setPhysicsEnabled(bool enabled) async {
    await _channel
        .invokeMethod('setPhysicsEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isPhysicsEnabled() async {
    final result = await _channel.invokeMethod('isPhysicsEnabled');
    return result as bool;
  }

  @override
  Future<void> setPhysicsConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setPhysicsConfig', config);
  }

  @override
  Future<String> addPhysicsBody(Map<String, dynamic> args) async {
    final result = await _channel.invokeMethod('createPhysicsBody', args);
    return result as String? ?? '';
  }

  @override
  Future<void> removePhysicsBody(String bodyId) async {
    await _channel.invokeMethod('removePhysicsBody', {'bodyId': bodyId});
  }

  @override
  Future<void> updatePhysicsBody(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updatePhysicsBody', args);
  }

  @override
  Future<List<Map<String, dynamic>>> getPhysicsBodies() async {
    final result = await _channel.invokeMethod('getPhysicsBodies');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getPhysicsBody(String bodyId) async {
    final result = await _channel.invokeMethod('getPhysicsBody', {
      'bodyId': bodyId,
    });
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> applyForce(Map<String, dynamic> args) async {
    await _channel.invokeMethod('applyForce', args);
  }

  @override
  Future<void> applyImpulse(Map<String, dynamic> args) async {
    await _channel.invokeMethod('applyImpulse', args);
  }

  @override
  Future<void> applyTorque(Map<String, dynamic> args) async {
    await _channel.invokeMethod('applyTorque', args);
  }

  @override
  Future<String> addPhysicsConstraint(Map<String, dynamic> args) async {
    final result =
        await _channel.invokeMethod('createPhysicsConstraint', args);
    return result as String? ?? '';
  }

  @override
  Future<void> removePhysicsConstraint(String constraintId) async {
    await _channel.invokeMethod('removePhysicsConstraint', {
      'constraintId': constraintId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPhysicsConstraints() async {
    final result = await _channel.invokeMethod('getPhysicsConstraints');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> raycast(
      Map<String, dynamic> args) async {
    final result = await _channel.invokeMethod<List>('raycast', args);
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  // ===== Multi-user =====

  @override
  Future<void> createMultiUserSession(Map<String, dynamic> config) async {
    await _channel.invokeMethod('createMultiUserSession', config);
  }

  @override
  Future<void> joinMultiUserSession(String sessionId, {String? displayName, String? password}) async {
    await _channel.invokeMethod('joinMultiUserSession', {
      'sessionId': sessionId,
      if (displayName != null) 'displayName': displayName,
      if (password != null) 'password': password,
    });
  }

  @override
  Future<void> leaveMultiUserSession() async {
    await _channel.invokeMethod('leaveMultiUserSession');
  }

  @override
  Future<Map<String, dynamic>?> getMultiUserSession() async {
    final result = await _channel.invokeMethod('getMultiUserSession');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> getMultiUserParticipants() async {
    final result =
        await _channel.invokeMethod('getMultiUserParticipants');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> shareObject(Map<String, dynamic> args) async {
    await _channel.invokeMethod('shareObject', args);
  }

  @override
  Future<void> unshareObject(String objectId) async {
    await _channel.invokeMethod('unshareObject', {'objectId': objectId});
  }

  @override
  Future<List<Map<String, dynamic>>> getSharedObjects() async {
    final result = await _channel.invokeMethod('getSharedObjects');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> sendMultiUserMessage(Map<String, dynamic> args) async {
    await _channel.invokeMethod('sendMultiUserMessage', args);
  }

  @override
  Future<void> setMultiUserConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setMultiUserConfig', config);
  }

  // ===== Lighting =====

  @override
  Future<void> setLightingEnabled(bool enabled) async {
    await _channel
        .invokeMethod('setLightingEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isLightingEnabled() async {
    final result = await _channel.invokeMethod('isLightingEnabled');
    return result as bool;
  }

  @override
  Future<void> setLightingConfig(Map<String, dynamic> config) async {
    await _channel.invokeMethod('setLightingConfig', config);
  }

  @override
  Future<Map<String, dynamic>?> getLightingConfig() async {
    final result = await _channel.invokeMethod('getLightingConfig');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<dynamic> addLight(Map<String, dynamic> args) async {
    final result = await _channel.invokeMethod('addLight', args);
    return result;
  }

  @override
  Future<void> removeLight(String lightId) async {
    await _channel.invokeMethod('removeLight', {'lightId': lightId});
  }

  @override
  Future<void> updateLight(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateLight', args);
  }

  @override
  Future<List<Map<String, dynamic>>> getLights() async {
    final result = await _channel.invokeMethod('getLights');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getLight(String lightId) async {
    final result = await _channel.invokeMethod('getLight', {
      'lightId': lightId,
    });
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> setAmbientLight(Map<String, dynamic> args) async {
    await _channel.invokeMethod('setAmbientLight', args);
  }

  @override
  Future<Map<String, dynamic>?> getAmbientLight() async {
    final result = await _channel.invokeMethod('getAmbientLight');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> setEnvironmentMap(Map<String, dynamic> args) async {
    await _channel.invokeMethod('setEnvironmentMap', args);
  }

  @override
  Future<Map<String, dynamic>?> getEnvironmentMap() async {
    final result = await _channel.invokeMethod('getEnvironmentMap');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  // ===== Environmental probes =====

  @override
  Future<void> setEnvironmentalProbesEnabled(bool enabled) async {
    await _channel.invokeMethod(
        'setEnvironmentalProbesEnabled', {'enabled': enabled});
  }

  @override
  Future<bool> isEnvironmentalProbesEnabled() async {
    final result =
        await _channel.invokeMethod('isEnvironmentalProbesEnabled');
    return result as bool;
  }

  @override
  Future<void> setEnvironmentalProbeConfig(
      Map<String, dynamic> config) async {
    await _channel.invokeMethod('setEnvironmentalProbeConfig', config);
  }

  @override
  Future<Map<String, dynamic>?> getEnvironmentalProbeConfig() async {
    final result =
        await _channel.invokeMethod('getEnvironmentalProbeConfig');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<dynamic> addEnvironmentalProbe(Map<String, dynamic> args) async {
    final result =
        await _channel.invokeMethod('addEnvironmentalProbe', args);
    return result;
  }

  @override
  Future<void> removeEnvironmentalProbe(String probeId) async {
    await _channel.invokeMethod('removeEnvironmentalProbe', {
      'probeId': probeId,
    });
  }

  @override
  Future<void> updateEnvironmentalProbe(Map<String, dynamic> args) async {
    await _channel.invokeMethod('updateEnvironmentalProbe', args);
  }

  @override
  Future<List<Map<String, dynamic>>> getEnvironmentalProbes() async {
    final result = await _channel.invokeMethod('getEnvironmentalProbes');
    final data = result as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getEnvironmentalProbe(
      String probeId) async {
    final result = await _channel.invokeMethod('getEnvironmentalProbe', {
      'probeId': probeId,
    });
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<void> forceEnvironmentalProbeUpdate(String probeId) async {
    await _channel.invokeMethod('forceEnvironmentalProbeUpdate', {
      'probeId': probeId,
    });
  }

  @override
  Future<void> clearEnvironmentalProbes() async {
    await _channel.invokeMethod('clearEnvironmentalProbes');
  }

  // ===== Dispose =====

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
