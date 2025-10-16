import 'vector3.dart';
import 'quaternion.dart';
import 'ar_image_target.dart';

/// Tracking state of an image
enum ImageTrackingState {
  /// Image is being tracked
  tracked,

  /// Image was tracked but is no longer visible
  notTracked,

  /// Image tracking is paused
  paused,

  /// Image tracking failed
  failed,
}

/// Represents a tracked image in AR space
class ARTrackedImage {
  final String id;
  final String targetId;
  final Vector3 position;
  final Quaternion rotation;
  final ImageTargetSize estimatedSize;
  final ImageTrackingState trackingState;
  final double confidence;
  final DateTime lastUpdated;

  ARTrackedImage({
    required this.id,
    required this.targetId,
    required this.position,
    required this.rotation,
    required this.estimatedSize,
    required this.trackingState,
    required this.confidence,
    required this.lastUpdated,
  });

  factory ARTrackedImage.fromMap(Map<dynamic, dynamic> map) {
    return ARTrackedImage(
      id: map['id'] as String,
      targetId: map['targetId'] as String,
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      estimatedSize: ImageTargetSize.fromMap(map['estimatedSize'] as Map),
      trackingState: _parseTrackingState(map['trackingState'] as String),
      confidence: (map['confidence'] as num).toDouble(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
    );
  }

  static ImageTrackingState _parseTrackingState(String state) {
    switch (state.toLowerCase()) {
      case 'tracked':
        return ImageTrackingState.tracked;
      case 'nottracked':
      case 'not_tracked':
        return ImageTrackingState.notTracked;
      case 'paused':
        return ImageTrackingState.paused;
      case 'failed':
        return ImageTrackingState.failed;
      default:
        return ImageTrackingState.notTracked;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetId': targetId,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'estimatedSize': estimatedSize.toMap(),
      'trackingState': trackingState.name,
      'confidence': confidence,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Whether the image is currently being tracked
  bool get isTracked => trackingState == ImageTrackingState.tracked;

  /// Whether the image tracking is reliable (high confidence)
  bool get isReliable => confidence > 0.7;

  @override
  String toString() =>
      'ARTrackedImage(id: $id, targetId: $targetId, state: $trackingState, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARTrackedImage &&
          id == other.id &&
          targetId == other.targetId &&
          position == other.position &&
          rotation == other.rotation &&
          estimatedSize == other.estimatedSize &&
          trackingState == other.trackingState &&
          confidence == other.confidence &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(
    id,
    targetId,
    position,
    rotation,
    estimatedSize,
    trackingState,
    confidence,
    lastUpdated,
  );
}
