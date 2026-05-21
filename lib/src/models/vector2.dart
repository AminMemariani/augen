/// Represents a 2D vector
class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);

  factory Vector2.zero() => const Vector2(0, 0);

  factory Vector2.fromMap(Map<dynamic, dynamic> map) {
    return Vector2(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y};
  }

  @override
  String toString() => 'Vector2($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
