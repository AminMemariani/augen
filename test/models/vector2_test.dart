import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Vector2', () {
    test('construction', () {
      const v = Vector2(3.5, 7.2);
      expect(v.x, 3.5);
      expect(v.y, 7.2);
    });

    test('zero factory', () {
      final v = Vector2.zero();
      expect(v.x, 0);
      expect(v.y, 0);
    });

    test('toMap', () {
      const v = Vector2(1.0, 2.0);
      expect(v.toMap(), {'x': 1.0, 'y': 2.0});
    });

    test('fromMap', () {
      final v = Vector2.fromMap({'x': 3.0, 'y': 4.0});
      expect(v, const Vector2(3.0, 4.0));
    });

    test('fromMap with int values', () {
      final v = Vector2.fromMap({'x': 3, 'y': 4});
      expect(v, const Vector2(3.0, 4.0));
    });

    test('toMap/fromMap round-trip', () {
      const original = Vector2(5.5, -2.3);
      final restored = Vector2.fromMap(original.toMap());
      expect(restored, original);
    });

    test('equality', () {
      const a = Vector2(1.0, 2.0);
      const b = Vector2(1.0, 2.0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality', () {
      const a = Vector2(1.0, 2.0);
      const b = Vector2(1.0, 3.0);
      expect(a, isNot(b));
    });

    test('toString', () {
      const v = Vector2(1.0, 2.0);
      expect(v.toString(), 'Vector2(1.0, 2.0)');
    });
  });
}
