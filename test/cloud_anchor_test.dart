import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('CloudAnchorState', () {
    test('has correct enum values', () {
      expect(CloudAnchorState.values, [
        CloudAnchorState.creating,
        CloudAnchorState.created,
        CloudAnchorState.resolving,
        CloudAnchorState.resolved,
        CloudAnchorState.failed,
        CloudAnchorState.expired,
      ]);
    });

    test('enum names are correct', () {
      expect(CloudAnchorState.creating.name, 'creating');
      expect(CloudAnchorState.created.name, 'created');
      expect(CloudAnchorState.resolving.name, 'resolving');
      expect(CloudAnchorState.resolved.name, 'resolved');
      expect(CloudAnchorState.failed.name, 'failed');
      expect(CloudAnchorState.expired.name, 'expired');
    });
  });

  group('ARCloudAnchor', () {
    test('creates with correct properties', () {
      final now = DateTime.now();
      final cloudAnchor = ARCloudAnchor(
        id: 'cloud_anchor_1',
        localAnchorId: 'local_anchor_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.95,
        createdAt: now,
        lastUpdated: now,
        expiresAt: now.add(const Duration(hours: 24)),
        isTracked: true,
        isReliable: true,
      );

      expect(cloudAnchor.id, 'cloud_anchor_1');
      expect(cloudAnchor.localAnchorId, 'local_anchor_1');
      expect(cloudAnchor.state, CloudAnchorState.created);
      expect(cloudAnchor.position, const Vector3(1, 2, 3));
      expect(cloudAnchor.rotation, const Quaternion(0, 0, 0, 1));
      expect(cloudAnchor.scale, const Vector3(1, 1, 1));
      expect(cloudAnchor.confidence, 0.95);
      expect(cloudAnchor.createdAt, now);
      expect(cloudAnchor.lastUpdated, now);
      expect(cloudAnchor.expiresAt, now.add(const Duration(hours: 24)));
      expect(cloudAnchor.isTracked, true);
      expect(cloudAnchor.isReliable, true);
    });

    test('computed properties work correctly', () {
      final now = DateTime.now();
      
      // Active states
      final createdAnchor = ARCloudAnchor(
        id: 'anchor_1',
        localAnchorId: 'local_1',
        state: CloudAnchorState.created,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      final resolvedAnchor = ARCloudAnchor(
        id: 'anchor_2',
        localAnchorId: 'local_2',
        state: CloudAnchorState.resolved,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      // Failed states
      final failedAnchor = ARCloudAnchor(
        id: 'anchor_3',
        localAnchorId: 'local_3',
        state: CloudAnchorState.failed,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      // Processing states
      final creatingAnchor = ARCloudAnchor(
        id: 'anchor_4',
        localAnchorId: 'local_4',
        state: CloudAnchorState.creating,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      expect(createdAnchor.isActive, true);
      expect(resolvedAnchor.isActive, true);
      expect(failedAnchor.isActive, false);
      expect(creatingAnchor.isActive, false);

      expect(createdAnchor.isFailed, false);
      expect(resolvedAnchor.isFailed, false);
      expect(failedAnchor.isFailed, true);
      expect(creatingAnchor.isFailed, false);

      expect(createdAnchor.isProcessing, false);
      expect(resolvedAnchor.isProcessing, false);
      expect(failedAnchor.isProcessing, false);
      expect(creatingAnchor.isProcessing, true);
    });

    test('converts to and from map', () {
      final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);
      final expiresAt = now.add(const Duration(hours: 24));
      
      final cloudAnchor = ARCloudAnchor(
        id: 'cloud_anchor_1',
        localAnchorId: 'local_anchor_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0.1, 0.2, 0.3, 0.4),
        scale: const Vector3(2, 3, 4),
        confidence: 0.95,
        createdAt: now,
        lastUpdated: now,
        expiresAt: expiresAt,
        isTracked: true,
        isReliable: true,
      );

      final map = cloudAnchor.toMap();
      final restored = ARCloudAnchor.fromMap(map);

      expect(restored.id, cloudAnchor.id);
      expect(restored.localAnchorId, cloudAnchor.localAnchorId);
      expect(restored.state, cloudAnchor.state);
      expect(restored.position, cloudAnchor.position);
      expect(restored.rotation, cloudAnchor.rotation);
      expect(restored.scale, cloudAnchor.scale);
      expect(restored.confidence, cloudAnchor.confidence);
      expect(restored.createdAt.millisecondsSinceEpoch, cloudAnchor.createdAt.millisecondsSinceEpoch);
      expect(restored.lastUpdated.millisecondsSinceEpoch, cloudAnchor.lastUpdated.millisecondsSinceEpoch);
      expect(restored.expiresAt?.millisecondsSinceEpoch, cloudAnchor.expiresAt?.millisecondsSinceEpoch);
      expect(restored.isTracked, cloudAnchor.isTracked);
      expect(restored.isReliable, cloudAnchor.isReliable);
    });

    test('parses cloud anchor states correctly', () {
      final now = DateTime.now();
      
      final testCases = [
        ('creating', CloudAnchorState.creating),
        ('created', CloudAnchorState.created),
        ('resolving', CloudAnchorState.resolving),
        ('resolved', CloudAnchorState.resolved),
        ('failed', CloudAnchorState.failed),
        ('expired', CloudAnchorState.expired),
        ('unknown', CloudAnchorState.failed), // Default fallback
      ];

      for (final (stateString, expectedState) in testCases) {
        final map = {
          'id': 'test_anchor',
          'localAnchorId': 'local_1',
          'state': stateString,
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
          'confidence': 0.9,
          'createdAt': now.millisecondsSinceEpoch,
          'lastUpdated': now.millisecondsSinceEpoch,
        };

        final cloudAnchor = ARCloudAnchor.fromMap(map);
        expect(cloudAnchor.state, expectedState);
      }
    });

    test('equality works correctly', () {
      final now = DateTime.now();
      final cloudAnchor1 = ARCloudAnchor(
        id: 'anchor_1',
        localAnchorId: 'local_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      final cloudAnchor2 = ARCloudAnchor(
        id: 'anchor_1',
        localAnchorId: 'local_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      final cloudAnchor3 = ARCloudAnchor(
        id: 'anchor_2',
        localAnchorId: 'local_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.9,
        createdAt: now,
        lastUpdated: now,
      );

      expect(cloudAnchor1, equals(cloudAnchor2));
      expect(cloudAnchor1, isNot(equals(cloudAnchor3)));
    });

    test('toString works correctly', () {
      final now = DateTime.now();
      final cloudAnchor = ARCloudAnchor(
        id: 'test_anchor',
        localAnchorId: 'local_1',
        state: CloudAnchorState.created,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        confidence: 0.95,
        createdAt: now,
        lastUpdated: now,
        isTracked: true,
        isReliable: true,
      );

      final str = cloudAnchor.toString();
      expect(str, contains('test_anchor'));
      expect(str, contains('created'));
      expect(str, contains('0.95'));
      expect(str, contains('true'));
    });
  });

  group('CloudAnchorStatus', () {
    test('creates with correct properties', () {
      final now = DateTime.now();
      final status = CloudAnchorStatus(
        cloudAnchorId: 'anchor_1',
        state: CloudAnchorState.creating,
        progress: 0.5,
        errorMessage: 'Test error',
        timestamp: now,
      );

      expect(status.cloudAnchorId, 'anchor_1');
      expect(status.state, CloudAnchorState.creating);
      expect(status.progress, 0.5);
      expect(status.errorMessage, 'Test error');
      expect(status.timestamp, now);
    });

    test('computed properties work correctly', () {
      final now = DateTime.now();
      
      // Complete states
      final createdStatus = CloudAnchorStatus(
        cloudAnchorId: 'anchor_1',
        state: CloudAnchorState.created,
        progress: 1.0,
        timestamp: now,
      );

      final resolvedStatus = CloudAnchorStatus(
        cloudAnchorId: 'anchor_2',
        state: CloudAnchorState.resolved,
        progress: 1.0,
        timestamp: now,
      );

      // Failed states
      final failedStatus = CloudAnchorStatus(
        cloudAnchorId: 'anchor_3',
        state: CloudAnchorState.failed,
        progress: 0.0,
        errorMessage: 'Failed to create',
        timestamp: now,
      );

      // Processing states
      final creatingStatus = CloudAnchorStatus(
        cloudAnchorId: 'anchor_4',
        state: CloudAnchorState.creating,
        progress: 0.5,
        timestamp: now,
      );

      expect(createdStatus.isComplete, true);
      expect(resolvedStatus.isComplete, true);
      expect(failedStatus.isComplete, true);
      expect(creatingStatus.isComplete, false);

      expect(createdStatus.isSuccessful, true);
      expect(resolvedStatus.isSuccessful, true);
      expect(failedStatus.isSuccessful, false);
      expect(creatingStatus.isSuccessful, false);

      expect(createdStatus.isFailed, false);
      expect(resolvedStatus.isFailed, false);
      expect(failedStatus.isFailed, true);
      expect(creatingStatus.isFailed, false);
    });

    test('converts to and from map', () {
      final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);
      final status = CloudAnchorStatus(
        cloudAnchorId: 'test_anchor',
        state: CloudAnchorState.creating,
        progress: 0.75,
        errorMessage: 'Test error message',
        timestamp: now,
      );

      final map = status.toMap();
      final restored = CloudAnchorStatus.fromMap(map);

      expect(restored.cloudAnchorId, status.cloudAnchorId);
      expect(restored.state, status.state);
      expect(restored.progress, status.progress);
      expect(restored.errorMessage, status.errorMessage);
      expect(restored.timestamp.millisecondsSinceEpoch, status.timestamp.millisecondsSinceEpoch);
    });

    test('equality works correctly', () {
      final now = DateTime.now();
      final status1 = CloudAnchorStatus(
        cloudAnchorId: 'anchor_1',
        state: CloudAnchorState.created,
        progress: 1.0,
        timestamp: now,
      );

      final status2 = CloudAnchorStatus(
        cloudAnchorId: 'anchor_1',
        state: CloudAnchorState.created,
        progress: 1.0,
        timestamp: now,
      );

      final status3 = CloudAnchorStatus(
        cloudAnchorId: 'anchor_2',
        state: CloudAnchorState.created,
        progress: 1.0,
        timestamp: now,
      );

      expect(status1, equals(status2));
      expect(status1, isNot(equals(status3)));
    });

    test('toString works correctly', () {
      final now = DateTime.now();
      final status = CloudAnchorStatus(
        cloudAnchorId: 'test_anchor',
        state: CloudAnchorState.creating,
        progress: 0.5,
        timestamp: now,
      );

      final str = status.toString();
      expect(str, contains('test_anchor'));
      expect(str, contains('creating'));
      expect(str, contains('0.5'));
    });
  });
}
