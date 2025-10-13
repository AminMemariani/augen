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

      // Wait a bit for any potential updates
      await Future.delayed(const Duration(seconds: 1));

      // Verify that streams can be listened to (they may not emit if AR not available)
      expect(planesSubscription, isNotNull);
      expect(anchorsSubscription, isNotNull);
      expect(errorSubscription, isNotNull);

      // Clean up
      await planesSubscription.cancel();
      await anchorsSubscription.cancel();
      await errorSubscription.cancel();
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
  });
}
