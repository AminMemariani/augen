// Tests for graceful handling of missing native implementations and
// disposed-controller calls on support-check + toggle methods.
//
// These cover the bug reports where iOS users saw:
//   - MissingPluginException(No implementation found for method
//     isEnvironmentalProbesSupported on channel augen_0)
//   - MissingPluginException(No implementation found for method
//     isCloudAnchorsSupported on channel augen_0)
//   - Bad state: Controller is disposed (from feature toggles fired during
//     tab switches)
//
// The package contract is now:
//   1. Support-check methods (`isXxxSupported`, `isXxxEnabled`) NEVER throw.
//      They return `false` when the platform doesn't implement them, the
//      controller is disposed, or any other error occurs.
//   2. Toggle methods (`setImageTrackingEnabled`, `setFaceTrackingEnabled`)
//      NEVER throw on disposed/missing — they return `false` and surface
//      the error via `errorStream`.
//   3. Mutation methods that modify AR scene state still throw `StateError`
//      after dispose — callers should guard with `controller.isDisposed`.

import 'package:augen/augen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Support checks tolerate missing native implementations', () {
    late AugenController controller;
    late MethodChannel channel;

    setUp(() {
      controller = AugenController(900);
      channel = MethodChannel('augen_900');
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (!controller.isDisposed) controller.dispose();
    });

    void mockMissingPlugin() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException(
              'No implementation found for method ${call.method}',
            );
          });
    }

    test('isCloudAnchorsSupported returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isCloudAnchorsSupported(), isFalse);
    });

    test(
      'isEnvironmentalProbesSupported returns false on MissingPluginException',
      () async {
        mockMissingPlugin();
        expect(await controller.isEnvironmentalProbesSupported(), isFalse);
      },
    );

    test('isPhysicsSupported returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isPhysicsSupported(), isFalse);
    });

    test('isOcclusionSupported returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isOcclusionSupported(), isFalse);
    });

    test('isLightingSupported returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isLightingSupported(), isFalse);
    });

    test('isMultiUserSupported returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isMultiUserSupported(), isFalse);
    });

    test('isARSupported returns false on MissingPluginException', () async {
      mockMissingPlugin();
      expect(await controller.isARSupported(), isFalse);
    });

    test('isFaceTrackingEnabled returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isFaceTrackingEnabled(), isFalse);
    });

    test('isImageTrackingEnabled returns false on MissingPluginException',
        () async {
      mockMissingPlugin();
      expect(await controller.isImageTrackingEnabled(), isFalse);
    });

    test('support checks survive PlatformException across all 7 checks',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'NATIVE_BOOM', message: 'kaboom');
          });
      expect(await controller.isARSupported(), isFalse);
      expect(await controller.isCloudAnchorsSupported(), isFalse);
      expect(await controller.isOcclusionSupported(), isFalse);
      expect(await controller.isPhysicsSupported(), isFalse);
      expect(await controller.isMultiUserSupported(), isFalse);
      expect(await controller.isLightingSupported(), isFalse);
      expect(await controller.isEnvironmentalProbesSupported(), isFalse);
      expect(await controller.isImageTrackingEnabled(), isFalse);
      expect(await controller.isFaceTrackingEnabled(), isFalse);
    });

    test('support checks survive UnsupportedError across all 7 checks',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw UnsupportedError('not on this platform');
          });
      expect(await controller.isARSupported(), isFalse);
      expect(await controller.isCloudAnchorsSupported(), isFalse);
      expect(await controller.isOcclusionSupported(), isFalse);
      expect(await controller.isPhysicsSupported(), isFalse);
      expect(await controller.isMultiUserSupported(), isFalse);
      expect(await controller.isLightingSupported(), isFalse);
      expect(await controller.isEnvironmentalProbesSupported(), isFalse);
      expect(await controller.isImageTrackingEnabled(), isFalse);
      expect(await controller.isFaceTrackingEnabled(), isFalse);
    });

    test('support checks pass through real boolean values', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'isARSupported':
                return true;
              case 'isPhysicsSupported':
                return true;
              case 'isCloudAnchorsSupported':
                return false;
              default:
                return null;
            }
          });
      expect(await controller.isARSupported(), isTrue);
      expect(await controller.isPhysicsSupported(), isTrue);
      expect(await controller.isCloudAnchorsSupported(), isFalse);
    });
  });

  group('Feature toggles tolerate disposal and missing implementations', () {
    test('setImageTrackingEnabled returns false on disposed controller',
        () async {
      final controller = AugenController(901);
      controller.dispose();

      // Must not throw — user-facing UI toggle.
      expect(await controller.setImageTrackingEnabled(true), isFalse);
      expect(await controller.setImageTrackingEnabled(false), isFalse);
    });

    test('setFaceTrackingEnabled returns false on disposed controller',
        () async {
      final controller = AugenController(902);
      controller.dispose();

      expect(await controller.setFaceTrackingEnabled(true), isFalse);
      expect(await controller.setFaceTrackingEnabled(false), isFalse);
    });

    test(
      'toggles surface errors via errorStream on MissingPluginException',
      () async {
        final controller = AugenController(903);
        final channel = MethodChannel('augen_903');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw MissingPluginException('No impl for ${call.method}');
            });

        final errors = <String>[];
        final sub = controller.errorStream.listen(errors.add);

        final ok = await controller.setImageTrackingEnabled(true);
        expect(ok, isFalse);

        // Give the error stream a microtask to deliver.
        await Future<void>.delayed(Duration.zero);
        expect(
          errors.any((e) => e.contains('Image tracking')),
          isTrue,
          reason: 'errorStream should surface the failure to the UI',
        );

        await sub.cancel();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        controller.dispose();
      },
    );

    test(
      'toggles surface errors via errorStream on PlatformException',
      () async {
        final controller = AugenController(907);
        final channel = MethodChannel('augen_907');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(code: 'BOOM', message: 'native explosion');
            });

        final errors = <String>[];
        final sub = controller.errorStream.listen(errors.add);

        expect(await controller.setImageTrackingEnabled(true), isFalse);
        expect(await controller.setFaceTrackingEnabled(true), isFalse);

        await Future<void>.delayed(Duration.zero);
        expect(errors.length, greaterThanOrEqualTo(2));
        expect(errors.any((e) => e.contains('failed')), isTrue);

        await sub.cancel();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        controller.dispose();
      },
    );

    test(
      'toggles surface errors via errorStream on UnsupportedError',
      () async {
        final controller = AugenController(908);
        final channel = MethodChannel('augen_908');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw UnsupportedError('not on web');
            });

        final errors = <String>[];
        final sub = controller.errorStream.listen(errors.add);

        expect(await controller.setImageTrackingEnabled(true), isFalse);

        await Future<void>.delayed(Duration.zero);
        // Note: errors thrown inside a method-channel mock handler are
        // wrapped by the Flutter binding into a PlatformException before
        // they reach the controller, so the toggle reports a generic
        // failure rather than the "not supported" branch. Either way,
        // the contract is satisfied: it didn't throw and surfaced an error.
        expect(errors, isNotEmpty);

        await sub.cancel();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        controller.dispose();
      },
    );

    test(
      'toggles return true on successful native call',
      () async {
        final controller = AugenController(904);
        final channel = MethodChannel('augen_904');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'setImageTrackingEnabled' ||
                  call.method == 'setFaceTrackingEnabled') {
                return null;
              }
              return null;
            });

        expect(await controller.setImageTrackingEnabled(true), isTrue);
        expect(await controller.setFaceTrackingEnabled(false), isTrue);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        controller.dispose();
      },
    );
  });

  group('isDisposed getter', () {
    test('starts false and becomes true after dispose', () {
      final controller = AugenController(905);
      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });

    test('dispose is idempotent', () {
      final controller = AugenController(906);
      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
      expect(controller.isDisposed, isTrue);
    });
  });
}
