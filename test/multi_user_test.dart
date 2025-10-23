import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('MultiUserConnectionState', () {
    test('has correct enum values', () {
      expect(MultiUserConnectionState.values, [
        MultiUserConnectionState.disconnected,
        MultiUserConnectionState.connecting,
        MultiUserConnectionState.connected,
        MultiUserConnectionState.reconnecting,
        MultiUserConnectionState.failed,
      ]);
    });

    test('enum names are correct', () {
      expect(MultiUserConnectionState.disconnected.name, 'disconnected');
      expect(MultiUserConnectionState.connecting.name, 'connecting');
      expect(MultiUserConnectionState.connected.name, 'connected');
      expect(MultiUserConnectionState.reconnecting.name, 'reconnecting');
      expect(MultiUserConnectionState.failed.name, 'failed');
    });
  });

  group('MultiUserRole', () {
    test('has correct enum values', () {
      expect(MultiUserRole.values, [
        MultiUserRole.host,
        MultiUserRole.participant,
        MultiUserRole.observer,
      ]);
    });

    test('enum names are correct', () {
      expect(MultiUserRole.host.name, 'host');
      expect(MultiUserRole.participant.name, 'participant');
      expect(MultiUserRole.observer.name, 'observer');
    });
  });

  group('MultiUserCapability', () {
    test('has correct enum values', () {
      expect(MultiUserCapability.values.length, 6);
      expect(
        MultiUserCapability.values.contains(MultiUserCapability.spatialSharing),
        true,
      );
      expect(
        MultiUserCapability.values.contains(
          MultiUserCapability.objectSynchronization,
        ),
        true,
      );
    });
  });

  group('MultiUserParticipant', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final testParticipant = MultiUserParticipant(
      id: 'participant1',
      displayName: 'User 1',
      role: MultiUserRole.participant,
      position: const Vector3(1, 2, 3),
      rotation: const Quaternion(0, 0, 0, 1),
      isActive: true,
      isHost: false,
      joinedAt: now,
      lastSeen: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testParticipant.id, 'participant1');
      expect(testParticipant.displayName, 'User 1');
      expect(testParticipant.role, MultiUserRole.participant);
      expect(testParticipant.position, const Vector3(1, 2, 3));
      expect(testParticipant.rotation, const Quaternion(0, 0, 0, 1));
      expect(testParticipant.isActive, true);
      expect(testParticipant.isHost, false);
      expect(testParticipant.joinedAt, now);
      expect(testParticipant.lastSeen, now);
      expect(testParticipant.metadata, {'key': 'value'});
    });

    test('computed properties work correctly', () {
      expect(testParticipant.isOnline, true);
      expect(testParticipant.isSessionHost, false);

      final hostParticipant = MultiUserParticipant(
        id: 'host1',
        displayName: 'Host',
        role: MultiUserRole.host,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        isActive: true,
        isHost: true,
        joinedAt: now,
        lastSeen: now,
      );
      expect(hostParticipant.isSessionHost, true);
    });

    test('converts to and from map', () {
      final map = testParticipant.toMap();
      final fromMap = MultiUserParticipant.fromMap(map);
      expect(fromMap, testParticipant);
    });

    test('parses roles correctly', () {
      final map = testParticipant.toMap();
      map['role'] = 'unknown';
      final fromMap = MultiUserParticipant.fromMap(map);
      expect(fromMap.role, MultiUserRole.participant); // Default value
    });

    test('equality works correctly', () {
      final anotherParticipant = MultiUserParticipant(
        id: 'participant1',
        displayName: 'User 1',
        role: MultiUserRole.participant,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        isActive: true,
        isHost: false,
        joinedAt: now,
        lastSeen: now,
        metadata: {'key': 'value'},
      );
      expect(testParticipant, anotherParticipant);

      final differentParticipant = MultiUserParticipant(
        id: 'participant2',
        displayName: 'User 2',
        role: MultiUserRole.participant,
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        isActive: true,
        isHost: false,
        joinedAt: now,
        lastSeen: now,
        metadata: {'key': 'value'},
      );
      expect(testParticipant == differentParticipant, false);
    });

    test('toString works correctly', () {
      expect(
        testParticipant.toString(),
        contains('MultiUserParticipant(id: participant1'),
      );
    });
  });

  group('ARMultiUserSession', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final participant1 = MultiUserParticipant(
      id: 'host1',
      displayName: 'Host',
      role: MultiUserRole.host,
      position: const Vector3(0, 0, 0),
      rotation: const Quaternion(0, 0, 0, 1),
      isActive: true,
      isHost: true,
      joinedAt: now,
      lastSeen: now,
    );
    final participant2 = MultiUserParticipant(
      id: 'user1',
      displayName: 'User 1',
      role: MultiUserRole.participant,
      position: const Vector3(1, 0, 0),
      rotation: const Quaternion(0, 0, 0, 1),
      isActive: true,
      isHost: false,
      joinedAt: now,
      lastSeen: now,
    );

    final testSession = ARMultiUserSession(
      id: 'session1',
      name: 'Test Session',
      hostId: 'host1',
      state: MultiUserConnectionState.connected,
      participants: [participant1, participant2],
      capabilities: [
        MultiUserCapability.spatialSharing,
        MultiUserCapability.objectSynchronization,
      ],
      maxParticipants: 8,
      isPrivate: false,
      createdAt: now,
      lastActivity: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testSession.id, 'session1');
      expect(testSession.name, 'Test Session');
      expect(testSession.hostId, 'host1');
      expect(testSession.state, MultiUserConnectionState.connected);
      expect(testSession.participants.length, 2);
      expect(testSession.capabilities.length, 2);
      expect(testSession.maxParticipants, 8);
      expect(testSession.isPrivate, false);
      expect(testSession.createdAt, now);
      expect(testSession.lastActivity, now);
      expect(testSession.metadata, {'key': 'value'});
    });

    test('computed properties work correctly', () {
      expect(testSession.host?.id, 'host1');
      expect(testSession.activeParticipants.length, 2);
      expect(testSession.participantCount, 2);
      expect(testSession.isFull, false);
      expect(testSession.isActive, true);
    });

    test('converts to and from map', () {
      final map = testSession.toMap();
      final fromMap = ARMultiUserSession.fromMap(map);
      expect(fromMap, testSession);
    });

    test('parses connection states correctly', () {
      final map = testSession.toMap();
      map['state'] = 'unknown';
      final fromMap = ARMultiUserSession.fromMap(map);
      expect(
        fromMap.state,
        MultiUserConnectionState.disconnected,
      ); // Default value
    });

    test('equality works correctly', () {
      final anotherSession = ARMultiUserSession(
        id: 'session1',
        name: 'Test Session',
        hostId: 'host1',
        state: MultiUserConnectionState.connected,
        participants: [participant1, participant2],
        capabilities: [
          MultiUserCapability.spatialSharing,
          MultiUserCapability.objectSynchronization,
        ],
        maxParticipants: 8,
        isPrivate: false,
        createdAt: now,
        lastActivity: now,
        metadata: {'key': 'value'},
      );
      expect(testSession, anotherSession);

      final differentSession = ARMultiUserSession(
        id: 'session2',
        name: 'Different Session',
        hostId: 'host1',
        state: MultiUserConnectionState.connected,
        participants: [participant1],
        capabilities: [MultiUserCapability.spatialSharing],
        maxParticipants: 8,
        isPrivate: false,
        createdAt: now,
        lastActivity: now,
      );
      expect(testSession == differentSession, false);
    });

    test('toString works correctly', () {
      expect(
        testSession.toString(),
        contains('ARMultiUserSession(id: session1'),
      );
    });
  });

  group('MultiUserSessionStatus', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final testStatus = MultiUserSessionStatus(
      status: 'connecting',
      progress: 0.5,
      timestamp: now,
    );

    test('creates with correct properties', () {
      expect(testStatus.status, 'connecting');
      expect(testStatus.progress, 0.5);
      expect(testStatus.errorMessage, isNull);
      expect(testStatus.timestamp, now);
    });

    test('computed properties work correctly', () {
      expect(testStatus.isComplete, false);
      expect(testStatus.isSuccessful, false);
      expect(testStatus.isFailed, false);

      final completeStatus = MultiUserSessionStatus(
        status: 'connected',
        progress: 1.0,
        timestamp: now,
      );
      expect(completeStatus.isComplete, true);
      expect(completeStatus.isSuccessful, true);

      final failedStatus = MultiUserSessionStatus(
        status: 'failed',
        progress: 0.8,
        errorMessage: 'Connection failed',
        timestamp: now,
      );
      expect(failedStatus.isFailed, true);
      expect(failedStatus.isSuccessful, false);
    });

    test('converts to and from map', () {
      final map = testStatus.toMap();
      final fromMap = MultiUserSessionStatus.fromMap(map);
      expect(fromMap, testStatus);
    });

    test('equality works correctly', () {
      final anotherStatus = MultiUserSessionStatus(
        status: 'connecting',
        progress: 0.5,
        timestamp: now,
      );
      expect(testStatus, anotherStatus);

      final differentStatus = MultiUserSessionStatus(
        status: 'connected',
        progress: 1.0,
        timestamp: now,
      );
      expect(testStatus == differentStatus, false);
    });

    test('toString works correctly', () {
      expect(
        testStatus.toString(),
        contains('MultiUserSessionStatus(status: connecting'),
      );
    });
  });

  group('MultiUserSharedObject', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final testObject = MultiUserSharedObject(
      id: 'object1',
      nodeId: 'node1',
      ownerId: 'user1',
      position: const Vector3(1, 2, 3),
      rotation: const Quaternion(0, 0, 0, 1),
      scale: const Vector3(1, 1, 1),
      isLocked: false,
      isVisible: true,
      createdAt: now,
      lastModified: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testObject.id, 'object1');
      expect(testObject.nodeId, 'node1');
      expect(testObject.ownerId, 'user1');
      expect(testObject.position, const Vector3(1, 2, 3));
      expect(testObject.rotation, const Quaternion(0, 0, 0, 1));
      expect(testObject.scale, const Vector3(1, 1, 1));
      expect(testObject.isLocked, false);
      expect(testObject.isVisible, true);
      expect(testObject.createdAt, now);
      expect(testObject.lastModified, now);
      expect(testObject.metadata, {'key': 'value'});
    });

    test('isOwnedBy works correctly', () {
      expect(testObject.isOwnedBy('user1'), true);
      expect(testObject.isOwnedBy('user2'), false);
    });

    test('converts to and from map', () {
      final map = testObject.toMap();
      final fromMap = MultiUserSharedObject.fromMap(map);
      expect(fromMap, testObject);
    });

    test('equality works correctly', () {
      final anotherObject = MultiUserSharedObject(
        id: 'object1',
        nodeId: 'node1',
        ownerId: 'user1',
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        isLocked: false,
        isVisible: true,
        createdAt: now,
        lastModified: now,
        metadata: {'key': 'value'},
      );
      expect(testObject, anotherObject);

      final differentObject = MultiUserSharedObject(
        id: 'object2',
        nodeId: 'node2',
        ownerId: 'user2',
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        isLocked: false,
        isVisible: true,
        createdAt: now,
        lastModified: now,
      );
      expect(testObject == differentObject, false);
    });

    test('toString works correctly', () {
      expect(
        testObject.toString(),
        contains('MultiUserSharedObject(id: object1'),
      );
    });
  });
}
