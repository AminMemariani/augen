import 'vector3.dart';
import 'quaternion.dart';

/// Represents an AR anchor in 3D space
class ARAnchor {
  final String id;
  final Vector3 position;
  final Quaternion rotation;
  final DateTime timestamp;

  ARAnchor({
    required this.id,
    required this.position,
    required this.rotation,
    required this.timestamp,
  });

  factory ARAnchor.fromMap(Map<dynamic, dynamic> map) {
    return ARAnchor(
      id: map['id'] as String,
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'ARAnchor(id: $id, position: $position, rotation: $rotation)';
}
