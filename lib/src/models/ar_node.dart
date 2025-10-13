import 'vector3.dart';
import 'quaternion.dart';

/// Types of AR nodes that can be added to the scene
enum NodeType { sphere, cube, cylinder, model }

/// Represents a 3D node in the AR scene
class ARNode {
  final String id;
  final NodeType type;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;
  final Map<String, dynamic>? properties;

  ARNode({
    required this.id,
    required this.type,
    required this.position,
    this.rotation = const Quaternion(0, 0, 0, 1),
    this.scale = const Vector3(1, 1, 1),
    this.properties,
  });

  factory ARNode.fromMap(Map<dynamic, dynamic> map) {
    return ARNode(
      id: map['id'] as String,
      type: _parseNodeType(map['type'] as String),
      position: Vector3.fromMap(map['position'] as Map),
      rotation: Quaternion.fromMap(map['rotation'] as Map),
      scale: Vector3.fromMap(map['scale'] as Map),
      properties: map['properties'] as Map<String, dynamic>?,
    );
  }

  static NodeType _parseNodeType(String type) {
    switch (type.toLowerCase()) {
      case 'sphere':
        return NodeType.sphere;
      case 'cube':
        return NodeType.cube;
      case 'cylinder':
        return NodeType.cylinder;
      case 'model':
        return NodeType.model;
      default:
        return NodeType.sphere;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'properties': properties,
    };
  }

  ARNode copyWith({
    String? id,
    NodeType? type,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    Map<String, dynamic>? properties,
  }) {
    return ARNode(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      properties: properties ?? this.properties,
    );
  }

  @override
  String toString() => 'ARNode(id: $id, type: $type, position: $position)';
}
