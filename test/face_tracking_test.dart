import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('FaceLandmark', () {
    test('creates with correct properties', () {
      final landmark = FaceLandmark(
        name: 'left_eye',
        position: const Vector3(0.1, 0.2, 0.3),
        confidence: 0.95,
      );

      expect(landmark.name, 'left_eye');
      expect(landmark.position, const Vector3(0.1, 0.2, 0.3));
      expect(landmark.confidence, 0.95);
    });

    test('converts to and from map', () {
      final landmark = FaceLandmark(
        name: 'nose_tip',
        position: const Vector3(0.0, 0.1, 0.2),
        confidence: 0.88,
      );

      final map = landmark.toMap();
      final restored = FaceLandmark.fromMap(map);

      expect(restored.name, landmark.name);
      expect(restored.position, landmark.position);
      expect(restored.confidence, landmark.confidence);
    });

    test('equality works correctly', () {
      final landmark1 = FaceLandmark(
        name: 'chin',
        position: const Vector3(0.0, -0.1, 0.0),
        confidence: 0.92,
      );

      final landmark2 = FaceLandmark(
        name: 'chin',
        position: const Vector3(0.0, -0.1, 0.0),
        confidence: 0.92,
      );

      final landmark3 = FaceLandmark(
        name: 'forehead',
        position: const Vector3(0.0, 0.2, 0.0),
        confidence: 0.85,
      );

      expect(landmark1, equals(landmark2));
      expect(landmark1, isNot(equals(landmark3)));
    });

    test('toString works correctly', () {
      final landmark = FaceLandmark(
        name: 'right_eye',
        position: const Vector3(-0.1, 0.2, 0.3),
        confidence: 0.91,
      );

      final str = landmark.toString();
      expect(str, contains('right_eye'));
      expect(str, contains('Vector3'));
      expect(str, contains('0.91'));
    });
  });

  group('FaceTrackingState', () {
    test('has correct enum values', () {
      expect(FaceTrackingState.values.length, 4);
      expect(FaceTrackingState.values, contains(FaceTrackingState.tracked));
      expect(FaceTrackingState.values, contains(FaceTrackingState.notTracked));
      expect(FaceTrackingState.values, contains(FaceTrackingState.paused));
      expect(FaceTrackingState.values, contains(FaceTrackingState.failed));
    });

    test('enum names are correct', () {
      expect(FaceTrackingState.tracked.name, 'tracked');
      expect(FaceTrackingState.notTracked.name, 'notTracked');
      expect(FaceTrackingState.paused.name, 'paused');
      expect(FaceTrackingState.failed.name, 'failed');
    });
  });

  group('ARFace', () {
    test('creates with correct properties', () {
      final landmarks = [
        FaceLandmark(
          name: 'left_eye',
          position: const Vector3(-0.05, 0.1, 0.0),
          confidence: 0.95,
        ),
        FaceLandmark(
          name: 'right_eye',
          position: const Vector3(0.05, 0.1, 0.0),
          confidence: 0.93,
        ),
      ];

      final face = ARFace(
        id: 'face_1',
        position: const Vector3(0.0, 0.0, -0.5),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.2, 0.3, 0.1),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.88,
        landmarks: landmarks,
        lastUpdated: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(face.id, 'face_1');
      expect(face.position, const Vector3(0.0, 0.0, -0.5));
      expect(face.rotation, const Quaternion(0, 0, 0, 1));
      expect(face.scale, const Vector3(0.2, 0.3, 0.1));
      expect(face.trackingState, FaceTrackingState.tracked);
      expect(face.confidence, 0.88);
      expect(face.landmarks, landmarks);
      expect(face.lastUpdated, DateTime(2024, 1, 1, 12, 0, 0));
    });

    test('computed properties work correctly', () {
      final face = ARFace(
        id: 'face_1',
        position: const Vector3(0.0, 0.0, -0.5),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.2, 0.3, 0.1),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.85,
        landmarks: [],
        lastUpdated: DateTime.now(),
      );

      expect(face.isTracked, true);
      expect(face.isReliable, true);
      expect(face.center, const Vector3(0.0, 0.0, -0.5));
      expect(face.dimensions, const Vector3(0.2, 0.3, 0.1));
    });

    test('isTracked returns false for non-tracked states', () {
      final face = ARFace(
        id: 'face_1',
        position: const Vector3(0.0, 0.0, -0.5),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.2, 0.3, 0.1),
        trackingState: FaceTrackingState.notTracked,
        confidence: 0.85,
        landmarks: [],
        lastUpdated: DateTime.now(),
      );

      expect(face.isTracked, false);
    });

    test('isReliable returns false for low confidence', () {
      final face = ARFace(
        id: 'face_1',
        position: const Vector3(0.0, 0.0, -0.5),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.2, 0.3, 0.1),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.5, // Low confidence
        landmarks: [],
        lastUpdated: DateTime.now(),
      );

      expect(face.isReliable, false);
    });

    test('converts to and from map', () {
      final landmarks = [
        FaceLandmark(
          name: 'nose',
          position: const Vector3(0.0, 0.0, 0.1),
          confidence: 0.9,
        ),
      ];

      final face = ARFace(
        id: 'face_2',
        position: const Vector3(0.1, 0.2, -0.3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.15, 0.25, 0.05),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.87,
        landmarks: landmarks,
        lastUpdated: DateTime(2024, 1, 15, 14, 30, 0),
      );

      final map = face.toMap();
      final restored = ARFace.fromMap(map);

      expect(restored.id, face.id);
      expect(restored.position, face.position);
      expect(restored.rotation, face.rotation);
      expect(restored.scale, face.scale);
      expect(restored.trackingState, face.trackingState);
      expect(restored.confidence, face.confidence);
      expect(restored.landmarks.length, face.landmarks.length);
      expect(restored.lastUpdated, face.lastUpdated);
    });

    test('parses tracking states correctly', () {
      final testCases = [
        ('tracked', FaceTrackingState.tracked),
        ('nottracked', FaceTrackingState.notTracked),
        ('paused', FaceTrackingState.paused),
        ('failed', FaceTrackingState.failed),
        ('unknown', FaceTrackingState.notTracked), // Default case
      ];

      for (final (stateString, expectedState) in testCases) {
        final map = {
          'id': 'test_face',
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 0.1, 'y': 0.1, 'z': 0.1},
          'trackingState': stateString,
          'confidence': 0.8,
          'landmarks': [],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        };

        final face = ARFace.fromMap(map);
        expect(face.trackingState, expectedState);
      }
    });

    test('equality works correctly', () {
      final landmarks = [
        FaceLandmark(
          name: 'mouth',
          position: const Vector3(0.0, -0.1, 0.0),
          confidence: 0.9,
        ),
      ];

      final face1 = ARFace(
        id: 'face_3',
        position: const Vector3(0.0, 0.0, -0.4),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.18, 0.28, 0.08),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.91,
        landmarks: landmarks,
        lastUpdated: DateTime(2024, 1, 20, 10, 15, 0),
      );

      final face2 = ARFace(
        id: 'face_3',
        position: const Vector3(0.0, 0.0, -0.4),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.18, 0.28, 0.08),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.91,
        landmarks: landmarks,
        lastUpdated: DateTime(2024, 1, 20, 10, 15, 0),
      );

      final face3 = ARFace(
        id: 'face_4',
        position: const Vector3(0.1, 0.1, -0.3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.2, 0.3, 0.1),
        trackingState: FaceTrackingState.notTracked,
        confidence: 0.7,
        landmarks: [],
        lastUpdated: DateTime.now(),
      );

      expect(face1, equals(face2));
      expect(face1, isNot(equals(face3)));
    });

    test('toString works correctly', () {
      final face = ARFace(
        id: 'face_5',
        position: const Vector3(0.0, 0.0, -0.6),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.22, 0.32, 0.12),
        trackingState: FaceTrackingState.tracked,
        confidence: 0.89,
        landmarks: [
          FaceLandmark(
            name: 'left_ear',
            position: const Vector3(-0.1, 0.0, 0.0),
            confidence: 0.88,
          ),
        ],
        lastUpdated: DateTime.now(),
      );

      final str = face.toString();
      expect(str, contains('face_5'));
      expect(str, contains('tracked'));
      expect(str, contains('0.89'));
      expect(str, contains('1')); // landmarks count
    });
  });
}
