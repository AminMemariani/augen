import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Models Tests', () {
    group('Vector3', () {
      test('creates vector with correct values', () {
        final vector = Vector3(1.0, 2.0, 3.0);
        expect(vector.x, 1.0);
        expect(vector.y, 2.0);
        expect(vector.z, 3.0);
      });

      test('creates zero vector', () {
        final vector = Vector3.zero();
        expect(vector.x, 0.0);
        expect(vector.y, 0.0);
        expect(vector.z, 0.0);
      });

      test('converts to and from map', () {
        final vector = Vector3(1.5, 2.5, 3.5);
        final map = vector.toMap();
        final fromMap = Vector3.fromMap(map);

        expect(fromMap.x, vector.x);
        expect(fromMap.y, vector.y);
        expect(fromMap.z, vector.z);
      });

      test('equality works correctly', () {
        final v1 = Vector3(1.0, 2.0, 3.0);
        final v2 = Vector3(1.0, 2.0, 3.0);
        final v3 = Vector3(1.0, 2.0, 4.0);

        expect(v1, equals(v2));
        expect(v1, isNot(equals(v3)));
      });

      test('toString returns correct format', () {
        final vector = Vector3(1.0, 2.0, 3.0);
        expect(vector.toString(), 'Vector3(1.0, 2.0, 3.0)');
      });
    });

    group('Quaternion', () {
      test('creates quaternion with correct values', () {
        final quat = Quaternion(0.1, 0.2, 0.3, 0.4);
        expect(quat.x, 0.1);
        expect(quat.y, 0.2);
        expect(quat.z, 0.3);
        expect(quat.w, 0.4);
      });

      test('creates identity quaternion', () {
        final quat = Quaternion.identity();
        expect(quat.x, 0.0);
        expect(quat.y, 0.0);
        expect(quat.z, 0.0);
        expect(quat.w, 1.0);
      });

      test('converts to and from map', () {
        final quat = Quaternion(0.1, 0.2, 0.3, 0.4);
        final map = quat.toMap();
        final fromMap = Quaternion.fromMap(map);

        expect(fromMap.x, quat.x);
        expect(fromMap.y, quat.y);
        expect(fromMap.z, quat.z);
        expect(fromMap.w, quat.w);
      });

      test('equality works correctly', () {
        final q1 = Quaternion(0.1, 0.2, 0.3, 0.4);
        final q2 = Quaternion(0.1, 0.2, 0.3, 0.4);
        final q3 = Quaternion(0.1, 0.2, 0.3, 0.5);

        expect(q1, equals(q2));
        expect(q1, isNot(equals(q3)));
      });

      test('toString returns correct format', () {
        final quat = Quaternion(0.1, 0.2, 0.3, 0.4);
        expect(quat.toString(), 'Quaternion(0.1, 0.2, 0.3, 0.4)');
      });
    });

    group('ARNode', () {
      test('creates node with required parameters', () {
        final node = ARNode(
          id: 'node1',
          type: NodeType.sphere,
          position: Vector3(1.0, 2.0, 3.0),
        );

        expect(node.id, 'node1');
        expect(node.type, NodeType.sphere);
        expect(node.position, Vector3(1.0, 2.0, 3.0));
        expect(node.rotation, Quaternion.identity());
        expect(node.scale, Vector3(1.0, 1.0, 1.0));
      });

      test('creates node with all parameters', () {
        final node = ARNode(
          id: 'node1',
          type: NodeType.cube,
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          scale: Vector3(2.0, 2.0, 2.0),
          properties: {'color': 'red'},
        );

        expect(node.properties?['color'], 'red');
        expect(node.scale, Vector3(2.0, 2.0, 2.0));
      });

      test('converts to and from map', () {
        final node = ARNode(
          id: 'node1',
          type: NodeType.cylinder,
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          scale: Vector3(2.0, 2.0, 2.0),
          properties: {'color': 'blue'},
        );

        final map = node.toMap();
        final fromMap = ARNode.fromMap(map);

        expect(fromMap.id, node.id);
        expect(fromMap.type, node.type);
        expect(fromMap.position, node.position);
        expect(fromMap.rotation, node.rotation);
        expect(fromMap.scale, node.scale);
        expect(fromMap.properties?['color'], 'blue');
      });

      test('copyWith creates modified copy', () {
        final node = ARNode(
          id: 'node1',
          type: NodeType.sphere,
          position: Vector3(1.0, 2.0, 3.0),
        );

        final modified = node.copyWith(
          id: 'node2',
          position: Vector3(4.0, 5.0, 6.0),
        );

        expect(modified.id, 'node2');
        expect(modified.position, Vector3(4.0, 5.0, 6.0));
        expect(modified.type, node.type);
      });

      test('parses all node types correctly', () {
        final sphere = ARNode.fromMap({
          'id': 'n1',
          'type': 'sphere',
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
        });
        expect(sphere.type, NodeType.sphere);

        final cube = ARNode.fromMap({
          'id': 'n2',
          'type': 'cube',
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
        });
        expect(cube.type, NodeType.cube);

        final cylinder = ARNode.fromMap({
          'id': 'n3',
          'type': 'cylinder',
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
        });
        expect(cylinder.type, NodeType.cylinder);
      });

      test('creates model node with factory constructor', () {
        final model = ARNode.fromModel(
          id: 'model1',
          modelPath: 'assets/models/object.glb',
          position: Vector3(1.0, 2.0, 3.0),
          scale: Vector3(0.5, 0.5, 0.5),
        );

        expect(model.type, NodeType.model);
        expect(model.modelPath, 'assets/models/object.glb');
        expect(model.modelFormat, ModelFormat.glb);
        expect(model.position, Vector3(1.0, 2.0, 3.0));
      });

      test('detects model format from file extension', () {
        expect(ARNode.detectModelFormat('model.glb'), ModelFormat.glb);
        expect(ARNode.detectModelFormat('model.gltf'), ModelFormat.gltf);
        expect(ARNode.detectModelFormat('model.obj'), ModelFormat.obj);
        expect(ARNode.detectModelFormat('model.usdz'), ModelFormat.usdz);
        expect(ARNode.detectModelFormat('model.unknown'), isNull);
      });

      test('model node requires modelPath', () {
        expect(
          () => ARNode(
            id: 'model1',
            type: NodeType.model,
            position: Vector3.zero(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('model node serialization includes modelPath and format', () {
        final model = ARNode.fromModel(
          id: 'model1',
          modelPath: 'assets/models/spaceship.glb',
          position: Vector3(1.0, 2.0, 3.0),
          modelFormat: ModelFormat.glb,
        );

        final map = model.toMap();
        expect(map['type'], 'model');
        expect(map['modelPath'], 'assets/models/spaceship.glb');
        expect(map['modelFormat'], 'glb');
      });

      test('model node deserialization includes modelPath and format', () {
        final map = {
          'id': 'model1',
          'type': 'model',
          'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 0.5, 'y': 0.5, 'z': 0.5},
          'modelPath': 'assets/models/car.glb',
          'modelFormat': 'glb',
        };

        final model = ARNode.fromMap(map);
        expect(model.type, NodeType.model);
        expect(model.modelPath, 'assets/models/car.glb');
        expect(model.modelFormat, ModelFormat.glb);
      });

      test('copyWith preserves model properties', () {
        final original = ARNode.fromModel(
          id: 'model1',
          modelPath: 'assets/models/object.glb',
          position: Vector3.zero(),
        );

        final modified = original.copyWith(
          position: Vector3(1, 2, 3),
          scale: Vector3(2, 2, 2),
        );

        expect(modified.modelPath, original.modelPath);
        expect(modified.modelFormat, original.modelFormat);
        expect(modified.type, NodeType.model);
        expect(modified.position, Vector3(1, 2, 3));
      });
    });

    group('ModelFormat', () {
      test('all formats are available', () {
        expect(ModelFormat.values.length, 4);
        expect(ModelFormat.values, contains(ModelFormat.gltf));
        expect(ModelFormat.values, contains(ModelFormat.glb));
        expect(ModelFormat.values, contains(ModelFormat.obj));
        expect(ModelFormat.values, contains(ModelFormat.usdz));
      });

      test('format names are correct', () {
        expect(ModelFormat.gltf.name, 'gltf');
        expect(ModelFormat.glb.name, 'glb');
        expect(ModelFormat.obj.name, 'obj');
        expect(ModelFormat.usdz.name, 'usdz');
      });
    });

    group('ARSessionConfig', () {
      test('creates default config', () {
        const config = ARSessionConfig();
        expect(config.planeDetection, true);
        expect(config.lightEstimation, true);
        expect(config.depthData, false);
        expect(config.autoFocus, true);
      });

      test('creates custom config', () {
        const config = ARSessionConfig(
          planeDetection: false,
          lightEstimation: false,
          depthData: true,
          autoFocus: false,
        );

        expect(config.planeDetection, false);
        expect(config.lightEstimation, false);
        expect(config.depthData, true);
        expect(config.autoFocus, false);
      });

      test('converts to and from map', () {
        const config = ARSessionConfig(
          planeDetection: true,
          lightEstimation: false,
          depthData: true,
          autoFocus: false,
        );

        final map = config.toMap();
        final fromMap = ARSessionConfig.fromMap(map);

        expect(fromMap.planeDetection, config.planeDetection);
        expect(fromMap.lightEstimation, config.lightEstimation);
        expect(fromMap.depthData, config.depthData);
        expect(fromMap.autoFocus, config.autoFocus);
      });

      test('copyWith creates modified copy', () {
        const config = ARSessionConfig();
        final modified = config.copyWith(
          planeDetection: false,
          depthData: true,
        );

        expect(modified.planeDetection, false);
        expect(modified.depthData, true);
        expect(modified.lightEstimation, config.lightEstimation);
        expect(modified.autoFocus, config.autoFocus);
      });
    });

    group('ARPlane', () {
      test('creates plane with correct values', () {
        final plane = ARPlane(
          id: 'plane1',
          center: Vector3(1.0, 2.0, 3.0),
          extent: Vector3(0.5, 0.1, 0.5),
          type: PlaneType.horizontal,
        );

        expect(plane.id, 'plane1');
        expect(plane.center, Vector3(1.0, 2.0, 3.0));
        expect(plane.extent, Vector3(0.5, 0.1, 0.5));
        expect(plane.type, PlaneType.horizontal);
      });

      test('converts to and from map', () {
        final plane = ARPlane(
          id: 'plane1',
          center: Vector3(1.0, 2.0, 3.0),
          extent: Vector3(0.5, 0.1, 0.5),
          type: PlaneType.vertical,
        );

        final map = plane.toMap();
        final fromMap = ARPlane.fromMap(map);

        expect(fromMap.id, plane.id);
        expect(fromMap.center, plane.center);
        expect(fromMap.extent, plane.extent);
        expect(fromMap.type, plane.type);
      });

      test('parses all plane types correctly', () {
        final horizontal = ARPlane.fromMap({
          'id': 'p1',
          'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'extent': {'x': 1.0, 'y': 0.1, 'z': 1.0},
          'type': 'horizontal',
        });
        expect(horizontal.type, PlaneType.horizontal);

        final vertical = ARPlane.fromMap({
          'id': 'p2',
          'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'extent': {'x': 1.0, 'y': 1.0, 'z': 0.1},
          'type': 'vertical',
        });
        expect(vertical.type, PlaneType.vertical);

        final unknown = ARPlane.fromMap({
          'id': 'p3',
          'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'extent': {'x': 1.0, 'y': 1.0, 'z': 1.0},
          'type': 'other',
        });
        expect(unknown.type, PlaneType.unknown);
      });

      test('toString returns correct format', () {
        final plane = ARPlane(
          id: 'plane1',
          center: Vector3(1.0, 2.0, 3.0),
          extent: Vector3(0.5, 0.1, 0.5),
          type: PlaneType.horizontal,
        );
        expect(plane.toString(), contains('ARPlane'));
        expect(plane.toString(), contains('plane1'));
      });
    });

    group('ARAnchor', () {
      test('creates anchor with correct values', () {
        final timestamp = DateTime.now();
        final anchor = ARAnchor(
          id: 'anchor1',
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          timestamp: timestamp,
        );

        expect(anchor.id, 'anchor1');
        expect(anchor.position, Vector3(1.0, 2.0, 3.0));
        expect(anchor.rotation, Quaternion(0.1, 0.2, 0.3, 0.4));
        expect(anchor.timestamp, timestamp);
      });

      test('converts to and from map', () {
        final timestamp = DateTime.now();
        final anchor = ARAnchor(
          id: 'anchor1',
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          timestamp: timestamp,
        );

        final map = anchor.toMap();
        final fromMap = ARAnchor.fromMap(map);

        expect(fromMap.id, anchor.id);
        expect(fromMap.position, anchor.position);
        expect(fromMap.rotation, anchor.rotation);
        expect(
          fromMap.timestamp.millisecondsSinceEpoch,
          anchor.timestamp.millisecondsSinceEpoch,
        );
      });

      test('toString returns correct format', () {
        final timestamp = DateTime.now();
        final anchor = ARAnchor(
          id: 'anchor1',
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          timestamp: timestamp,
        );
        expect(anchor.toString(), contains('ARAnchor'));
        expect(anchor.toString(), contains('anchor1'));
      });
    });

    group('ARHitResult', () {
      test('creates hit result with correct values', () {
        final hitResult = ARHitResult(
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          distance: 1.5,
          planeId: 'plane1',
        );

        expect(hitResult.position, Vector3(1.0, 2.0, 3.0));
        expect(hitResult.rotation, Quaternion(0.1, 0.2, 0.3, 0.4));
        expect(hitResult.distance, 1.5);
        expect(hitResult.planeId, 'plane1');
      });

      test('creates hit result without planeId', () {
        final hitResult = ARHitResult(
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          distance: 1.5,
        );

        expect(hitResult.planeId, isNull);
      });

      test('converts to and from map', () {
        final hitResult = ARHitResult(
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          distance: 1.5,
          planeId: 'plane1',
        );

        final map = hitResult.toMap();
        final fromMap = ARHitResult.fromMap(map);

        expect(fromMap.position, hitResult.position);
        expect(fromMap.rotation, hitResult.rotation);
        expect(fromMap.distance, hitResult.distance);
        expect(fromMap.planeId, hitResult.planeId);
      });

      test('toString returns correct format', () {
        final hitResult = ARHitResult(
          position: Vector3(1.0, 2.0, 3.0),
          rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
          distance: 1.5,
        );
        expect(hitResult.toString(), contains('ARHitResult'));
        expect(hitResult.toString(), contains('1.5'));
      });
    });
  });
}
