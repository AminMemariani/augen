/// Abstract backend interface for platform-specific AR operations.
/// Mobile uses MethodChannel, Web uses JS interop.
abstract class AugenPlatformBackend {
  // Lifecycle
  Future<void> initialize(Map<String, dynamic> config);
  Future<bool> isARSupported();
  Future<void> pause();
  Future<void> resume();
  Future<void> reset();

  // Nodes
  Future<void> addNode(Map<String, dynamic> nodeData);
  Future<void> removeNode(String id);
  Future<void> updateNode(Map<String, dynamic> nodeData);

  // Hit testing
  Future<List<Map<String, dynamic>>> hitTest(double x, double y);

  // Anchors
  Future<Map<String, dynamic>?> addAnchor(Map<String, dynamic> position);
  Future<void> removeAnchor(String id);

  // Image tracking
  Future<void> addImageTarget(Map<String, dynamic> target);
  Future<void> removeImageTarget(String id);
  Future<List<Map<String, dynamic>>> getImageTargets();
  Future<List<Map<String, dynamic>>> getTrackedImages();
  Future<void> setImageTrackingEnabled(bool enabled);
  Future<bool> isImageTrackingEnabled();
  Future<void> addNodeToTrackedImage(Map<String, dynamic> args);
  Future<void> removeNodeFromTrackedImage(String nodeId);

  // Marker tracking (NEW)
  Future<void> addMarkerTarget(Map<String, dynamic> target);
  Future<void> removeMarkerTarget(String id);
  Future<List<Map<String, dynamic>>> getMarkerTargets();
  Future<void> setMarkerTrackingEnabled(bool enabled);
  Future<bool> isMarkerTrackingEnabled();
  Future<List<Map<String, dynamic>>> getTrackedMarkers();
  Future<void> setMarkerDetectionOptions(Map<String, dynamic> options);
  Future<void> addNodeToTrackedMarker(Map<String, dynamic> args);
  Future<void> removeNodeFromTrackedMarker(String nodeId);

  // Animation methods
  Future<void> playAnimation(Map<String, dynamic> args);
  Future<void> pauseAnimation(Map<String, dynamic> args);
  Future<void> stopAnimation(Map<String, dynamic> args);
  Future<void> resumeAnimation(Map<String, dynamic> args);
  Future<void> seekAnimation(Map<String, dynamic> args);
  Future<void> setAnimationSpeed(Map<String, dynamic> args);
  Future<List<String>> getAvailableAnimations(String nodeId);

  // Animation blending
  Future<void> playBlendSet(Map<String, dynamic> args);
  Future<void> stopBlendSet(Map<String, dynamic> args);
  Future<void> updateBlendWeights(Map<String, dynamic> args);
  Future<void> startCrossfadeTransition(Map<String, dynamic> args);
  Future<void> stopTransition(Map<String, dynamic> args);
  Future<void> startStateMachine(Map<String, dynamic> args);
  Future<void> stopStateMachine(Map<String, dynamic> args);
  Future<void> updateStateMachineParameters(Map<String, dynamic> args);
  Future<void> triggerStateMachineTransition(Map<String, dynamic> args);
  Future<void> startBlendTree(Map<String, dynamic> args);
  Future<void> stopBlendTree(Map<String, dynamic> args);
  Future<void> updateBlendTreeParameters(Map<String, dynamic> args);
  Future<void> setAnimationLayerWeight(Map<String, dynamic> args);
  Future<List<Map<String, dynamic>>> getAnimationLayers(String nodeId);
  Future<void> playAdditiveAnimation(Map<String, dynamic> args);
  Future<void> setAnimationBoneMask(Map<String, dynamic> args);
  Future<List<String>> getBoneHierarchy(String nodeId);

  // Face tracking
  Future<void> setFaceTrackingEnabled(bool enabled);
  Future<bool> isFaceTrackingEnabled();
  Future<List<Map<String, dynamic>>> getTrackedFaces();
  Future<void> addNodeToTrackedFace(Map<String, dynamic> args);
  Future<void> removeNodeFromTrackedFace(Map<String, dynamic> args);
  Future<List<Map<String, dynamic>>> getFaceLandmarks(String faceId);
  Future<void> setFaceTrackingConfig(Map<String, dynamic> config);

