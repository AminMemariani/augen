import 'package:flutter_test/flutter_test.dart';
import 'package:augen/src/models/ar_image_target.dart';
import 'package:augen/src/models/ar_tracked_image.dart';
import 'package:augen/src/models/vector3.dart';
import 'package:augen/src/models/quaternion.dart';

void main() {
  group('ImageTargetSize', () {
    test('creates with correct dimensions', () {
      const size = ImageTargetSize(10.0, 20.0);
      expect(size.width, 10.0);
      expect(size.height, 20.0);
    });

    test('serializes to map correctly', () {
      const size = ImageTargetSize(15.5, 25.5);
      final map = size.toMap();
      expect(map['width'], 15.5);
      expect(map['height'], 25.5);
    });

    test('deserializes from map correctly', () {
      final map = {'width': 30.0, 'height': 40.0};
      final size = ImageTargetSize.fromMap(map);
      expect(size.width, 30.0);
      expect(size.height, 40.0);
    });

    test('equality works correctly', () {
      const size1 = ImageTargetSize(10.0, 20.0);
      const size2 = ImageTargetSize(10.0, 20.0);
      const size3 = ImageTargetSize(10.0, 30.0);

      expect(size1, equals(size2));
      expect(size1, isNot(equals(size3)));
    });

    test('toString works correctly', () {
      const size = ImageTargetSize(10.0, 20.0);
      expect(size.toString(), 'ImageTargetSize(10.0 x 20.0)');
    });
  });

  group('ARImageTarget', () {
    late ARImageTarget target;
    late ImageTargetSize size;

    setUp(() {
      size = const ImageTargetSize(10.0, 20.0);
      target = ARImageTarget(
        id: 'target1',
        name: 'Test Target',
        imagePath: 'assets/images/test.jpg',
        physicalSize: size,
        isActive: true,
      );
    });

    test('creates with correct properties', () {
      expect(target.id, 'target1');
      expect(target.name, 'Test Target');
      expect(target.imagePath, 'assets/images/test.jpg');
      expect(target.physicalSize, size);
      expect(target.isActive, true);
    });

    test('creates with default isActive value', () {
      final target2 = ARImageTarget(
        id: 'target2',
        name: 'Test Target 2',
        imagePath: 'assets/images/test2.jpg',
        physicalSize: size,
      );
      expect(target2.isActive, true);
    });

    test('serializes to map correctly', () {
      final map = target.toMap();
      expect(map['id'], 'target1');
      expect(map['name'], 'Test Target');
      expect(map['imagePath'], 'assets/images/test.jpg');
      expect(map['physicalSize']['width'], 10.0);
      expect(map['physicalSize']['height'], 20.0);
      expect(map['isActive'], true);
    });

    test('deserializes from map correctly', () {
      final map = {
        'id': 'target2',
        'name': 'Test Target 2',
        'imagePath': 'assets/images/test2.jpg',
        'physicalSize': {'width': 15.0, 'height': 25.0},
        'isActive': false,
      };
      final target2 = ARImageTarget.fromMap(map);
      expect(target2.id, 'target2');
      expect(target2.name, 'Test Target 2');
      expect(target2.imagePath, 'assets/images/test2.jpg');
      expect(target2.physicalSize.width, 15.0);
      expect(target2.physicalSize.height, 25.0);
      expect(target2.isActive, false);
    });

    test('deserializes with default isActive when missing', () {
      final map = {
        'id': 'target3',
        'name': 'Test Target 3',
        'imagePath': 'assets/images/test3.jpg',
        'physicalSize': {'width': 20.0, 'height': 30.0},
      };
      final target3 = ARImageTarget.fromMap(map);
      expect(target3.isActive, true);
    });

    test('equality works correctly', () {
      final target2 = ARImageTarget(
        id: 'target1',
        name: 'Test Target',
        imagePath: 'assets/images/test.jpg',
        physicalSize: size,
        isActive: true,
      );
      final target3 = ARImageTarget(
        id: 'target2',
        name: 'Test Target',
        imagePath: 'assets/images/test.jpg',
        physicalSize: size,
        isActive: true,
      );

      expect(target, equals(target2));
      expect(target, isNot(equals(target3)));
    });

    test('toString works correctly', () {
      expect(
        target.toString(),
        'ARImageTarget(id: target1, name: Test Target, size: ImageTargetSize(10.0 x 20.0))',
      );
    });
  });

  group('ImageTrackingState', () {
    test('has correct enum values', () {
      expect(ImageTrackingState.values, [
        ImageTrackingState.tracked,
        ImageTrackingState.notTracked,
        ImageTrackingState.paused,
        ImageTrackingState.failed,
      ]);
    });
  });

  group('ARTrackedImage', () {
    late ARTrackedImage trackedImage;
    late ImageTargetSize size;

    setUp(() {
      size = const ImageTargetSize(10.0, 20.0);
      trackedImage = ARTrackedImage(
        id: 'tracked1',
        targetId: 'target1',
        position: const Vector3(1.0, 2.0, 3.0),
        rotation: const Quaternion(0.0, 0.0, 0.0, 1.0),
        estimatedSize: size,
        trackingState: ImageTrackingState.tracked,
        confidence: 0.85,
        lastUpdated: DateTime(2023, 1, 1, 12, 0, 0),
      );
    });

    test('creates with correct properties', () {
      expect(trackedImage.id, 'tracked1');
      expect(trackedImage.targetId, 'target1');
      expect(trackedImage.position, const Vector3(1.0, 2.0, 3.0));
      expect(trackedImage.rotation, const Quaternion(0.0, 0.0, 0.0, 1.0));
      expect(trackedImage.estimatedSize, size);
      expect(trackedImage.trackingState, ImageTrackingState.tracked);
      expect(trackedImage.confidence, 0.85);
      expect(trackedImage.lastUpdated, DateTime(2023, 1, 1, 12, 0, 0));
    });

    test('isTracked getter works correctly', () {
      expect(trackedImage.isTracked, true);

      final notTracked = ARTrackedImage(
        id: 'tracked2',
        targetId: 'target2',
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        estimatedSize: size,
        trackingState: ImageTrackingState.notTracked,
        confidence: 0.0,
        lastUpdated: DateTime.now(),
      );
      expect(notTracked.isTracked, false);
    });

    test('isReliable getter works correctly', () {
      expect(trackedImage.isReliable, true); // confidence > 0.7

      final unreliable = ARTrackedImage(
        id: 'tracked2',
        targetId: 'target2',
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        estimatedSize: size,
        trackingState: ImageTrackingState.tracked,
        confidence: 0.5, // < 0.7
        lastUpdated: DateTime.now(),
      );
      expect(unreliable.isReliable, false);
    });

    test('serializes to map correctly', () {
      final map = trackedImage.toMap();
      expect(map['id'], 'tracked1');
      expect(map['targetId'], 'target1');
      expect(map['position']['x'], 1.0);
      expect(map['position']['y'], 2.0);
      expect(map['position']['z'], 3.0);
      expect(map['rotation']['x'], 0.0);
      expect(map['rotation']['y'], 0.0);
      expect(map['rotation']['z'], 0.0);
      expect(map['rotation']['w'], 1.0);
      expect(map['estimatedSize']['width'], 10.0);
      expect(map['estimatedSize']['height'], 20.0);
      expect(map['trackingState'], 'tracked');
      expect(map['confidence'], 0.85);
      expect(
        map['lastUpdated'],
        DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
      );
    });

    test('deserializes from map correctly', () {
      final map = {
        'id': 'tracked2',
        'targetId': 'target2',
        'position': {'x': 2.0, 'y': 3.0, 'z': 4.0},
        'rotation': {'x': 0.1, 'y': 0.2, 'z': 0.3, 'w': 0.9},
        'estimatedSize': {'width': 15.0, 'height': 25.0},
        'trackingState': 'nottracked',
        'confidence': 0.3,
        'lastUpdated': DateTime(2023, 2, 1, 12, 0, 0).millisecondsSinceEpoch,
      };
      final tracked2 = ARTrackedImage.fromMap(map);
      expect(tracked2.id, 'tracked2');
      expect(tracked2.targetId, 'target2');
      expect(tracked2.position, const Vector3(2.0, 3.0, 4.0));
      expect(tracked2.rotation, const Quaternion(0.1, 0.2, 0.3, 0.9));
      expect(tracked2.estimatedSize.width, 15.0);
      expect(tracked2.estimatedSize.height, 25.0);
      expect(tracked2.trackingState, ImageTrackingState.notTracked);
      expect(tracked2.confidence, 0.3);
      expect(tracked2.lastUpdated, DateTime(2023, 2, 1, 12, 0, 0));
    });

    test('parses tracking states correctly', () {
      final states = [
        ('tracked', ImageTrackingState.tracked),
        ('nottracked', ImageTrackingState.notTracked),
        ('not_tracked', ImageTrackingState.notTracked),
        ('paused', ImageTrackingState.paused),
        ('failed', ImageTrackingState.failed),
        ('unknown', ImageTrackingState.notTracked), // default
      ];

      for (final (stateString, expectedState) in states) {
        final map = {
          'id': 'test',
          'targetId': 'target',
          'position': {'x': 0, 'y': 0, 'z': 0},
          'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
          'estimatedSize': {'width': 10, 'height': 10},
          'trackingState': stateString,
          'confidence': 0.5,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };
        final tracked = ARTrackedImage.fromMap(map);
        expect(
          tracked.trackingState,
          expectedState,
          reason: 'Failed for state: $stateString',
        );
      }
    });

    test('equality works correctly', () {
      final tracked2 = ARTrackedImage(
        id: 'tracked1',
        targetId: 'target1',
        position: const Vector3(1.0, 2.0, 3.0),
        rotation: const Quaternion(0.0, 0.0, 0.0, 1.0),
        estimatedSize: size,
        trackingState: ImageTrackingState.tracked,
        confidence: 0.85,
        lastUpdated: DateTime(2023, 1, 1, 12, 0, 0),
      );
      final tracked3 = ARTrackedImage(
        id: 'tracked2',
        targetId: 'target1',
        position: const Vector3(1.0, 2.0, 3.0),
        rotation: const Quaternion(0.0, 0.0, 0.0, 1.0),
        estimatedSize: size,
        trackingState: ImageTrackingState.tracked,
        confidence: 0.85,
        lastUpdated: DateTime(2023, 1, 1, 12, 0, 0),
      );

      expect(trackedImage, equals(tracked2));
      expect(trackedImage, isNot(equals(tracked3)));
    });

    test('toString works correctly', () {
      expect(
        trackedImage.toString(),
        'ARTrackedImage(id: tracked1, targetId: target1, state: ImageTrackingState.tracked, confidence: 85.0%)',
      );
    });
  });
}
