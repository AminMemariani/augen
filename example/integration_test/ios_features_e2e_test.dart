// End-to-end tests that exercise every Augen feature against the REAL native
// implementation on a physical device (ARKit / RealityKit on iOS).
//
// Unlike plugin_integration_test.dart, these tests are strict: a feature that
// reports "not supported", throws MissingPluginException, or fails to
// round-trip its state through the native layer fails the test.
//
// Run on a connected iPhone:
//   cd example
//   flutter test integration_test/ios_features_e2e_test.dart -d <device-id>

import 'dart:async';

import 'package:augen/augen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<AugenController> _startSession(WidgetTester tester) async {
  final completer = Completer<AugenController>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AugenView(
          onViewCreated: (c) {
            if (!completer.isCompleted) completer.complete(c);
          },
          config: const ARSessionConfig(
            planeDetection: true,
            lightEstimation: true,
            depthData: false,
            autoFocus: true,
          ),
        ),
      ),
    ),
  );
  // Platform views need real frames to be created.
  for (var i = 0; i < 50 && !completer.isCompleted; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final controller = await completer.future.timeout(const Duration(seconds: 10));
  expect(await controller.isARSupported(), isTrue, reason: 'ARKit must be supported');
  await controller.initialize(
    const ARSessionConfig(planeDetection: true, lightEstimation: true, autoFocus: true),
  );
  // Let the session spin up and deliver a few frames.
  await _settle(tester, const Duration(seconds: 2));
  return controller;
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _stop(WidgetTester tester, AugenController controller) async {
  controller.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
}

ARNode _cube(String id, {Vector3 position = const Vector3(0, 0, -0.6)}) =>
    ARNode(id: id, type: NodeType.cube, position: position);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Core: nodes, anchors, hit test, pause/resume/reset', (tester) async {
    final c = await _startSession(tester);

    await c.addNode(_cube('core_cube'));
    await c.addNode(ARNode(id: 'core_sphere', type: NodeType.sphere, position: const Vector3(0.2, 0, -0.6)));
    await c.updateNode(ARNode(id: 'core_cube', type: NodeType.cube, position: const Vector3(0, 0.1, -0.6)));

    final anchor = await c.addAnchor(const Vector3(0, 0, -1));
    expect(anchor, isNotNull);
    await c.removeAnchor(anchor!.id);

    // Must not throw even when no plane is under the point.
    final hits = await c.hitTest(200, 400);
    expect(hits, isA<List<ARHitResult>>());

    await c.pause();
    await c.resume();
    await c.removeNode('core_sphere');
    await c.reset();
    await _stop(tester, c);
  });

  testWidgets('Animation: built-in clips, blending, transitions, state machine', (tester) async {
    final c = await _startSession(tester);
    await c.addNode(_cube('anim_node'));

    final clips = await c.getAvailableAnimations('anim_node');
    expect(clips, isNotEmpty, reason: 'primitives expose built-in procedural clips');
    final clip = clips.contains('spin') ? 'spin' : clips.first;

    final statuses = <dynamic>[];
    final sub = c.animationStatusStream.listen(statuses.add);

    await c.playAnimation(nodeId: 'anim_node', animationId: clip);
    await _settle(tester, const Duration(milliseconds: 500));
    await c.setAnimationSpeed(nodeId: 'anim_node', animationId: clip, speed: 2.0);
    await c.pauseAnimation(nodeId: 'anim_node', animationId: clip);
    await c.resumeAnimation(nodeId: 'anim_node', animationId: clip);
    await c.seekAnimation(nodeId: 'anim_node', animationId: clip, time: 0.2);
    await c.stopAnimation(nodeId: 'anim_node', animationId: clip);
    await _settle(tester, const Duration(milliseconds: 300));
    expect(statuses, isNotEmpty, reason: 'onAnimationStatus events must arrive');

    await c.crossfadeToAnimation(
      nodeId: 'anim_node',
      fromAnimationId: clips.first,
      toAnimationId: clips.last,
      duration: 0.3,
    );
    await _settle(tester, const Duration(milliseconds: 500));

    expect(await c.getBoneHierarchy('anim_node'), isA<List<String>>());
    await sub.cancel();
    await _stop(tester, c);
  });

  testWidgets('Physics: bodies, forces, world config, constraints', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isPhysicsSupported(), isTrue);

    await c.initializePhysics(const PhysicsWorldConfig());
    await c.startPhysics();

    await c.addNode(_cube('phys_a', position: const Vector3(0, 0.3, -0.8)));
    await c.addNode(_cube('phys_b', position: const Vector3(0.2, 0.3, -0.8)));
    final bodyA = await c.createPhysicsBody(
      nodeId: 'phys_a',
      type: PhysicsBodyType.dynamic,
      material: const PhysicsMaterial(),
      mass: 1.0,
    );
    final bodyB = await c.createPhysicsBody(
      nodeId: 'phys_b',
      type: PhysicsBodyType.dynamic,
      material: const PhysicsMaterial(),
      mass: 1.0,
    );
    expect(bodyA, isNotEmpty);

    await c.applyForce(bodyId: bodyA, force: const Vector3(0, 5, 0));
    await c.applyImpulse(bodyId: bodyA, impulse: const Vector3(0.5, 0, 0));
    await c.setVelocity(bodyId: bodyB, velocity: const Vector3(0, 1, 0));
    await c.setAngularVelocity(bodyId: bodyB, angularVelocity: const Vector3(0, 1, 0));
    await _settle(tester, const Duration(seconds: 1));

    final bodies = await c.getPhysicsBodies();
    expect(bodies.map((b) => b.id), containsAll([bodyA, bodyB]));

    final constraint = await c.createPhysicsConstraint(
      bodyAId: bodyA,
      bodyBId: bodyB,
      type: PhysicsConstraintType.fixed,
    );
    expect((await c.getPhysicsConstraints()).map((x) => x.id), contains(constraint));
    await c.removePhysicsConstraint(constraint);

    await c.updatePhysicsWorldConfig(const PhysicsWorldConfig(gravity: Vector3(0, -5, 0)));
    expect((await c.getPhysicsWorldConfig()).gravity.y, closeTo(-5, 0.01));

    await c.pausePhysics();
    await c.resumePhysics();
    await c.removePhysicsBody(bodyA);
    await c.removePhysicsBody(bodyB);
    await c.stopPhysics();
    await _stop(tester, c);
  });

  testWidgets('Image tracking: targets from assets round-trip', (tester) async {
    final c = await _startSession(tester);

    await c.addImageTarget(ARImageTarget(
      id: 'poster',
      name: 'Poster',
      imagePath: 'assets/images/sample_poster.jpg',
      physicalSize: const ImageTargetSize(0.3, 0.4),
    ));
    await c.addImageTarget(ARImageTarget(
      id: 'card',
      name: 'Card',
      imagePath: 'assets/images/sample_card.jpg',
      physicalSize: const ImageTargetSize(0.085, 0.055),
    ));
    expect((await c.getImageTargets()).map((t) => t.id), containsAll(['poster', 'card']));

    expect(await c.setImageTrackingEnabled(true), isTrue);
    expect(await c.isImageTrackingEnabled(), isTrue);
    expect(await c.getTrackedImages(), isA<List<ARTrackedImage>>());

    await c.removeImageTarget('card');
    expect((await c.getImageTargets()).map((t) => t.id), isNot(contains('card')));
    expect(await c.setImageTrackingEnabled(false), isTrue);
    await _stop(tester, c);
  });

  testWidgets('Lighting: lights CRUD, config, shadows, ambient', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isLightingSupported(), isTrue);
    final caps = await c.getLightingCapabilities();
    expect(caps['maxLights'], greaterThan(0));

    final light = await c.addLight(ARLight(
      id: 'e2e_dir',
      type: ARLightType.directional,
      position: const Vector3(0, 2, 0),
      rotation: const Quaternion(0, 0, 0, 1),
      direction: const Vector3(0, -1, 0),
      intensity: 1000,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    ));
    expect(light.id, 'e2e_dir');
    await c.addLight(ARLight(
      id: 'e2e_spot',
      type: ARLightType.spot,
      position: const Vector3(0, 1, -0.5),
      rotation: const Quaternion(0, 0, 0, 1),
      direction: const Vector3(0, -1, 0),
      intensity: 800,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    ));
    expect((await c.getLights()).map((l) => l.id), containsAll(['e2e_dir', 'e2e_spot']));

    await c.updateLightIntensity(lightId: 'e2e_dir', intensity: 500);
    expect((await c.getLight('e2e_dir'))!.intensity, closeTo(500, 0.01));
    await c.updateLightColor(lightId: 'e2e_dir', color: const Vector3(1, 0.5, 0.5));
    await c.setLightEnabled(lightId: 'e2e_spot', enabled: false);
    expect((await c.getLight('e2e_spot'))!.isEnabled, isFalse);
    await c.setLightCastShadows(lightId: 'e2e_dir', castShadows: true);

    await c.setShadowsEnabled(true);
    await c.setShadowQuality(ShadowQuality.high);
    await c.setAmbientLighting(intensity: 0.8, color: const Vector3(1, 1, 1));
    final config = await c.getLightingConfig();
    expect(config, isA<ARLightingConfig>());

    await c.removeLight('e2e_spot');
    await c.clearLights();
    expect(await c.getLights(), isEmpty);
    await _stop(tester, c);
  });

  testWidgets('Occlusion: capabilities, enable, create/update/remove', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isOcclusionSupported(), isTrue);
    final caps = await c.getOcclusionCapabilities();
    expect(caps['personOcclusion'], isTrue);

    await c.setOcclusionEnabled(true);
    expect(await c.isOcclusionEnabled(), isTrue);

    final id = await c.createOcclusion(
      type: OcclusionType.plane,
      position: const Vector3(0, -0.5, -1),
      rotation: const Quaternion(0, 0, 0, 1),
      scale: const Vector3(1, 1, 1),
    );
    expect((await c.getOcclusions()).map((o) => o.id), contains(id));
    await c.updateOcclusion(occlusionId: id, position: const Vector3(0, -0.4, -1));
    expect(await c.getOcclusion(id), isNotNull);
    await c.removeOcclusion(id);
    expect((await c.getOcclusions()).map((o) => o.id), isNot(contains(id)));

    await c.setOcclusionEnabled(false);
    expect(await c.isOcclusionEnabled(), isFalse);
    await _stop(tester, c);
  });

  testWidgets('Environmental probes: add/update/remove, config', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isEnvironmentalProbesSupported(), isTrue);
    final caps = await c.getEnvironmentalProbesCapabilities();
    expect(caps['supported'], isTrue);

    final probe = await c.addEnvironmentalProbe(AREnvironmentalProbe(
      id: 'e2e_probe',
      type: ARProbeType.spherical,
      position: const Vector3(0, 0, -1),
      rotation: const Quaternion(0, 0, 0, 1),
      scale: const Vector3(1, 1, 1),
      influenceRadius: 2.0,
      updateMode: ARProbeUpdateMode.automatic,
      quality: ARProbeQuality.medium,
      isActive: true,
      captureReflections: true,
      captureLighting: true,
      textureResolution: 256,
      isRealTime: true,
      updateFrequency: 1.0,
      confidence: 1.0,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    ));
    expect((await c.getEnvironmentalProbes()).map((p) => p.id), contains(probe.id));

    await c.updateEnvironmentalProbePosition(probeId: probe.id, position: const Vector3(0, 0.2, -1));
    await c.updateEnvironmentalProbeInfluenceRadius(probeId: probe.id, influenceRadius: 3.0);
    await c.forceEnvironmentalProbeUpdate(probe.id);
    expect(await c.getEnvironmentalProbe(probe.id), isNotNull);
    expect(await c.getEnvironmentalProbeConfig(), isA<AREnvironmentalProbeConfig>());

    await c.removeEnvironmentalProbe(probe.id);
    await c.clearEnvironmentalProbes();
    expect(await c.getEnvironmentalProbes(), isEmpty);
    await _stop(tester, c);
  });

  testWidgets('Cloud anchors (on-device persistence): create/get/delete', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isCloudAnchorsSupported(), isTrue);
    await c.setCloudAnchorConfig(maxCloudAnchors: 5, timeout: const Duration(seconds: 20));

    final created = Completer<void>();
    final statusSub = c.cloudAnchorStatusStream.listen((s) {
      if (s.state == CloudAnchorState.created && !created.isCompleted) {
        created.complete();
      }
    });

    final local = await c.addAnchor(const Vector3(0, 0, -0.8));
    final cloudId = await c.createCloudAnchor(local!.id);
    expect(cloudId, isNotEmpty);
    expect((await c.getCloudAnchors()).map((a) => a.id), contains(cloudId));
    expect(await c.getCloudAnchor(cloudId), isNotNull);

    // Hosting persists an ARWorldMap, which ARKit only produces once it has
    // mapped enough of the room. On a stationary device that may never
    // happen within the test window — then sharing must fail with the
    // documented, actionable error rather than silently succeeding.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!created.isCompleted && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (created.isCompleted) {
      expect(await c.shareCloudAnchor(cloudId), isNotEmpty);
    } else {
      await expectLater(
        c.shareCloudAnchor(cloudId),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'CLOUD_ANCHOR_NOT_READY')),
      );
    }
    await statusSub.cancel();

    await c.deleteCloudAnchor(cloudId);
    expect((await c.getCloudAnchors()).map((a) => a.id), isNot(contains(cloudId)));
    await _stop(tester, c);
  });

  testWidgets('Multi-user: host session, participants, shared objects', (tester) async {
    final c = await _startSession(tester);
    expect(await c.isMultiUserSupported(), isTrue);

    final sessionId = await c.createMultiUserSession(name: 'e2e session', maxParticipants: 4);
    expect(sessionId, isNotEmpty);
    final session = await c.getMultiUserSession();
    expect(session, isNotNull);
    expect(session!.participants, isNotEmpty, reason: 'local host is a participant');
    expect(await c.getMultiUserParticipants(), isNotEmpty);

    await c.addNode(_cube('shared_cube'));
    final sharedId = await c.shareObject(nodeId: 'shared_cube');
    expect((await c.getMultiUserSharedObjects()).map((o) => o.id), contains(sharedId));
    await c.unshareObject(sharedId);

    await c.leaveMultiUserSession();
    expect(await c.getMultiUserSession(), isNull);
    await _stop(tester, c);
  });

  // Runs last: switching to the front camera resets world tracking.
  testWidgets('Face tracking: enable front-camera tracking and query faces', (tester) async {
    final c = await _startSession(tester);
    expect(await c.setFaceTrackingEnabled(true), isTrue);
    expect(await c.isFaceTrackingEnabled(), isTrue);
    await c.setFaceTrackingConfig(detectLandmarks: true, detectExpressions: true);
    await _settle(tester, const Duration(seconds: 1));
    expect(await c.getTrackedFaces(), isA<List<ARFace>>());
    expect(await c.setFaceTrackingEnabled(false), isTrue);
    expect(await c.isFaceTrackingEnabled(), isFalse);
    await _stop(tester, c);
  });

  testWidgets('No feature is reported as unimplemented by the native layer', (tester) async {
    final c = await _startSession(tester);
    // Each of these throws MissingPluginException if the native handler is absent.
    final probes = <String, Future<Object?> Function()>{
      'getTrackedFaces': c.getTrackedFaces,
      'getTrackedImages': c.getTrackedImages,
      'getImageTargets': c.getImageTargets,
      'getPhysicsBodies': c.getPhysicsBodies,
      'getPhysicsConstraints': c.getPhysicsConstraints,
      'getLights': c.getLights,
      'getOcclusions': c.getOcclusions,
      'getEnvironmentalProbes': c.getEnvironmentalProbes,
      'getCloudAnchors': c.getCloudAnchors,
      'getMultiUserParticipants': c.getMultiUserParticipants,
    };
    final missing = <String>[];
    for (final entry in probes.entries) {
      try {
        await entry.value();
      } on MissingPluginException {
        missing.add(entry.key);
      }
    }
    expect(missing, isEmpty, reason: 'Not implemented natively: $missing');
    await _stop(tester, c);
  });
}
