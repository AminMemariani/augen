import 'vector3.dart';
import 'quaternion.dart';

/// Multi-user session connection states
enum MultiUserConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Multi-user participant roles
enum MultiUserRole { host, participant, observer }

/// Multi-user session capabilities
enum MultiUserCapability {
  spatialSharing,
  objectSynchronization,
  realTimeCollaboration,
  voiceChat,
  gestureSharing,
  avatarDisplay,
}

/// Multi-user participant information
class MultiUserParticipant {
  final String id;
  final String displayName;
  final MultiUserRole role;
  final Vector3 position;
  final Quaternion rotation;
  final bool isActive;
  final bool isHost;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final Map<String, dynamic> metadata;

  const MultiUserParticipant({
    required this.id,
    required this.displayName,
    required this.role,
    required this.position,
    required this.rotation,
    required this.isActive,
    required this.isHost,
    required this.joinedAt,
    required this.lastSeen,
    this.metadata = const {},
  });

  /// Check if participant is currently active
  bool get isOnline =>
      isActive && DateTime.now().difference(lastSeen).inSeconds < 30;

  /// Check if participant is the session host
  bool get isSessionHost => isHost && role == MultiUserRole.host;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'role': role.name,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'isActive': isActive,
      'isHost': isHost,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory MultiUserParticipant.fromMap(Map<String, dynamic> map) {
    return MultiUserParticipant(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      role: MultiUserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => MultiUserRole.participant,
      ),
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      isActive: map['isActive'] as bool,
      isHost: map['isHost'] as bool,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MultiUserParticipant &&
        other.id == id &&
        other.displayName == displayName &&
        other.role == role &&
        other.position == position &&
        other.rotation == rotation &&
        other.isActive == isActive &&
        other.isHost == isHost &&
        other.joinedAt.millisecondsSinceEpoch ==
            joinedAt.millisecondsSinceEpoch &&
        other.lastSeen.millisecondsSinceEpoch ==
            lastSeen.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    role,
    position,
    rotation,
    isActive,
    isHost,
    joinedAt.millisecondsSinceEpoch,
    lastSeen.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'MultiUserParticipant(id: $id, displayName: $displayName, role: $role, position: $position, rotation: $rotation, isActive: $isActive, isHost: $isHost, joinedAt: $joinedAt, lastSeen: $lastSeen, metadata: $metadata)';
  }
}

/// Multi-user session information
class ARMultiUserSession {
  final String id;
  final String name;
  final String hostId;
  final MultiUserConnectionState state;
  final List<MultiUserParticipant> participants;
  final List<MultiUserCapability> capabilities;
  final int maxParticipants;
  final bool isPrivate;
  final String? password;
  final DateTime createdAt;
  final DateTime lastActivity;
  final Map<String, dynamic> metadata;

  const ARMultiUserSession({
    required this.id,
    required this.name,
    required this.hostId,
    required this.state,
    required this.participants,
    required this.capabilities,
    required this.maxParticipants,
    required this.isPrivate,
    this.password,
    required this.createdAt,
    required this.lastActivity,
    this.metadata = const {},
  });

  /// Get the host participant
  MultiUserParticipant? get host {
    try {
      return participants.firstWhere((p) => p.id == hostId);
    } catch (e) {
      return null;
    }
  }

  /// Get active participants
  List<MultiUserParticipant> get activeParticipants =>
      participants.where((p) => p.isOnline).toList();

  /// Get participant count
  int get participantCount => participants.length;

  /// Check if session is full
  bool get isFull => participants.length >= maxParticipants;

