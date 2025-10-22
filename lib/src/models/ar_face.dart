import 'package:augen/src/models/vector3.dart';
import 'package:augen/src/models/quaternion.dart';

/// Represents the tracking state of a face
enum FaceTrackingState { tracked, notTracked, paused, failed }

/// Represents a facial landmark point
class FaceLandmark {
  final String name;
  final Vector3 position;
  final double confidence;

  const FaceLandmark({
    required this.name,
    required this.position,
    required this.confidence,
  });

  factory FaceLandmark.fromMap(Map<dynamic, dynamic> map) {
    return FaceLandmark(
      name: map['name'] as String,
      position: Vector3.fromMap(map['position'] as Map),
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'position': position.toMap(),
      'confidence': confidence,
    };
  }

  @override
  String toString() =>
      'FaceLandmark(name: $name, position: $position, confidence: $confidence)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceLandmark &&
          name == other.name &&
          position == other.position &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(name, position, confidence);
}

/// Represents a tracked face in the AR scene
class ARFace {
  final String id;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;
  final FaceTrackingState trackingState;
  final double confidence;
  final List<FaceLandmark> landmarks;
  final DateTime lastUpdated;

  ARFace({
    required this.id,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.trackingState,
    required this.confidence,
    required this.landmarks,
    required this.lastUpdated,
  });

  /// Returns true if the face is currently being tracked.
  bool get isTracked => trackingState == FaceTrackingState.tracked;

  /// Returns true if the tracking confidence is high (e.g., > 0.7).
  bool get isReliable => confidence > 0.7;

  /// Returns the center point of the face
  Vector3 get center => position;

  /// Returns the face's bounding box dimensions
  Vector3 get dimensions => scale;

  factory ARFace.fromMap(Map<dynamic, dynamic> map) {
    return ARFace(
      id: map['id'] as String,
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      scale: Vector3.fromMap(map['scale'] as Map),
      trackingState: _parseFaceTrackingState(map['trackingState'] as String),
      confidence: (map['confidence'] as num).toDouble(),
      landmarks: (map['landmarks'] as List)
          .map((e) => FaceLandmark.fromMap(e as Map))
          .toList(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'trackingState': trackingState.name,
      'confidence': confidence,
      'landmarks': landmarks.map((e) => e.toMap()).toList(),
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  static FaceTrackingState _parseFaceTrackingState(String state) {
    switch (state.toLowerCase()) {
      case 'tracked':
        return FaceTrackingState.tracked;
      case 'nottracked':
        return FaceTrackingState.notTracked;
      case 'paused':
        return FaceTrackingState.paused;
      case 'failed':
        return FaceTrackingState.failed;
      default:
        return FaceTrackingState.notTracked; // Default or error state
    }
  }

  @override
  String toString() =>
      'ARFace(id: $id, trackingState: $trackingState, confidence: $confidence, landmarks: ${landmarks.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARFace &&
          id == other.id &&
          position == other.position &&
          rotation == other.rotation &&
          scale == other.scale &&
          trackingState == other.trackingState &&
          confidence == other.confidence &&
          landmarks == other.landmarks &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(
    id,
    position,
    rotation,
    scale,
    trackingState,
    confidence,
    landmarks,
    lastUpdated,
  );
}
