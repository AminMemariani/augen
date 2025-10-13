import 'vector3.dart';

/// Types of detected planes
enum PlaneType { horizontal, vertical, unknown }

/// Represents a detected plane in AR
class ARPlane {
  final String id;
  final Vector3 center;
  final Vector3 extent;
  final PlaneType type;

  ARPlane({
    required this.id,
    required this.center,
    required this.extent,
    required this.type,
  });

  factory ARPlane.fromMap(Map<dynamic, dynamic> map) {
    return ARPlane(
      id: map['id'] as String,
      center: Vector3.fromMap(map['center'] as Map),
      extent: Vector3.fromMap(map['extent'] as Map),
      type: _parsePlaneType(map['type'] as String),
    );
  }

  static PlaneType _parsePlaneType(String type) {
    switch (type.toLowerCase()) {
      case 'horizontal':
        return PlaneType.horizontal;
      case 'vertical':
        return PlaneType.vertical;
      default:
        return PlaneType.unknown;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'center': center.toMap(),
      'extent': extent.toMap(),
      'type': type.name,
    };
  }

  @override
  String toString() => 'ARPlane(id: $id, center: $center, type: $type)';
}
