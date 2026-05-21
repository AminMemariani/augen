import 'package:augen/augen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARPlane.fromMap (normalized iOS/Android shape)', () {
    test('parses horizontal plane with nested center/extent', () {
      final plane = ARPlane.fromMap({
        'id': 'plane-h-1',
        'center': {'x': 1.0, 'y': 2.0, 'z': 3.0},
        'extent': {'x': 4.0, 'y': 0.1, 'z': 5.0},
        'type': 'horizontal',
      });

      expect(plane.id, 'plane-h-1');
      expect(plane.center, const Vector3(1.0, 2.0, 3.0));
      expect(plane.extent, const Vector3(4.0, 0.1, 5.0));
      expect(plane.type, PlaneType.horizontal);
    });

    test('parses vertical plane with nested center/extent', () {
      final plane = ARPlane.fromMap({
        'id': 'plane-v-1',
        'center': {'x': -0.5, 'y': 1.0, 'z': 0.0},
        'extent': {'x': 2.0, 'y': 2.0, 'z': 0.05},
        'type': 'vertical',
      });

      expect(plane.type, PlaneType.vertical);
      expect(plane.center.x, -0.5);
      expect(plane.extent.z, 0.05);
    });

    test('unknown type string falls back to PlaneType.unknown', () {
      final plane = ARPlane.fromMap({
        'id': 'plane-u',
        'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'extent': {'x': 1.0, 'y': 1.0, 'z': 1.0},
        'type': 'ceiling',
      });
      expect(plane.type, PlaneType.unknown);
    });

    test('type matching is case-insensitive', () {
      final plane = ARPlane.fromMap({
        'id': 'plane-c',
        'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'extent': {'x': 1.0, 'y': 0.0, 'z': 1.0},
        'type': 'HORIZONTAL',
      });
      expect(plane.type, PlaneType.horizontal);
    });

    test('toMap round-trips through fromMap', () {
      final original = ARPlane(
        id: 'rt-1',
        center: const Vector3(0.25, 0.5, 0.75),
        extent: const Vector3(1.25, 0.05, 2.5),
        type: PlaneType.horizontal,
      );
      final round = ARPlane.fromMap(original.toMap());

      expect(round.id, original.id);
      expect(round.center, original.center);
      expect(round.extent, original.extent);
      expect(round.type, original.type);
    });

    test('handles num (int) coordinates from platform channel', () {
      // Platform channel may deliver ints when values are whole numbers.
      final plane = ARPlane.fromMap({
        'id': 'plane-int',
        'center': {'x': 1, 'y': 2, 'z': 3},
        'extent': {'x': 4, 'y': 0, 'z': 5},
        'type': 'horizontal',
      });
      expect(plane.center, const Vector3(1.0, 2.0, 3.0));
      expect(plane.extent, const Vector3(4.0, 0.0, 5.0));
    });
  });
}
