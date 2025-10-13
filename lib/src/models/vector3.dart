/// Represents a 3D vector
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  factory Vector3.zero() => const Vector3(0, 0, 0);

  factory Vector3.fromMap(Map<dynamic, dynamic> map) {
    return Vector3(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y, 'z': z};
  }

  @override
  String toString() => 'Vector3($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}
