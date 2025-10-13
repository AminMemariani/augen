/// Represents a quaternion for 3D rotations
class Quaternion {
  final double x;
  final double y;
  final double z;
  final double w;

  const Quaternion(this.x, this.y, this.z, this.w);

  factory Quaternion.identity() => const Quaternion(0, 0, 0, 1);

  factory Quaternion.fromMap(Map<dynamic, dynamic> map) {
    return Quaternion(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['z'] as num).toDouble(),
      (map['w'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y, 'z': z, 'w': w};
  }

  @override
  String toString() => 'Quaternion($x, $y, $z, $w)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quaternion &&
          x == other.x &&
          y == other.y &&
          z == other.z &&
          w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}
