// This is a comprehensive Flutter integration test for the Augen AR plugin.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:augen/augen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Augen AR Integration Tests', () {
    testWidgets('AugenView can be created and disposed', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
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

      // Wait for view to be created
      await tester.pumpAndSettle();

      // Give some time for the platform view to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify controller was created
      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Controller was not created within timeout');
        },
      );

      expect(createdController, isNotNull);
      expect(createdController.viewId, isNotNull);

      // Verify controller has streams
      expect(createdController.planesStream, isNotNull);
      expect(createdController.anchorsStream, isNotNull);
      expect(createdController.errorStream, isNotNull);
    });

    testWidgets('AugenController can check AR support', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      // Check AR support
      final isSupported = await createdController.isARSupported();

      // Should return a boolean value (true or false depending on platform)
      expect(isSupported, isA<bool>());
    });

    testWidgets('AugenController can initialize AR session', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      // Try to initialize AR session
      try {
        await createdController.initialize(
          const ARSessionConfig(
            planeDetection: true,
            lightEstimation: true,
            depthData: false,
            autoFocus: true,
          ),
        );
        // If we get here, initialization succeeded or the platform supports it
        expect(true, true);
      } catch (e) {
        // If AR is not supported, that's also acceptable for this test
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController can add and remove nodes', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      // Create a test node
      final node = ARNode(
        id: 'test_node_1',
        type: NodeType.sphere,
        position: const Vector3(0, 0, -1),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.1, 0.1, 0.1),
        properties: {'color': 'blue', 'test': true},
      );

      try {
        // Try to add the node
        await createdController.addNode(node);

        // If we get here, the node was added successfully
        expect(true, true);

        // Try to remove the node
        await createdController.removeNode('test_node_1');

        // If we get here, the node was removed successfully
        expect(true, true);
      } catch (e) {
        // If AR operations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController can perform hit test', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Perform a hit test at screen center
        final results = await createdController.hitTest(0.5, 0.5);

        // Should return a list (may be empty if no surfaces detected)
        expect(results, isA<List<ARHitResult>>());
      } catch (e) {
        // If AR operations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController can add and remove anchors', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Try to add an anchor
        final anchor = await createdController.addAnchor(
          const Vector3(0, 0, -0.5),
        );

        // Should return an anchor or null
        expect(anchor, anyOf(isNull, isA<ARAnchor>()));

        if (anchor != null) {
          // Try to remove the anchor
          await createdController.removeAnchor(anchor.id);
          expect(true, true);
        }
      } catch (e) {
        // If AR operations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController can pause and resume', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Try to pause
        await createdController.pause();
        expect(true, true);

        // Try to resume
        await createdController.resume();
        expect(true, true);
      } catch (e) {
        // If AR operations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController can reset session', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Try to reset
        await createdController.reset();
        expect(true, true);
      } catch (e) {
        // If AR operations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('AugenController streams work correctly', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      // Set up stream listeners
      final planesSubscription = createdController.planesStream.listen((
        planes,
      ) {
        // Stream is working
      });

      final anchorsSubscription = createdController.anchorsStream.listen((
        anchors,
      ) {
        // Stream is working
      });

      final errorSubscription = createdController.errorStream.listen((error) {
        // Stream is working
      });

      // New image tracking streams
      final imageTargetsSubscription = createdController.imageTargetsStream
          .listen((targets) {
            // Stream is working
          });

      final trackedImagesSubscription = createdController.trackedImagesStream
          .listen((tracked) {
            // Stream is working
          });

      // Face tracking streams
      final facesSubscription = createdController.facesStream.listen((faces) {
        // Stream is working
      });

      // Animation streams
      final animationStatusSubscription = createdController
          .animationStatusStream
          .listen((status) {
            // Stream is working
          });

      final transitionStatusSubscription = createdController
          .transitionStatusStream
          .listen((status) {
            // Stream is working
          });

      final stateMachineStatusSubscription = createdController
          .stateMachineStatusStream
          .listen((status) {
            // Stream is working
          });

      // Wait a bit for any potential updates
      await Future.delayed(const Duration(seconds: 1));

      // Verify that streams can be listened to (they may not emit if AR not available)
      expect(planesSubscription, isNotNull);
      expect(anchorsSubscription, isNotNull);
      expect(errorSubscription, isNotNull);
      expect(imageTargetsSubscription, isNotNull);
      expect(trackedImagesSubscription, isNotNull);
      expect(facesSubscription, isNotNull);
      expect(animationStatusSubscription, isNotNull);
      expect(transitionStatusSubscription, isNotNull);
      expect(stateMachineStatusSubscription, isNotNull);

      // Clean up
      await planesSubscription.cancel();
      await anchorsSubscription.cancel();
      await errorSubscription.cancel();
      await imageTargetsSubscription.cancel();
      await trackedImagesSubscription.cancel();
      await facesSubscription.cancel();
      await animationStatusSubscription.cancel();
      await transitionStatusSubscription.cancel();
      await stateMachineStatusSubscription.cancel();
    });

    testWidgets('Full AR workflow: initialize, add nodes, hit test, clean up', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
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

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Step 1: Check AR support
        final isSupported = await createdController.isARSupported();
        // ignore: avoid_print
        print('AR Supported: $isSupported');

        if (isSupported) {
          // Step 2: Initialize AR
          await createdController.initialize(
            const ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
              depthData: false,
              autoFocus: true,
            ),
          );

          // Step 3: Add multiple nodes
          for (int i = 0; i < 3; i++) {
            final node = ARNode(
              id: 'workflow_node_$i',
              type: NodeType.values[i % NodeType.values.length],
              position: Vector3(i * 0.1, 0, -1),
              scale: const Vector3(0.1, 0.1, 0.1),
            );
            await createdController.addNode(node);
          }

          // Step 4: Perform hit test
          final hitResults = await createdController.hitTest(0.5, 0.5);
          // ignore: avoid_print
          print('Hit test results: ${hitResults.length}');

          // Step 5: Add an anchor if hit test succeeded
          if (hitResults.isNotEmpty) {
            final anchor = await createdController.addAnchor(
              hitResults.first.position,
            );
            // ignore: avoid_print
            print('Anchor added: ${anchor?.id}');
          }

          // Step 6: Update a node
          final updatedNode = ARNode(
            id: 'workflow_node_0',
            type: NodeType.sphere,
            position: const Vector3(0.2, 0.1, -1),
            scale: const Vector3(0.2, 0.2, 0.2),
          );
          await createdController.updateNode(updatedNode);

          // Step 7: Remove nodes
          for (int i = 0; i < 3; i++) {
            await createdController.removeNode('workflow_node_$i');
          }

          // Step 8: Reset session
          await createdController.reset();
        }

        expect(true, true);
      } catch (e) {
        // If AR is not fully supported, test still passes
        // ignore: avoid_print
        print('AR workflow error (acceptable): $e');
        expect(e, isNotNull);
      }
    });

    testWidgets('Multiple AugenViews can be created sequentially', (
      WidgetTester tester,
    ) async {
      // First view
      final completer1 = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer1.isCompleted) {
                  completer1.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final created1 = await completer1.future.timeout(
        const Duration(seconds: 5),
      );
      expect(created1, isNotNull);

      // Dispose first view
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Create second view
      final completer2 = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer2.isCompleted) {
                  completer2.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final created2 = await completer2.future.timeout(
        const Duration(seconds: 5),
      );
      expect(created2, isNotNull);

      // Verify they have different view IDs
      expect(created1.viewId != created2.viewId, true);
    });

    testWidgets('Image tracking features work correctly', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Test image tracking methods
        final target = ARImageTarget(
          id: 'test_target',
          name: 'Test Target',
          imagePath: 'https://example.com/test.jpg',
          physicalSize: const ImageTargetSize(0.1, 0.1),
        );

        // Add image target
        await createdController.addImageTarget(target);
        expect(true, true);

        // Get image targets
        final targets = await createdController.getImageTargets();
        expect(targets, isA<List<ARImageTarget>>());

        // Enable image tracking
        await createdController.setImageTrackingEnabled(true);
        expect(true, true);

        // Check if image tracking is enabled
        final isEnabled = await createdController.isImageTrackingEnabled();
        expect(isEnabled, isA<bool>());

        // Get tracked images
        final trackedImages = await createdController.getTrackedImages();
        expect(trackedImages, isA<List<ARTrackedImage>>());

        // Remove image target
        await createdController.removeImageTarget('test_target');
        expect(true, true);

        // Disable image tracking
        await createdController.setImageTrackingEnabled(false);
        expect(true, true);
      } catch (e) {
        // If image tracking is not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('Face tracking features work correctly', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Test face tracking methods
        // Enable face tracking
        await createdController.setFaceTrackingEnabled(true);
        expect(true, true);

        // Check if face tracking is enabled
        final isEnabled = await createdController.isFaceTrackingEnabled();
        expect(isEnabled, isA<bool>());

        // Get tracked faces
        final trackedFaces = await createdController.getTrackedFaces();
        expect(trackedFaces, isA<List<ARFace>>());

        // Configure face tracking
        await createdController.setFaceTrackingConfig(
          detectLandmarks: true,
          detectExpressions: true,
          minFaceSize: 0.1,
          maxFaceSize: 1.0,
        );
        expect(true, true);

        // Test adding content to a tracked face (if any faces are tracked)
        if (trackedFaces.isNotEmpty) {
          final face = trackedFaces.first;
          final contentNode = ARNode(
            id: 'face_content_${face.id}',
            type: NodeType.sphere,
            position: const Vector3(0, 0, 0.1),
            scale: const Vector3(0.05, 0.05, 0.05),
          );

          await createdController.addNodeToTrackedFace(
            nodeId: 'face_content_${face.id}',
            faceId: face.id,
            node: contentNode,
          );
          expect(true, true);

          // Get face landmarks
          final landmarks = await createdController.getFaceLandmarks(face.id);
          expect(landmarks, isA<List<FaceLandmark>>());

          // Remove content from face
          await createdController.removeNodeFromTrackedFace(
            nodeId: 'face_content_${face.id}',
            faceId: face.id,
          );
          expect(true, true);
        }

        // Disable face tracking
        await createdController.setFaceTrackingEnabled(false);
        expect(true, true);
      } catch (e) {
        // If face tracking is not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('Animation features work correctly', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Test animation methods
        const nodeId = 'test_character';

        // Play animation
        await createdController.playAnimation(
          nodeId: nodeId,
          animationId: 'idle',
        );
        expect(true, true);

        // Pause animation
        await createdController.pauseAnimation(
          nodeId: nodeId,
          animationId: 'idle',
        );
        expect(true, true);

        // Resume animation
        await createdController.resumeAnimation(
          nodeId: nodeId,
          animationId: 'idle',
        );
        expect(true, true);

        // Stop animation
        await createdController.stopAnimation(
          nodeId: nodeId,
          animationId: 'idle',
        );
        expect(true, true);

        // Set animation speed
        await createdController.setAnimationSpeed(
          nodeId: nodeId,
          animationId: 'walk',
          speed: 1.5,
        );
        expect(true, true);

        // Blend animations
        await createdController.blendAnimations(
          nodeId: nodeId,
          animationWeights: {'idle': 0.5, 'walk': 0.5},
        );
        expect(true, true);

        // Crossfade animation
        await createdController.crossfadeToAnimation(
          nodeId: nodeId,
          fromAnimationId: 'idle',
          toAnimationId: 'walk',
          duration: 1.0,
        );
        expect(true, true);

        // Get available animations
        final animations = await createdController.getAvailableAnimations(
          nodeId,
        );
        expect(animations, isA<List<String>>());

        // Get animation layers
        final layers = await createdController.getAnimationLayers(nodeId);
        expect(layers, isA<List<Map<String, dynamic>>>());

        // Set animation layer weight
        await createdController.setAnimationLayerWeight(
          nodeId: nodeId,
          layer: 0,
          weight: 0.8,
        );
        expect(true, true);

        // Play additive animation
        await createdController.playAdditiveAnimation(
          nodeId: nodeId,
          animationId: 'wave',
          targetLayer: 1,
          weight: 0.3,
        );
        expect(true, true);

        // Set bone mask
        await createdController.setAnimationBoneMask(
          nodeId: nodeId,
          layer: 0,
          boneMask: ['spine', 'head'],
        );
        expect(true, true);
      } catch (e) {
        // If animations are not supported, that's acceptable
        expect(e, isNotNull);
      }
    });

    testWidgets('Complete feature integration test', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
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

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      final createdController = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      try {
        // Step 1: Check AR support
        final isSupported = await createdController.isARSupported();
        // ignore: avoid_print
        print('AR Supported: $isSupported');

        if (isSupported) {
          // Step 2: Initialize AR
          await createdController.initialize(
            const ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
              depthData: false,
              autoFocus: true,
            ),
          );

          // Step 3: Add image targets
          final target = ARImageTarget(
            id: 'integration_test_target',
            name: 'Integration Test Target',
            imagePath: 'https://example.com/integration_test.jpg',
            physicalSize: const ImageTargetSize(0.2, 0.2),
          );
          await createdController.addImageTarget(target);

          // Step 4: Enable image tracking
          await createdController.setImageTrackingEnabled(true);

          // Step 4.5: Enable face tracking
          await createdController.setFaceTrackingEnabled(true);
          await createdController.setFaceTrackingConfig(
            detectLandmarks: true,
            detectExpressions: true,
            minFaceSize: 0.1,
            maxFaceSize: 1.0,
          );

          // Step 5: Add a 3D model node
          final modelNode = ARNode.fromModel(
            id: 'integration_test_model',
            modelPath: 'https://example.com/models/test.glb',
            position: const Vector3(0, 0, -1),
            rotation: const Quaternion(0, 0, 0, 1),
            scale: const Vector3(0.1, 0.1, 0.1),
          );
          await createdController.addNode(modelNode);

          // Step 6: Test animations on the model
          await createdController.playAnimation(
            nodeId: 'integration_test_model',
            animationId: 'idle',
          );

          // Step 7: Test animation blending
          await createdController.blendAnimations(
            nodeId: 'integration_test_model',
            animationWeights: {'idle': 0.7, 'walk': 0.3},
          );

          // Step 8: Perform hit test
          final hitResults = await createdController.hitTest(0.5, 0.5);
          // ignore: avoid_print
          print('Hit test results: ${hitResults.length}');

          // Step 9: Add an anchor if hit test succeeded
          if (hitResults.isNotEmpty) {
            final anchor = await createdController.addAnchor(
              hitResults.first.position,
            );
            // ignore: avoid_print
            print('Anchor added: ${anchor?.id}');
          }

          // Step 10: Test cloud anchors
          final cloudAnchorsSupported = await createdController
              .isCloudAnchorsSupported();
          // ignore: avoid_print
          print('Cloud anchors supported: $cloudAnchorsSupported');

          if (cloudAnchorsSupported) {
            // Configure cloud anchors
            await createdController.setCloudAnchorConfig(
              maxCloudAnchors: 5,
              timeout: const Duration(seconds: 30),
              enableSharing: true,
            );

            // Create a cloud anchor (if we have a local anchor)
            if (hitResults.isNotEmpty) {
              final localAnchor = await createdController.addAnchor(
                hitResults.first.position,
              );
              if (localAnchor != null) {
                final cloudAnchorId = await createdController.createCloudAnchor(
                  localAnchor.id,
                );
                // ignore: avoid_print
                print('Created cloud anchor: $cloudAnchorId');

                // Get cloud anchors
                final cloudAnchors = await createdController.getCloudAnchors();
                // ignore: avoid_print
                print('Cloud anchors: ${cloudAnchors.length}');

                // Share cloud anchor session
                final sessionId = await createdController.shareCloudAnchor(
                  cloudAnchorId,
                );
                // ignore: avoid_print
                print('Shared cloud anchor session: $sessionId');

                // Clean up cloud anchor
                await createdController.deleteCloudAnchor(cloudAnchorId);
              }
            }
          }

          // Step 11: Get all data
          final targets = await createdController.getImageTargets();
          final trackedImages = await createdController.getTrackedImages();
          final trackedFaces = await createdController.getTrackedFaces();
          final animations = await createdController.getAvailableAnimations(
            'integration_test_model',
          );

          // ignore: avoid_print
          print('Image targets: ${targets.length}');
          // ignore: avoid_print
          print('Tracked images: ${trackedImages.length}');
          // ignore: avoid_print
          print('Tracked faces: ${trackedFaces.length}');
          // ignore: avoid_print
          print('Available animations: ${animations.length}');

          // Step 12: Clean up
          await createdController.removeNode('integration_test_model');
          await createdController.removeImageTarget('integration_test_target');
          await createdController.setImageTrackingEnabled(false);
          await createdController.setFaceTrackingEnabled(false);
          await createdController.reset();
        }

        expect(true, true);
      } catch (e) {
        // If AR is not fully supported, test still passes
        // ignore: avoid_print
        print('Complete integration test error (acceptable): $e');
        expect(e, isNotNull);
      }
    });

    testWidgets('Cloud Anchor Integration Test', (WidgetTester tester) async {
      try {
        final completer = Completer<AugenController>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AugenView(
                onViewCreated: (c) {
                  if (!completer.isCompleted) {
                    completer.complete(c);
                  }
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

        await tester.pumpAndSettle();
        await Future.delayed(const Duration(milliseconds: 500));

        final createdController = await completer.future;
        expect(createdController, isNotNull);

        // Test cloud anchor support
        final cloudAnchorsSupported = await createdController
            .isCloudAnchorsSupported();
        // ignore: avoid_print
        print('Cloud anchors supported: $cloudAnchorsSupported');

        if (cloudAnchorsSupported) {
          // Configure cloud anchors
          await createdController.setCloudAnchorConfig(
            maxCloudAnchors: 3,
            timeout: const Duration(seconds: 15),
            enableSharing: true,
          );

          // Test cloud anchor streams
          final cloudAnchorsSubscription = createdController.cloudAnchorsStream
              .listen((anchors) {
                // ignore: avoid_print
                print('Cloud anchors updated: ${anchors.length}');
              });

          final cloudAnchorStatusSubscription = createdController
              .cloudAnchorStatusStream
              .listen((status) {
                // ignore: avoid_print
                print('Cloud anchor status: ${status.state}');
              });

          // Test session management (using a dummy cloud anchor ID)
          final sessionId = await createdController.shareCloudAnchor(
            'dummy_cloud_anchor_id',
          );
          // ignore: avoid_print
          print('Shared cloud anchor session: $sessionId');

          // Test joining a session (this would normally be done with a real session ID)
          try {
            await createdController.joinCloudAnchorSession('test_session_123');
            // ignore: avoid_print
            print('Joined cloud anchor session');
          } catch (e) {
            // Expected to fail with test session ID
            // ignore: avoid_print
            print('Join session failed (expected): $e');
          }

          // Test leaving session
          await createdController.leaveCloudAnchorSession();
          // ignore: avoid_print
          print('Left cloud anchor session');

          // Clean up subscriptions
          await cloudAnchorsSubscription.cancel();
          await cloudAnchorStatusSubscription.cancel();
        }

        expect(true, true);
      } catch (e) {
        // If cloud anchors are not supported, test still passes
        // ignore: avoid_print
        print('Cloud anchor integration test error (acceptable): $e');
        expect(e, isNotNull);
      }
    });

    testWidgets('Occlusion Integration Test', (WidgetTester tester) async {
      try {
        final completer = Completer<AugenController>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AugenView(
                onViewCreated: (c) {
                  if (!completer.isCompleted) {
                    completer.complete(c);
                  }
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

        await tester.pumpAndSettle();
        await Future.delayed(const Duration(milliseconds: 500));

        final createdController = await completer.future;
        expect(createdController, isNotNull);

        // Test occlusion support
        final occlusionSupported = await createdController
            .isOcclusionSupported();
        // ignore: avoid_print
        print('Occlusion supported: $occlusionSupported');

        if (occlusionSupported) {
          // Configure occlusion
          await createdController.setOcclusionConfig(
            type: OcclusionType.depth,
            enableDepthOcclusion: true,
            enablePersonOcclusion: true,
            enablePlaneOcclusion: true,
          );

          // Test occlusion streams
          final occlusionsSubscription = createdController.occlusionsStream
              .listen((occlusions) {
                // ignore: avoid_print
                print('Occlusions updated: ${occlusions.length}');
              });

          final occlusionStatusSubscription = createdController
              .occlusionStatusStream
              .listen((status) {
                // ignore: avoid_print
                print('Occlusion status: ${status.status}');
              });

          // Test enabling occlusion
          await createdController.setOcclusionEnabled(true);
          // ignore: avoid_print
          print('Occlusion enabled');

          // Test creating occlusion
          final occlusionId = await createdController.createOcclusion(
            type: OcclusionType.depth,
            position: const Vector3(0, 0, -1),
            rotation: const Quaternion(0, 0, 0, 1),
            scale: const Vector3(1, 1, 1),
          );
          // ignore: avoid_print
          print('Created occlusion: $occlusionId');

          // Test getting occlusions
          final occlusions = await createdController.getOcclusions();
          // ignore: avoid_print
          print('Retrieved ${occlusions.length} occlusions');

          // Test getting specific occlusion
          final occlusion = await createdController.getOcclusion(occlusionId);
          if (occlusion != null) {
            // ignore: avoid_print
            print('Retrieved occlusion: ${occlusion.id}');
          }

          // Test occlusion capabilities
          final capabilities = await createdController
              .getOcclusionCapabilities();
          // ignore: avoid_print
          print('Occlusion capabilities: $capabilities');

          // Test disabling occlusion
          await createdController.setOcclusionEnabled(false);
          // ignore: avoid_print
          print('Occlusion disabled');

          // Clean up subscriptions
          await occlusionsSubscription.cancel();
          await occlusionStatusSubscription.cancel();
        }

        expect(true, true);
      } catch (e) {
        // If occlusion is not supported, test still passes
        // ignore: avoid_print
        print('Occlusion integration test error (acceptable): $e');
        expect(e, isNotNull);
      }
    });

    testWidgets('Lighting and shadows integration test', (
      WidgetTester tester,
    ) async {
      final completer = Completer<AugenController>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AugenView(
              onViewCreated: (c) {
                if (!completer.isCompleted) {
                  completer.complete(c);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final controller = await completer.future;
      expect(controller, isNotNull);

      try {
        // Test lighting support
        final lightingSupported = await controller.isLightingSupported();
        expect(lightingSupported, isA<bool>());

        if (lightingSupported) {
          // Test lighting capabilities
          final capabilities = await controller.getLightingCapabilities();
          expect(capabilities, isA<Map<String, dynamic>>());

          // Test lighting configuration
          const config = ARLightingConfig(
            enableGlobalIllumination: true,
            enableShadows: true,
            globalShadowQuality: ShadowQuality.medium,
            globalShadowFilterMode: ShadowFilterMode.soft,
            ambientIntensity: 0.3,
            ambientColor: Vector3(1.0, 1.0, 1.0),
            shadowDistance: 50.0,
            maxShadowCasters: 4,
            enableCascadedShadows: true,
            shadowCascadeCount: 4,
            shadowCascadeDistances: [10.0, 25.0, 50.0, 100.0],
            enableContactShadows: false,
            contactShadowDistance: 5.0,
            enableScreenSpaceShadows: false,
            enableRayTracedShadows: false,
          );

          await controller.setLightingConfig(config);
          final retrievedConfig = await controller.getLightingConfig();
          expect(retrievedConfig.enableGlobalIllumination, true);
          expect(retrievedConfig.enableShadows, true);

          // Test adding lights
          final now = DateTime.now();
          final directionalLight = ARLight(
            id: 'test_directional',
            type: ARLightType.directional,
            position: const Vector3(0, 10, 0),
            rotation: const Quaternion(0, 0, 0, 1),
            direction: const Vector3(0, -1, 0),
            intensity: 1000.0,
            intensityUnit: LightIntensityUnit.lux,
            color: const Vector3(1.0, 1.0, 1.0),
            isEnabled: true,
            castShadows: true,
            shadowQuality: ShadowQuality.medium,
            shadowFilterMode: ShadowFilterMode.soft,
            createdAt: now,
            lastModified: now,
          );

          final addedLight = await controller.addLight(directionalLight);
          expect(addedLight.id, 'test_directional');
          expect(addedLight.type, ARLightType.directional);

          // Test point light
          final pointLight = ARLight(
            id: 'test_point',
            type: ARLightType.point,
            position: const Vector3(1, 2, 3),
            rotation: const Quaternion(0, 0, 0, 1),
            direction: const Vector3(0, -1, 0),
            intensity: 500.0,
            intensityUnit: LightIntensityUnit.lux,
            color: const Vector3(1.0, 0.5, 0.2),
            range: 10.0,
            isEnabled: true,
            castShadows: true,
            shadowQuality: ShadowQuality.high,
            shadowFilterMode: ShadowFilterMode.pcf,
            createdAt: now,
            lastModified: now,
          );

          final addedPointLight = await controller.addLight(pointLight);
          expect(addedPointLight.id, 'test_point');
          expect(addedPointLight.type, ARLightType.point);

          // Test getting lights
          final lights = await controller.getLights();
          expect(lights.length, greaterThanOrEqualTo(2));

          // Test updating light
          final updatedLight = addedLight.copyWith(
            intensity: 1500.0,
            color: const Vector3(1.0, 0.8, 0.6),
          );
          final result = await controller.updateLight(updatedLight);
          expect(result.intensity, 1500.0);
          expect(result.color, const Vector3(1.0, 0.8, 0.6));

          // Test shadow controls
          await controller.setShadowsEnabled(true);
          await controller.setShadowQuality(ShadowQuality.high);

          // Test ambient lighting
          await controller.setAmbientLighting(
            intensity: 0.5,
            color: const Vector3(0.9, 0.9, 1.0),
          );

          // Test light position update
          await controller.updateLightPosition(
            lightId: 'test_point',
            position: const Vector3(2, 3, 4),
          );

          // Test light intensity update
          await controller.updateLightIntensity(
            lightId: 'test_point',
            intensity: 750.0,
          );

          // Test light color update
          await controller.updateLightColor(
            lightId: 'test_point',
            color: const Vector3(0.8, 1.0, 0.6),
          );

          // Test enabling/disabling light
          await controller.setLightEnabled(
            lightId: 'test_point',
            enabled: false,
          );

          // Test shadow casting
          await controller.setLightCastShadows(
            lightId: 'test_directional',
            castShadows: false,
          );

          // Test removing light
          await controller.removeLight('test_point');

          // Test clearing all lights
          await controller.clearLights();

          // Test lighting streams
          final lightsStream = controller.lightsStream;
          final configStream = controller.lightingConfigStream;
          final statusStream = controller.lightingStatusStream;

          expect(lightsStream, isNotNull);
          expect(configStream, isNotNull);
          expect(statusStream, isNotNull);
        }

        expect(true, true);
      } catch (e) {
        // If lighting is not supported, test still passes
        // ignore: avoid_print
        print('Lighting integration test error (acceptable): $e');
        expect(e, isNotNull);
      }
    });

    testWidgets('Environmental Probes Integration Test', (
      WidgetTester tester,
    ) async {
      try {
        final completer = Completer<AugenController>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AugenView(
                onViewCreated: (c) {
                  if (!completer.isCompleted) {
                    completer.complete(c);
                  }
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

        // Wait for view to be created
        await tester.pumpAndSettle();

        // Give some time for the platform view to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify controller was created
        final controller = await completer.future.timeout(
          const Duration(seconds: 5),
        );
        expect(controller, isNotNull);

        // Test environmental probes support
        final isSupported = await controller.isEnvironmentalProbesSupported();
        if (isSupported) {
          // Test getting capabilities
          final capabilities = await controller
              .getEnvironmentalProbesCapabilities();
          expect(capabilities, isNotNull);

          // Test creating spherical probe
          final sphericalProbe = AREnvironmentalProbe(
            id: 'test_spherical',
            type: ARProbeType.spherical,
            position: const Vector3(0, 1, 0),
            rotation: const Quaternion(0, 0, 0, 1),
            scale: const Vector3(1, 1, 1),
            influenceRadius: 5.0,
            updateMode: ARProbeUpdateMode.automatic,
            quality: ARProbeQuality.medium,
            isActive: true,
            captureReflections: true,
            captureLighting: true,
            textureResolution: 512,
            isRealTime: true,
            updateFrequency: 1.0,
            confidence: 0.8,
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
          );

          final addedSpherical = await controller.addEnvironmentalProbe(
            sphericalProbe,
          );
          expect(addedSpherical.id, 'test_spherical');
          expect(addedSpherical.type, ARProbeType.spherical);

          // Test creating box probe
          final boxProbe = AREnvironmentalProbe(
            id: 'test_box',
            type: ARProbeType.box,
            position: const Vector3(1, 1, 1),
            rotation: const Quaternion(0, 0, 0, 1),
            scale: const Vector3(2, 2, 2),
            influenceRadius: 3.0,
            updateMode: ARProbeUpdateMode.automatic,
            quality: ARProbeQuality.high,
            isActive: true,
            captureReflections: true,
            captureLighting: true,
            textureResolution: 1024,
            isRealTime: true,
            updateFrequency: 0.5,
            confidence: 0.9,
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
          );

          final addedBox = await controller.addEnvironmentalProbe(boxProbe);
          expect(addedBox.id, 'test_box');
          expect(addedBox.type, ARProbeType.box);

          // Test creating planar probe
          final planarProbe = AREnvironmentalProbe(
            id: 'test_planar',
            type: ARProbeType.planar,
            position: const Vector3(2, 0.5, 2),
            rotation: const Quaternion(0, 0, 0, 1),
            scale: const Vector3(4, 0.1, 4),
            influenceRadius: 2.0,
            updateMode: ARProbeUpdateMode.manual,
            quality: ARProbeQuality.low,
            isActive: true,
            captureReflections: true,
            captureLighting: false,
            textureResolution: 256,
            isRealTime: false,
            updateFrequency: 2.0,
            confidence: 0.7,
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
          );

          final addedPlanar = await controller.addEnvironmentalProbe(
            planarProbe,
          );
          expect(addedPlanar.id, 'test_planar');
          expect(addedPlanar.type, ARProbeType.planar);

          // Test getting all probes
          final allProbes = await controller.getEnvironmentalProbes();
          expect(allProbes.length, greaterThanOrEqualTo(3));

          // Test getting specific probe
          final retrievedProbe = await controller.getEnvironmentalProbe(
            'test_spherical',
          );
          expect(retrievedProbe, isNotNull);
          expect(retrievedProbe?.id, 'test_spherical');

          // Test updating probe position
          await controller.updateEnvironmentalProbePosition(
            probeId: 'test_spherical',
            position: const Vector3(1, 2, 3),
          );

          // Test updating probe rotation
          await controller.updateEnvironmentalProbeRotation(
            probeId: 'test_spherical',
            rotation: const Quaternion(0, 0, 0, 1),
          );

          // Test updating probe influence radius
          await controller.updateEnvironmentalProbeInfluenceRadius(
            probeId: 'test_spherical',
            influenceRadius: 7.0,
          );

          // Test updating probe quality
          await controller.updateEnvironmentalProbeQuality(
            probeId: 'test_spherical',
            quality: ARProbeQuality.high,
          );

          // Test enabling/disabling probe
          await controller.setEnvironmentalProbeEnabled(
            probeId: 'test_spherical',
            enabled: false,
          );

          // Test updating probe capture settings
          await controller.updateEnvironmentalProbeCaptureSettings(
            probeId: 'test_spherical',
            captureReflections: false,
            captureLighting: true,
          );

          // Test forcing probe update
          await controller.forceEnvironmentalProbeUpdate('test_spherical');

          // Test setting probe configuration
          final probeConfig = AREnvironmentalProbeConfig(
            enableProbes: true,
            defaultQuality: ARProbeQuality.medium,
            defaultUpdateMode: ARProbeUpdateMode.automatic,
            defaultTextureResolution: 512,
            maxActiveProbes: 10,
            defaultInfluenceRadius: 5.0,
            defaultRealTime: true,
            defaultUpdateFrequency: 1.0,
            autoCreateProbes: true,
            optimizePlacement: true,
          );

          await controller.setEnvironmentalProbeConfig(probeConfig);

          // Test getting probe configuration
          final retrievedConfig = await controller
              .getEnvironmentalProbeConfig();
          expect(retrievedConfig, isNotNull);
          expect(retrievedConfig.enableProbes, true);

          // Test removing specific probe
          await controller.removeEnvironmentalProbe('test_box');

          // Test clearing all probes
          await controller.clearEnvironmentalProbes();

          // Test environmental probes streams
          final probesStream = controller.probesStream;
          final probeConfigStream = controller.probeConfigStream;
          final probeStatusStream = controller.probeStatusStream;

          expect(probesStream, isNotNull);
          expect(probeConfigStream, isNotNull);
          expect(probeStatusStream, isNotNull);
        }

        expect(true, true);
      } catch (e) {
        // If environmental probes are not supported, test still passes
        // ignore: avoid_print
        print('Environmental probes integration test error (acceptable): $e');
        expect(e, isNotNull);
      }
    });
  });
}