  /// Check if session is active
  bool get isActive => state == MultiUserConnectionState.connected;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostId': hostId,
      'state': state.name,
      'participants': participants.map((p) => p.toMap()).toList(),
      'capabilities': capabilities.map((c) => c.name).toList(),
      'maxParticipants': maxParticipants,
      'isPrivate': isPrivate,
      'password': password,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActivity': lastActivity.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ARMultiUserSession.fromMap(Map<String, dynamic> map) {
    return ARMultiUserSession(
      id: map['id'] as String,
      name: map['name'] as String,
      hostId: map['hostId'] as String,
      state: MultiUserConnectionState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => MultiUserConnectionState.disconnected,
      ),
      participants: (map['participants'] as List)
          .map((p) => MultiUserParticipant.fromMap(p as Map<String, dynamic>))
          .toList(),
      capabilities: (map['capabilities'] as List)
          .map(
            (c) => MultiUserCapability.values.firstWhere(
              (e) => e.name == c,
              orElse: () => MultiUserCapability.spatialSharing,
            ),
          )
          .toList(),
      maxParticipants: map['maxParticipants'] as int,
      isPrivate: map['isPrivate'] as bool,
      password: map['password'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastActivity: DateTime.fromMillisecondsSinceEpoch(
        map['lastActivity'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARMultiUserSession &&
        other.id == id &&
        other.name == name &&
        other.hostId == hostId &&
        other.state == state &&
        _listEquals(other.participants, participants) &&
        _listEquals(other.capabilities, capabilities) &&
        other.maxParticipants == maxParticipants &&
        other.isPrivate == isPrivate &&
        other.password == password &&
        other.createdAt.millisecondsSinceEpoch ==
            createdAt.millisecondsSinceEpoch &&
        other.lastActivity.millisecondsSinceEpoch ==
            lastActivity.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    hostId,
    state,
    Object.hashAll(participants),
    Object.hashAll(capabilities),
    maxParticipants,
    isPrivate,
    password,
    createdAt.millisecondsSinceEpoch,
    lastActivity.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'ARMultiUserSession(id: $id, name: $name, hostId: $hostId, state: $state, participants: $participants, capabilities: $capabilities, maxParticipants: $maxParticipants, isPrivate: $isPrivate, password: $password, createdAt: $createdAt, lastActivity: $lastActivity, metadata: $metadata)';
  }
}

/// Multi-user session status updates
class MultiUserSessionStatus {
  final String status;
  final double progress;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const MultiUserSessionStatus({
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Check if operation is complete
  bool get isComplete => progress >= 1.0;

  /// Check if operation was successful
  bool get isSuccessful => isComplete && errorMessage == null;

  /// Check if operation failed
  bool get isFailed => errorMessage != null;

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'progress': progress,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory MultiUserSessionStatus.fromMap(Map<String, dynamic> map) {
    return MultiUserSessionStatus(
      status: map['status'] as String,
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MultiUserSessionStatus &&
        other.status == status &&
        other.progress == progress &&
        other.errorMessage == errorMessage &&
        other.timestamp.millisecondsSinceEpoch ==
            timestamp.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    status,
    progress,
    errorMessage,
    timestamp.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'MultiUserSessionStatus(status: $status, progress: $progress, errorMessage: $errorMessage, timestamp: $timestamp, metadata: $metadata)';
  }
}

/// Multi-user shared object
class MultiUserSharedObject {
  final String id;
  final String nodeId;
  final String ownerId;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;
  final bool isLocked;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> metadata;

  const MultiUserSharedObject({
    required this.id,
    required this.nodeId,
    required this.ownerId,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.isLocked,
    required this.isVisible,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
  });

  /// Check if object is owned by current user
  bool isOwnedBy(String userId) => ownerId == userId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nodeId': nodeId,
      'ownerId': ownerId,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'isLocked': isLocked,
      'isVisible': isVisible,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory MultiUserSharedObject.fromMap(Map<String, dynamic> map) {
    return MultiUserSharedObject(
      id: map['id'] as String,
      nodeId: map['nodeId'] as String,
      ownerId: map['ownerId'] as String,
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      scale: Vector3.fromMap(Map<String, dynamic>.from(map['scale'] as Map)),
      isLocked: map['isLocked'] as bool,
      isVisible: map['isVisible'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['lastModified'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MultiUserSharedObject &&
        other.id == id &&
        other.nodeId == nodeId &&
        other.ownerId == ownerId &&
        other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.isLocked == isLocked &&
        other.isVisible == isVisible &&
        other.createdAt.millisecondsSinceEpoch ==
            createdAt.millisecondsSinceEpoch &&
        other.lastModified.millisecondsSinceEpoch ==
            lastModified.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    nodeId,
    ownerId,
    position,
    rotation,
    scale,
    isLocked,
    isVisible,
    createdAt.millisecondsSinceEpoch,
    lastModified.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'MultiUserSharedObject(id: $id, nodeId: $nodeId, ownerId: $ownerId, position: $position, rotation: $rotation, scale: $scale, isLocked: $isLocked, isVisible: $isVisible, createdAt: $createdAt, lastModified: $lastModified, metadata: $metadata)';
  }
}

/// Helper functions for list and map equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == b) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map? a, Map? b) {
  if (a == b) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}
