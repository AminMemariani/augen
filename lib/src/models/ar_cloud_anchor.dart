import 'package:augen/src/models/vector3.dart';
import 'package:augen/src/models/quaternion.dart';

/// Represents the state of a cloud anchor
enum CloudAnchorState {
  /// Cloud anchor is being created/uploaded
  creating,
  /// Cloud anchor is successfully created and available
  created,
  /// Cloud anchor is being resolved/downloaded
  resolving,
  /// Cloud anchor is successfully resolved and available
  resolved,
  /// Cloud anchor creation/resolution failed
  failed,
  /// Cloud anchor is no longer available
  expired,
}

/// Represents a cloud anchor that can persist across sessions
class ARCloudAnchor {
  /// Unique identifier for the cloud anchor
  final String id;
  
  /// Local anchor ID that this cloud anchor is based on
  final String localAnchorId;
  
  /// Current state of the cloud anchor
  final CloudAnchorState state;
  
  /// Position of the cloud anchor in 3D space
  final Vector3 position;
  
  /// Rotation of the cloud anchor
  final Quaternion rotation;
  
  /// Scale of the cloud anchor
  final Vector3 scale;
  
  /// Confidence score for the cloud anchor (0.0 - 1.0)
  final double confidence;
  
  /// Timestamp when the cloud anchor was created
  final DateTime createdAt;
  
  /// Timestamp when the cloud anchor was last updated
  final DateTime lastUpdated;
  
  /// Expiration time for the cloud anchor (if applicable)
  final DateTime? expiresAt;
  
  /// Whether the cloud anchor is currently being tracked
  final bool isTracked;
  
  /// Whether the cloud anchor is reliable for use
  final bool isReliable;

  ARCloudAnchor({
    required this.id,
    required this.localAnchorId,
    required this.state,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.confidence,
    required this.createdAt,
    required this.lastUpdated,
    this.expiresAt,
    this.isTracked = false,
    this.isReliable = false,
  });

  /// Returns true if the cloud anchor is successfully created or resolved
  bool get isActive => state == CloudAnchorState.created || state == CloudAnchorState.resolved;

  /// Returns true if the cloud anchor is in a failed state
  bool get isFailed => state == CloudAnchorState.failed || state == CloudAnchorState.expired;

  /// Returns true if the cloud anchor is currently being processed
  bool get isProcessing => state == CloudAnchorState.creating || state == CloudAnchorState.resolving;

  /// Creates an ARCloudAnchor from a map
  factory ARCloudAnchor.fromMap(Map<dynamic, dynamic> map) {
    return ARCloudAnchor(
      id: map['id'] as String,
      localAnchorId: map['localAnchorId'] as String,
      state: _parseCloudAnchorState(map['state'] as String),
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      scale: Vector3.fromMap(map['scale'] as Map),
      confidence: (map['confidence'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int),
      expiresAt: map['expiresAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
          : null,
      isTracked: map['isTracked'] as bool? ?? false,
      isReliable: map['isReliable'] as bool? ?? false,
    );
  }

  /// Converts the ARCloudAnchor to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localAnchorId': localAnchorId,
      'state': state.name,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'confidence': confidence,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'isTracked': isTracked,
      'isReliable': isReliable,
    };
  }

  /// Parses cloud anchor state from string
  static CloudAnchorState _parseCloudAnchorState(String state) {
    switch (state.toLowerCase()) {
      case 'creating':
        return CloudAnchorState.creating;
      case 'created':
        return CloudAnchorState.created;
      case 'resolving':
        return CloudAnchorState.resolving;
      case 'resolved':
        return CloudAnchorState.resolved;
      case 'failed':
        return CloudAnchorState.failed;
      case 'expired':
        return CloudAnchorState.expired;
      default:
        return CloudAnchorState.failed;
    }
  }

  @override
  String toString() =>
      'ARCloudAnchor(id: $id, state: $state, confidence: $confidence, isTracked: $isTracked)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARCloudAnchor &&
          id == other.id &&
          localAnchorId == other.localAnchorId &&
          state == other.state &&
          position == other.position &&
          rotation == other.rotation &&
          scale == other.scale &&
          confidence == other.confidence &&
          createdAt == other.createdAt &&
          lastUpdated == other.lastUpdated &&
          expiresAt == other.expiresAt &&
          isTracked == other.isTracked &&
          isReliable == other.isReliable;

  @override
  int get hashCode => Object.hash(
      id, localAnchorId, state, position, rotation, scale, confidence,
      createdAt, lastUpdated, expiresAt, isTracked, isReliable);
}

/// Represents the status of a cloud anchor operation
class CloudAnchorStatus {
  /// The cloud anchor ID
  final String cloudAnchorId;
  
  /// The current state of the operation
  final CloudAnchorState state;
  
  /// Progress of the operation (0.0 - 1.0)
  final double progress;
  
  /// Error message if the operation failed
  final String? errorMessage;
  
  /// Timestamp when the status was last updated
  final DateTime timestamp;

  CloudAnchorStatus({
    required this.cloudAnchorId,
    required this.state,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
  });

  /// Returns true if the operation is complete (success or failure)
  bool get isComplete => state == CloudAnchorState.created || 
                        state == CloudAnchorState.resolved || 
                        state == CloudAnchorState.failed || 
                        state == CloudAnchorState.expired;

  /// Returns true if the operation was successful
  bool get isSuccessful => state == CloudAnchorState.created || state == CloudAnchorState.resolved;

  /// Returns true if the operation failed
  bool get isFailed => state == CloudAnchorState.failed || state == CloudAnchorState.expired;

  /// Creates a CloudAnchorStatus from a map
  factory CloudAnchorStatus.fromMap(Map<dynamic, dynamic> map) {
    return CloudAnchorStatus(
      cloudAnchorId: map['cloudAnchorId'] as String,
      state: ARCloudAnchor._parseCloudAnchorState(map['state'] as String),
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Converts the CloudAnchorStatus to a map
  Map<String, dynamic> toMap() {
    return {
      'cloudAnchorId': cloudAnchorId,
      'state': state.name,
      'progress': progress,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'CloudAnchorStatus(cloudAnchorId: $cloudAnchorId, state: $state, progress: $progress)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudAnchorStatus &&
          cloudAnchorId == other.cloudAnchorId &&
          state == other.state &&
          progress == other.progress &&
          errorMessage == other.errorMessage &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(cloudAnchorId, state, progress, errorMessage, timestamp);
}