  // Cloud anchors
  Future<String> createCloudAnchor(String localAnchorId);
  Future<void> resolveCloudAnchor(String cloudAnchorId);
  Future<List<Map<String, dynamic>>> getCloudAnchors();
  Future<Map<String, dynamic>?> getCloudAnchor(String cloudAnchorId);
  Future<void> deleteCloudAnchor(String cloudAnchorId);
  Future<bool> isCloudAnchorsSupported();
  Future<void> setCloudAnchorConfig(Map<String, dynamic> config);
  Future<String> shareCloudAnchor(String cloudAnchorId);
  Future<void> joinCloudAnchorSession(String sessionId);
  Future<void> leaveCloudAnchorSession();

  // Occlusion
  Future<void> setOcclusionEnabled(bool enabled);
  Future<bool> isOcclusionEnabled();
  Future<void> setOcclusionConfig(Map<String, dynamic> config);
  Future<List<Map<String, dynamic>>> getOcclusions();
  Future<Map<String, dynamic>?> getOcclusion(String occlusionId);
  Future<String> createOcclusion(Map<String, dynamic> args);
  Future<void> updateOcclusion(Map<String, dynamic> args);
  Future<void> removeOcclusion(String occlusionId);

  // Physics
  Future<void> setPhysicsEnabled(bool enabled);
  Future<bool> isPhysicsEnabled();
  Future<void> setPhysicsConfig(Map<String, dynamic> config);
  Future<String> addPhysicsBody(Map<String, dynamic> args);
  Future<void> removePhysicsBody(String bodyId);
  Future<void> updatePhysicsBody(Map<String, dynamic> args);
  Future<List<Map<String, dynamic>>> getPhysicsBodies();
  Future<Map<String, dynamic>?> getPhysicsBody(String bodyId);
  Future<void> applyForce(Map<String, dynamic> args);
  Future<void> applyImpulse(Map<String, dynamic> args);
  Future<void> applyTorque(Map<String, dynamic> args);
  Future<String> addPhysicsConstraint(Map<String, dynamic> args);
  Future<void> removePhysicsConstraint(String constraintId);
  Future<List<Map<String, dynamic>>> getPhysicsConstraints();
  Future<List<Map<String, dynamic>>> raycast(Map<String, dynamic> args);

  // Multi-user
  Future<void> createMultiUserSession(Map<String, dynamic> config);
  Future<void> joinMultiUserSession(String sessionId, {String? displayName, String? password});
  Future<void> leaveMultiUserSession();
  Future<Map<String, dynamic>?> getMultiUserSession();
  Future<List<Map<String, dynamic>>> getMultiUserParticipants();
  Future<void> shareObject(Map<String, dynamic> args);
  Future<void> unshareObject(String objectId);
  Future<List<Map<String, dynamic>>> getSharedObjects();
  Future<void> sendMultiUserMessage(Map<String, dynamic> args);
  Future<void> setMultiUserConfig(Map<String, dynamic> config);

  // Lighting
  Future<void> setLightingEnabled(bool enabled);
  Future<bool> isLightingEnabled();
  Future<void> setLightingConfig(Map<String, dynamic> config);
  Future<Map<String, dynamic>?> getLightingConfig();
  Future<dynamic> addLight(Map<String, dynamic> args);
  Future<void> removeLight(String lightId);
  Future<void> updateLight(Map<String, dynamic> args);
  Future<List<Map<String, dynamic>>> getLights();
  Future<Map<String, dynamic>?> getLight(String lightId);
  Future<void> setAmbientLight(Map<String, dynamic> args);
  Future<Map<String, dynamic>?> getAmbientLight();
  Future<void> setEnvironmentMap(Map<String, dynamic> args);
  Future<Map<String, dynamic>?> getEnvironmentMap();

  // Environmental probes
  Future<void> setEnvironmentalProbesEnabled(bool enabled);
  Future<bool> isEnvironmentalProbesEnabled();
  Future<void> setEnvironmentalProbeConfig(Map<String, dynamic> config);
  Future<Map<String, dynamic>?> getEnvironmentalProbeConfig();
  Future<dynamic> addEnvironmentalProbe(Map<String, dynamic> args);
  Future<void> removeEnvironmentalProbe(String probeId);
  Future<void> updateEnvironmentalProbe(Map<String, dynamic> args);
  Future<List<Map<String, dynamic>>> getEnvironmentalProbes();
  Future<Map<String, dynamic>?> getEnvironmentalProbe(String probeId);
  Future<void> forceEnvironmentalProbeUpdate(String probeId);
  Future<void> clearEnvironmentalProbes();

  // Generic fallback for methods not explicitly declared
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);

  /// Callback handler - the backend calls this when native/web pushes updates
  void Function(String method, dynamic arguments)? onPlatformCallback;

  /// Dispose the backend
  void dispose();
}
