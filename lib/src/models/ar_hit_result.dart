import 'vector3.dart';
import 'quaternion.dart';

/// Represents a hit test result from AR ray casting
class ARHitResult {
  final Vector3 position;
  final Quaternion rotation;
  final double distance;
  final String? planeId;

  ARHitResult({
    required this.position,
    required this.rotation,
    required this.distance,
    this.planeId,
  });

  factory ARHitResult.fromMap(Map<dynamic, dynamic> map) {
    return ARHitResult(
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      distance: (map['distance'] as num).toDouble(),
      planeId: map['planeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'distance': distance,
      'planeId': planeId,
    };
  }

  @override
  String toString() => 'ARHitResult(position: $position, distance: $distance)';
}
