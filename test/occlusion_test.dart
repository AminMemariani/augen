import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('OcclusionType', () {
    test('has correct enum values', () {
      expect(OcclusionType.values.length, 4);
      expect(OcclusionType.none, OcclusionType.none);
      expect(OcclusionType.depth, OcclusionType.depth);
      expect(OcclusionType.person, OcclusionType.person);
      expect(OcclusionType.plane, OcclusionType.plane);
    });

    test('enum names are correct', () {
      expect(OcclusionType.none.name, 'none');
      expect(OcclusionType.depth.name, 'depth');
      expect(OcclusionType.person.name, 'person');
      expect(OcclusionType.plane.name, 'plane');
    });
  });

  group('AROcclusion', () {
    test('creates with correct properties', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final occlusion = AROcclusion(
        id: 'occlusion_1',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.8,
        createdAt: now,
        lastUpdated: now,
        metadata: {'test': 'value'},
      );

      expect(occlusion.id, 'occlusion_1');
      expect(occlusion.type, OcclusionType.depth);
      expect(occlusion.isActive, true);
      expect(occlusion.position, const Vector3(1, 2, 3));
      expect(occlusion.rotation, const Quaternion(0, 0, 0, 1));
      expect(occlusion.scale, const Vector3(1, 1, 1));
      expect(occlusion.confidence, 0.8);
      expect(occlusion.createdAt, now);
      expect(occlusion.lastUpdated, now);
      expect(occlusion.metadata, {'test': 'value'});
    });

    test('computed properties work correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final highConfidenceOcclusion = AROcclusion(
        id: 'high_confidence',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.8,
        createdAt: now,
        lastUpdated: now,
      );

      final lowConfidenceOcclusion = AROcclusion(
        id: 'low_confidence',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.5,
        createdAt: now,
        lastUpdated: now,
      );

      expect(highConfidenceOcclusion.isReliable, true);
      expect(lowConfidenceOcclusion.isReliable, false);
      expect(highConfidenceOcclusion.isRecent, true);
    });

    test('converts to and from map', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final originalOcclusion = AROcclusion(
        id: 'occlusion_1',
        type: OcclusionType.person,
        isActive: true,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(2, 2, 2),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
        metadata: {'type': 'person', 'confidence': 0.9},
      );

      final map = originalOcclusion.toMap();
      final reconstructedOcclusion = AROcclusion.fromMap(map);

      expect(reconstructedOcclusion.id, originalOcclusion.id);
      expect(reconstructedOcclusion.type, originalOcclusion.type);
      expect(reconstructedOcclusion.isActive, originalOcclusion.isActive);
      expect(reconstructedOcclusion.position, originalOcclusion.position);
      expect(reconstructedOcclusion.rotation, originalOcclusion.rotation);
      expect(reconstructedOcclusion.scale, originalOcclusion.scale);
      expect(reconstructedOcclusion.confidence, originalOcclusion.confidence);
      expect(
        reconstructedOcclusion.createdAt.millisecondsSinceEpoch,
        originalOcclusion.createdAt.millisecondsSinceEpoch,
      );
      expect(
        reconstructedOcclusion.lastUpdated.millisecondsSinceEpoch,
        originalOcclusion.lastUpdated.millisecondsSinceEpoch,
      );
      expect(reconstructedOcclusion.metadata, originalOcclusion.metadata);
    });

    test('parses occlusion types correctly', () {
      final map = {
        'id': 'test_occlusion',
        'type': 'depth',
        'isActive': true,
        'position': {'x': 0, 'y': 0, 'z': 0},
        'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
        'scale': {'x': 1, 'y': 1, 'z': 1},
        'confidence': 0.7,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'metadata': {},
      };

      final occlusion = AROcclusion.fromMap(map);
      expect(occlusion.type, OcclusionType.depth);

      // Test unknown type defaults to none
      final unknownMap = Map<String, dynamic>.from(map);
      unknownMap['type'] = 'unknown';
      final unknownOcclusion = AROcclusion.fromMap(unknownMap);
      expect(unknownOcclusion.type, OcclusionType.none);
    });

    test('equality works correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final occlusion1 = AROcclusion(
        id: 'occlusion_1',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.8,
        createdAt: now,
        lastUpdated: now,
      );

      final occlusion2 = AROcclusion(
        id: 'occlusion_1',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.8,
        createdAt: now,
        lastUpdated: now,
      );

      final occlusion3 = AROcclusion(
        id: 'occlusion_2',
        type: OcclusionType.person,
        isActive: false,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.5,
        createdAt: now,
        lastUpdated: now,
      );

      expect(occlusion1, equals(occlusion2));
      expect(occlusion1, isNot(equals(occlusion3)));
      expect(occlusion1.hashCode, equals(occlusion2.hashCode));
      expect(occlusion1.hashCode, isNot(equals(occlusion3.hashCode)));
    });

    test('toString works correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final occlusion = AROcclusion(
        id: 'occlusion_1',
        type: OcclusionType.depth,
        isActive: true,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.8,
        createdAt: now,
        lastUpdated: now,
      );

      final string = occlusion.toString();
      expect(string, contains('AROcclusion'));
      expect(string, contains('occlusion_1'));
      expect(string, contains('depth'));
      expect(string, contains('true'));
    });
  });

  group('OcclusionStatus', () {
    test('creates with correct properties', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final status = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'processing',
        progress: 0.5,
        errorMessage: null,
        timestamp: now,
      );

      expect(status.occlusionId, 'occlusion_1');
      expect(status.status, 'processing');
      expect(status.progress, 0.5);
      expect(status.errorMessage, null);
      expect(status.timestamp, now);
    });

    test('computed properties work correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );

      final completeStatus = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'completed',
        progress: 1.0,
        errorMessage: null,
        timestamp: now,
      );

      final failedStatus = OcclusionStatus(
        occlusionId: 'occlusion_2',
        status: 'failed',
        progress: 0.3,
        errorMessage: 'Processing failed',
        timestamp: now,
      );

      final processingStatus = OcclusionStatus(
        occlusionId: 'occlusion_3',
        status: 'processing',
        progress: 0.5,
        errorMessage: null,
        timestamp: now,
      );

      expect(completeStatus.isComplete, true);
      expect(completeStatus.isSuccessful, true);
      expect(completeStatus.isFailed, false);

      expect(failedStatus.isComplete, false);
      expect(failedStatus.isSuccessful, false);
      expect(failedStatus.isFailed, true);

      expect(processingStatus.isComplete, false);
      expect(processingStatus.isSuccessful, false);
      expect(processingStatus.isFailed, false);
    });

    test('converts to and from map', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final originalStatus = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'processing',
        progress: 0.7,
        errorMessage: 'Test error',
        timestamp: now,
      );

      final map = originalStatus.toMap();
      final reconstructedStatus = OcclusionStatus.fromMap(map);

      expect(reconstructedStatus.occlusionId, originalStatus.occlusionId);
      expect(reconstructedStatus.status, originalStatus.status);
      expect(reconstructedStatus.progress, originalStatus.progress);
      expect(reconstructedStatus.errorMessage, originalStatus.errorMessage);
      expect(
        reconstructedStatus.timestamp.millisecondsSinceEpoch,
        originalStatus.timestamp.millisecondsSinceEpoch,
      );
    });

    test('equality works correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final status1 = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'processing',
        progress: 0.5,
        errorMessage: null,
        timestamp: now,
      );

      final status2 = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'processing',
        progress: 0.5,
        errorMessage: null,
        timestamp: now,
      );

      final status3 = OcclusionStatus(
        occlusionId: 'occlusion_2',
        status: 'completed',
        progress: 1.0,
        errorMessage: 'Error',
        timestamp: now,
      );

      expect(status1, equals(status2));
      expect(status1, isNot(equals(status3)));
      expect(status1.hashCode, equals(status2.hashCode));
      expect(status1.hashCode, isNot(equals(status3.hashCode)));
    });

    test('toString works correctly', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final status = OcclusionStatus(
        occlusionId: 'occlusion_1',
        status: 'processing',
        progress: 0.5,
        errorMessage: null,
        timestamp: now,
      );

      final string = status.toString();
      expect(string, contains('OcclusionStatus'));
      expect(string, contains('occlusion_1'));
      expect(string, contains('processing'));
      expect(string, contains('0.5'));
    });
  });
}
