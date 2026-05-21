import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('ARMarkerTrackingState', () {
    test('has expected values', () {
      expect(ARMarkerTrackingState.values, [
        ARMarkerTrackingState.tracked,
        ARMarkerTrackingState.notTracked,
        ARMarkerTrackingState.paused,
        ARMarkerTrackingState.failed,
      ]);
    });
  });

  group('ARTrackedMarker', () {
    final testTime = DateTime(2025, 1, 15, 12, 0, 0);
    final testCorners = [
      const Vector2(0, 0),
      const Vector2(1, 0),
      const Vector2(1, 1),
      const Vector2(0, 1),
    ];
    final testTransform = List.generate(16, (i) => i.toDouble());

    ARTrackedMarker createMarker({
      ARMarkerTrackingState state = ARMarkerTrackingState.tracked,
      double confidence = 0.9,
    }) {
      return ARTrackedMarker(
        id: 'tracked-1',
        targetId: 'target-1',
        type: ARMarkerType.aruco,
        position: const Vector3(1.0, 2.0, 3.0),
        rotation: const Quaternion(0.0, 0.0, 0.0, 1.0),
        transform: testTransform,
        corners: testCorners,
        confidence: confidence,
        trackingState: state,
        lastUpdated: testTime,
      );
    }

    test('construction', () {
      final m = createMarker();
      expect(m.id, 'tracked-1');
      expect(m.targetId, 'target-1');
      expect(m.type, ARMarkerType.aruco);
      expect(m.position, const Vector3(1.0, 2.0, 3.0));
      expect(m.rotation, const Quaternion(0.0, 0.0, 0.0, 1.0));
      expect(m.transform.length, 16);
      expect(m.corners.length, 4);
      expect(m.confidence, 0.9);
      expect(m.trackingState, ARMarkerTrackingState.tracked);
      expect(m.lastUpdated, testTime);
    });

    test('isTracked returns true only for tracked state', () {
      expect(createMarker(state: ARMarkerTrackingState.tracked).isTracked, true);
      expect(createMarker(state: ARMarkerTrackingState.notTracked).isTracked, false);
      expect(createMarker(state: ARMarkerTrackingState.paused).isTracked, false);
      expect(createMarker(state: ARMarkerTrackingState.failed).isTracked, false);
    });

    test('isReliable requires tracked AND confidence > 0.7', () {
      expect(createMarker(state: ARMarkerTrackingState.tracked, confidence: 0.9).isReliable, true);
      expect(createMarker(state: ARMarkerTrackingState.tracked, confidence: 0.71).isReliable, true);
      expect(createMarker(state: ARMarkerTrackingState.tracked, confidence: 0.7).isReliable, false);
      expect(createMarker(state: ARMarkerTrackingState.tracked, confidence: 0.5).isReliable, false);
      expect(createMarker(state: ARMarkerTrackingState.notTracked, confidence: 0.9).isReliable, false);
    });

    test('toMap produces correct map', () {
      final map = createMarker().toMap();
      expect(map['id'], 'tracked-1');
      expect(map['targetId'], 'target-1');
      expect(map['type'], 'aruco');
      expect(map['trackingState'], 'tracked');
      expect(map['confidence'], 0.9);
      expect(map['lastUpdated'], testTime.millisecondsSinceEpoch);
      expect((map['transform'] as List).length, 16);
      expect((map['corners'] as List).length, 4);
    });

    test('fromMap parses correctly', () {
      final map = createMarker().toMap();
      final restored = ARTrackedMarker.fromMap(map);
      expect(restored.id, 'tracked-1');
      expect(restored.targetId, 'target-1');
      expect(restored.type, ARMarkerType.aruco);
      expect(restored.trackingState, ARMarkerTrackingState.tracked);
      expect(restored.confidence, 0.9);
    });

    test('toMap/fromMap round-trip', () {
      final original = createMarker();
      final restored = ARTrackedMarker.fromMap(original.toMap());
      expect(restored, original);
    });

    test('corners list preservation', () {
      final m = createMarker();
      final map = m.toMap();
      final restored = ARTrackedMarker.fromMap(map);
      expect(restored.corners.length, 4);
      expect(restored.corners[0], const Vector2(0, 0));
      expect(restored.corners[2], const Vector2(1, 1));
    });

    test('transform list 16 elements', () {
      final m = createMarker();
      expect(m.transform.length, 16);
      final restored = ARTrackedMarker.fromMap(m.toMap());
      expect(restored.transform.length, 16);
      expect(restored.transform[15], 15.0);
    });

    test('DateTime serialization', () {
      final m = createMarker();
      final map = m.toMap();
      expect(map['lastUpdated'], testTime.millisecondsSinceEpoch);
      final restored = ARTrackedMarker.fromMap(map);
      expect(restored.lastUpdated, testTime);
    });

    test('enum parsing - tracking states', () {
      for (final entry in {
        'tracked': ARMarkerTrackingState.tracked,
        'nottracked': ARMarkerTrackingState.notTracked,
        'not_tracked': ARMarkerTrackingState.notTracked,
        'paused': ARMarkerTrackingState.paused,
        'failed': ARMarkerTrackingState.failed,
        'unknown': ARMarkerTrackingState.notTracked,
      }.entries) {
        final base = createMarker().toMap();
        base['trackingState'] = entry.key;
        final m = ARTrackedMarker.fromMap(base);
        expect(m.trackingState, entry.value, reason: 'state: ${entry.key}');
      }
    });

    test('enum parsing - marker types', () {
      for (final entry in {
        'pattern': ARMarkerType.pattern,
        'PATTERN': ARMarkerType.pattern,
        'barcode': ARMarkerType.barcode,
        'aruco': ARMarkerType.aruco,
        'unknown': ARMarkerType.pattern,
      }.entries) {
        final base = createMarker().toMap();
        base['type'] = entry.key;
        final m = ARTrackedMarker.fromMap(base);
        expect(m.type, entry.value, reason: 'type: ${entry.key}');
      }
    });

    test('equality and hashCode', () {
      final a = createMarker();
      final b = createMarker();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality', () {
      final a = createMarker();
      final b = createMarker(confidence: 0.5);
      expect(a, isNot(b));
    });
  });
}
