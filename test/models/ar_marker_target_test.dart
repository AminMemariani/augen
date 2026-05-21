import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('ARMarkerType', () {
    test('has expected values', () {
      expect(ARMarkerType.values, [
        ARMarkerType.pattern,
        ARMarkerType.barcode,
        ARMarkerType.aruco,
      ]);
    });
  });

  group('ARArucoDictionary', () {
    test('has expected values', () {
      expect(ARArucoDictionary.values.length, 5);
      expect(ARArucoDictionary.dict4x4_50, isNotNull);
      expect(ARArucoDictionary.dict7x7_1000, isNotNull);
    });
  });

  group('ARMarkerTarget', () {
    ARMarkerTarget createPatternTarget() {
      return const ARMarkerTarget(
        id: 'marker-1',
        name: 'Test Pattern',
        type: ARMarkerType.pattern,
        physicalWidth: 0.1,
        patternPath: 'assets/pattern.patt',
      );
    }

    ARMarkerTarget createBarcodeTarget() {
      return const ARMarkerTarget(
        id: 'marker-2',
        name: 'Test Barcode',
        type: ARMarkerType.barcode,
        physicalWidth: 0.08,
        barcodeId: 42,
      );
    }

    ARMarkerTarget createArucoTarget() {
      return const ARMarkerTarget(
        id: 'marker-3',
        name: 'Test ArUco',
        type: ARMarkerType.aruco,
        physicalWidth: 0.05,
        arucoId: 7,
        arucoDictionary: ARArucoDictionary.dict5x5_100,
      );
    }

    ARMarkerTarget createFullTarget() {
      return const ARMarkerTarget(
        id: 'full-1',
        name: 'Full Marker',
        type: ARMarkerType.aruco,
        physicalWidth: 0.12,
        physicalHeight: 0.14,
        patternPath: 'path.patt',
        barcodeId: 10,
        arucoId: 5,
        arucoDictionary: ARArucoDictionary.dict6x6_250,
        isActive: false,
        metadata: {'key': 'value'},
      );
    }

    test('construction with all fields', () {
      final t = createFullTarget();
      expect(t.id, 'full-1');
      expect(t.name, 'Full Marker');
      expect(t.type, ARMarkerType.aruco);
      expect(t.physicalWidth, 0.12);
      expect(t.physicalHeight, 0.14);
      expect(t.patternPath, 'path.patt');
      expect(t.barcodeId, 10);
      expect(t.arucoId, 5);
      expect(t.arucoDictionary, ARArucoDictionary.dict6x6_250);
      expect(t.isActive, false);
      expect(t.metadata, {'key': 'value'});
    });

    test('default values', () {
      const t = ARMarkerTarget(
        id: 'x',
        name: 'y',
        type: ARMarkerType.pattern,
        physicalWidth: 0.1,
      );
      expect(t.isActive, true);
      expect(t.physicalHeight, isNull);
      expect(t.patternPath, isNull);
      expect(t.barcodeId, isNull);
      expect(t.arucoId, isNull);
      expect(t.arucoDictionary, isNull);
      expect(t.metadata, isNull);
    });

    test('pattern marker creation', () {
      final t = createPatternTarget();
      expect(t.type, ARMarkerType.pattern);
      expect(t.patternPath, 'assets/pattern.patt');
    });

    test('barcode marker creation', () {
      final t = createBarcodeTarget();
      expect(t.type, ARMarkerType.barcode);
      expect(t.barcodeId, 42);
    });

    test('aruco marker creation', () {
      final t = createArucoTarget();
      expect(t.type, ARMarkerType.aruco);
      expect(t.arucoId, 7);
      expect(t.arucoDictionary, ARArucoDictionary.dict5x5_100);
    });

    test('toMap produces correct map', () {
      final map = createFullTarget().toMap();
      expect(map['id'], 'full-1');
      expect(map['name'], 'Full Marker');
      expect(map['type'], 'aruco');
      expect(map['physicalWidth'], 0.12);
      expect(map['physicalHeight'], 0.14);
      expect(map['patternPath'], 'path.patt');
      expect(map['barcodeId'], 10);
      expect(map['arucoId'], 5);
      expect(map['arucoDictionary'], 'dict6x6_250');
      expect(map['isActive'], false);
      expect(map['metadata'], {'key': 'value'});
    });

    test('toMap omits null fields', () {
      final map = createPatternTarget().toMap();
      expect(map.containsKey('physicalHeight'), false);
      expect(map.containsKey('imagePath'), false);
      expect(map.containsKey('barcodeId'), false);
      expect(map.containsKey('arucoId'), false);
      expect(map.containsKey('arucoDictionary'), false);
      expect(map.containsKey('metadata'), false);
    });

    test('imagePath is supported for PNG-based markers', () {
      const target = ARMarkerTarget(
        id: 'png-marker',
        name: 'PNG Marker',
        type: ARMarkerType.pattern,
        physicalWidth: 0.08,
        imagePath: 'assets/markers/Hiro_marker.png',
      );
      expect(target.imagePath, 'assets/markers/Hiro_marker.png');
      expect(target.patternPath, isNull);

      final map = target.toMap();
      expect(map['imagePath'], 'assets/markers/Hiro_marker.png');
      expect(map.containsKey('patternPath'), false);

      final round = ARMarkerTarget.fromMap(map);
      expect(round.imagePath, target.imagePath);
      expect(round, equals(target));
    });

    test('copyWith preserves and updates imagePath', () {
      const a = ARMarkerTarget(
        id: 'm',
        name: 'M',
        type: ARMarkerType.pattern,
        physicalWidth: 0.05,
        imagePath: 'assets/a.png',
      );
      final b = a.copyWith(imagePath: 'assets/b.png');
      expect(b.imagePath, 'assets/b.png');
      expect(b.id, a.id);

      final c = a.copyWith();
      expect(c.imagePath, a.imagePath);
    });

    test('fromMap parses correctly', () {
      final original = createFullTarget();
      final restored = ARMarkerTarget.fromMap(original.toMap());
      expect(restored, original);
    });

    test('fromMap enum string parsing', () {
      final t = ARMarkerTarget.fromMap({
        'id': 'x',
        'name': 'y',
        'type': 'BARCODE',
        'physicalWidth': 0.1,
      });
      expect(t.type, ARMarkerType.barcode);
    });

    test('fromMap aruco dictionary parsing', () {
      for (final dict in ARArucoDictionary.values) {
        final t = ARMarkerTarget.fromMap({
          'id': 'x',
          'name': 'y',
          'type': 'aruco',
          'physicalWidth': 0.1,
          'arucoDictionary': dict.name,
        });
        expect(t.arucoDictionary, dict);
      }
    });

    test('fromMap unknown type defaults to pattern', () {
      final t = ARMarkerTarget.fromMap({
        'id': 'x',
        'name': 'y',
        'type': 'unknown',
        'physicalWidth': 0.1,
      });
      expect(t.type, ARMarkerType.pattern);
    });

    test('fromMap isActive defaults to true', () {
      final t = ARMarkerTarget.fromMap({
        'id': 'x',
        'name': 'y',
        'type': 'pattern',
        'physicalWidth': 0.1,
      });
      expect(t.isActive, true);
    });

    test('copyWith works', () {
      final original = createPatternTarget();
      final copied = original.copyWith(name: 'New Name', isActive: false);
      expect(copied.id, original.id);
      expect(copied.name, 'New Name');
      expect(copied.isActive, false);
      expect(copied.type, original.type);
    });

    test('copyWith no changes returns equal', () {
      final original = createFullTarget();
      final copied = original.copyWith();
      expect(copied, original);
    });

    test('equality', () {
      final a = createPatternTarget();
      final b = createPatternTarget();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality on different id', () {
      final a = createPatternTarget();
      final b = a.copyWith(id: 'different');
      expect(a, isNot(b));
    });

    test('toMap/fromMap round-trip', () {
      final targets = [
        createPatternTarget(),
        createBarcodeTarget(),
        createArucoTarget(),
        createFullTarget(),
      ];
      for (final t in targets) {
        expect(ARMarkerTarget.fromMap(t.toMap()), t);
      }
    });
  });
}
