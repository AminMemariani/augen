import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Controller lifecycle', () {
    test('creating a controller does not throw', () {
      expect(() => AugenController(100), returnsNormally);
      AugenController(100).dispose();
    });

    test('dispose can be called without prior initialization', () {
      final controller = AugenController(101);
      expect(() => controller.dispose(), returnsNormally);
    });

    test('dispose can be called multiple times safely', () {
      final controller = AugenController(102);
      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
    });

    test('dispose closes all stream controllers (streams complete)', () async {
      final controller = AugenController(103);

      // Listen to several streams and check they complete after dispose
      final planesDone = Completer<void>();
      final anchorsDone = Completer<void>();
      final errorsDone = Completer<void>();

      controller.planesStream.listen(
        null,
        onDone: () => planesDone.complete(),
      );
      controller.anchorsStream.listen(
        null,
        onDone: () => anchorsDone.complete(),
      );
      controller.errorStream.listen(
        null,
        onDone: () => errorsDone.complete(),
      );

      controller.dispose();

      await planesDone.future.timeout(const Duration(seconds: 1));
      await anchorsDone.future.timeout(const Duration(seconds: 1));
      await errorsDone.future.timeout(const Duration(seconds: 1));
    });

    test('mutation methods after dispose throw StateError', () {
      final controller = AugenController(104);
      controller.dispose();

      // Mutation methods that change AR state still throw — callers should
      // guard with `controller.isDisposed` first.
      expect(
        () => controller.initialize(const ARSessionConfig()),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.pause(), throwsA(isA<StateError>()));
      expect(() => controller.resume(), throwsA(isA<StateError>()));
      expect(() => controller.reset(), throwsA(isA<StateError>()));
      expect(
        () => controller.addNode(
          ARNode(id: 'n', type: NodeType.sphere, position: Vector3.zero()),
        ),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.removeNode('n'), throwsA(isA<StateError>()));
      expect(() => controller.hitTest(0, 0), throwsA(isA<StateError>()));
      expect(
        () => controller.addAnchor(Vector3.zero()),
        throwsA(isA<StateError>()),
      );
      expect(
        () => controller.removeAnchor('a'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'support checks after dispose return false safely (no throw)',
      () async {
        final controller = AugenController(105);
        controller.dispose();

        expect(controller.isDisposed, isTrue);

        // All support-check methods must gracefully return false instead of
        // throwing — UI toggle callbacks rely on this when racing dispose.
        expect(await controller.isARSupported(), isFalse);
        expect(await controller.isCloudAnchorsSupported(), isFalse);
        expect(await controller.isPhysicsSupported(), isFalse);
        expect(await controller.isOcclusionSupported(), isFalse);
        expect(await controller.isLightingSupported(), isFalse);
        expect(await controller.isEnvironmentalProbesSupported(), isFalse);
        expect(await controller.isMultiUserSupported(), isFalse);
        expect(await controller.isFaceTrackingEnabled(), isFalse);
        expect(await controller.isImageTrackingEnabled(), isFalse);
      },
    );

    test(
      'feature toggles after dispose return false safely (no throw)',
      () async {
        final controller = AugenController(106);
        controller.dispose();

        // Toggle methods are user-facing UI callbacks — must never throw
        // when fired after a tab switch / widget disposal.
        expect(await controller.setImageTrackingEnabled(true), isFalse);
        expect(await controller.setImageTrackingEnabled(false), isFalse);
        expect(await controller.setFaceTrackingEnabled(true), isFalse);
        expect(await controller.setFaceTrackingEnabled(false), isFalse);
      },
    );

    test('isDisposed is true after dispose and false before', () {
      final controller = AugenController(107);
      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
      // Idempotent
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });

    test('multiple controllers with different viewIds work independently',
        () async {
      final controller1 = AugenController(200);
      final controller2 = AugenController(201);
      final channel1 = MethodChannel('augen_200');
      final channel2 = MethodChannel('augen_201');

      String? lastMethodOn1;
      String? lastMethodOn2;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel1, (MethodCall call) async {
        lastMethodOn1 = call.method;
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel2, (MethodCall call) async {
        lastMethodOn2 = call.method;
        return null;
      });

      await controller1.pause();
      expect(lastMethodOn1, 'pause');
      expect(lastMethodOn2, isNull); // controller2 not called

      await controller2.resume();
      expect(lastMethodOn2, 'resume');
      expect(lastMethodOn1, 'pause'); // controller1 unchanged

      expect(controller1.viewId, 200);
      expect(controller2.viewId, 201);

      controller1.dispose();
      controller2.dispose();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel1, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel2, null);
    });
  });
}
