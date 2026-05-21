import 'vector2.dart';
import 'vector3.dart';
import 'quaternion.dart';
import 'ar_marker_target.dart';

/// Tracking state of a marker
enum ARMarkerTrackingState {
  /// Marker is being tracked
  tracked,

  /// Marker is not tracked
  notTracked,

  /// Marker tracking is paused
  paused,

  /// Marker tracking failed
  failed,
}

/// Represents a tracked marker in AR space
class ARTrackedMarker {
  final String id;
  final String targetId;
  final ARMarkerType type;
  final Vector3 position;
  final Quaternion rotation;
  final List<double> transform;
  final List<Vector2> corners;
  final double confidence;
  final ARMarkerTrackingState trackingState;
  final DateTime lastUpdated;

  ARTrackedMarker({
    required this.id,
    required this.targetId,
    required this.type,
    required this.position,
    required this.rotation,
    required this.transform,
    required this.corners,
    required this.confidence,
    required this.trackingState,
    required this.lastUpdated,
  });

  factory ARTrackedMarker.fromMap(Map<dynamic, dynamic> map) {
    return ARTrackedMarker(
      id: map['id'] as String,
      targetId: map['targetId'] as String,
      type: _parseMarkerType(map['type'] as String),
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      transform: (map['transform'] as List).cast<num>().map((n) => n.toDouble()).toList(),
      corners: (map['corners'] as List)
          .map((c) => Vector2.fromMap(c as Map))
          .toList(),
      confidence: (map['confidence'] as num).toDouble(),
      trackingState: _parseTrackingState(map['trackingState'] as String),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
    );
  }

  static ARMarkerType _parseMarkerType(String type) {
    switch (type.toLowerCase()) {
      case 'pattern':
        return ARMarkerType.pattern;
      case 'barcode':
        return ARMarkerType.barcode;
      case 'aruco':
        return ARMarkerType.aruco;
      default:
        return ARMarkerType.pattern;
    }
  }

  static ARMarkerTrackingState _parseTrackingState(String state) {
    switch (state.toLowerCase()) {
      case 'tracked':
        return ARMarkerTrackingState.tracked;
      case 'nottracked':
      case 'not_tracked':
        return ARMarkerTrackingState.notTracked;
      case 'paused':
        return ARMarkerTrackingState.paused;
      case 'failed':
        return ARMarkerTrackingState.failed;
      default:
        return ARMarkerTrackingState.notTracked;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetId': targetId,
      'type': type.name,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'transform': transform,
      'corners': corners.map((c) => c.toMap()).toList(),
      'confidence': confidence,
      'trackingState': trackingState.name,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Whether the marker is currently being tracked
  bool get isTracked => trackingState == ARMarkerTrackingState.tracked;

  /// Whether the marker tracking is reliable (high confidence)
  bool get isReliable => isTracked && confidence > 0.7;

  @override
  String toString() =>
      'ARTrackedMarker(id: $id, targetId: $targetId, type: $type, state: $trackingState, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARTrackedMarker &&
          id == other.id &&
          targetId == other.targetId &&
          type == other.type &&
          position == other.position &&
          rotation == other.rotation &&
          trackingState == other.trackingState &&
          confidence == other.confidence &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(
    id,
    targetId,
    type,
    position,
    rotation,
    trackingState,
    confidence,
    lastUpdated,
  );
}
