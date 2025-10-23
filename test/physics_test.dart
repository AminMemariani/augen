import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('PhysicsBodyType', () {
    test('has correct enum values', () {
      expect(PhysicsBodyType.values, [
        PhysicsBodyType.static,
        PhysicsBodyType.dynamic,
        PhysicsBodyType.kinematic,
      ]);
    });

    test('enum names are correct', () {
      expect(PhysicsBodyType.static.name, 'static');
      expect(PhysicsBodyType.dynamic.name, 'dynamic');
      expect(PhysicsBodyType.kinematic.name, 'kinematic');
    });
  });

  group('PhysicsMaterial', () {
    final testMaterial = const PhysicsMaterial(
      density: 2.0,
      friction: 0.8,
      restitution: 0.5,
      linearDamping: 0.1,
      angularDamping: 0.2,
    );

    test('creates with correct properties', () {
      expect(testMaterial.density, 2.0);
      expect(testMaterial.friction, 0.8);
      expect(testMaterial.restitution, 0.5);
      expect(testMaterial.linearDamping, 0.1);
      expect(testMaterial.angularDamping, 0.2);
    });

    test('creates with default values', () {
      const defaultMaterial = PhysicsMaterial();
      expect(defaultMaterial.density, 1.0);
      expect(defaultMaterial.friction, 0.5);
      expect(defaultMaterial.restitution, 0.0);
      expect(defaultMaterial.linearDamping, 0.0);
      expect(defaultMaterial.angularDamping, 0.0);
    });

    test('converts to and from map', () {
      final map = testMaterial.toMap();
      final fromMap = PhysicsMaterial.fromMap(map);
      expect(fromMap, testMaterial);
    });

    test('equality works correctly', () {
      const anotherMaterial = PhysicsMaterial(
        density: 2.0,
        friction: 0.8,
        restitution: 0.5,
        linearDamping: 0.1,
        angularDamping: 0.2,
      );
      expect(testMaterial, anotherMaterial);
      expect(testMaterial == anotherMaterial, true);

      const differentMaterial = PhysicsMaterial(
        density: 1.0,
        friction: 0.8,
        restitution: 0.5,
        linearDamping: 0.1,
        angularDamping: 0.2,
      );
      expect(testMaterial == differentMaterial, false);
    });

    test('toString works correctly', () {
      expect(testMaterial.toString(), contains('PhysicsMaterial(density: 2.0'));
    });
  });

  group('ARPhysicsBody', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch);
    final testBody = ARPhysicsBody(
      id: 'body1',
      nodeId: 'node1',
      type: PhysicsBodyType.dynamic,
      material: const PhysicsMaterial(
        density: 1.0,
        friction: 0.5,
        restitution: 0.0,
      ),
      position: const Vector3(1, 2, 3),
      rotation: const Quaternion(0, 0, 0, 1),
      scale: const Vector3(1, 1, 1),
      velocity: const Vector3(0, 0, 0),
      angularVelocity: const Vector3(0, 0, 0),
      isActive: true,
      mass: 1.0,
      createdAt: now,
      lastUpdated: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testBody.id, 'body1');
      expect(testBody.nodeId, 'node1');
      expect(testBody.type, PhysicsBodyType.dynamic);
      expect(testBody.position, const Vector3(1, 2, 3));
      expect(testBody.rotation, const Quaternion(0, 0, 0, 1));
      expect(testBody.scale, const Vector3(1, 1, 1));
      expect(testBody.velocity, const Vector3(0, 0, 0));
      expect(testBody.angularVelocity, const Vector3(0, 0, 0));
      expect(testBody.isActive, true);
      expect(testBody.mass, 1.0);
      expect(testBody.createdAt, now);
      expect(testBody.lastUpdated, now);
      expect(testBody.metadata, {'key': 'value'});
    });

    test('computed properties work correctly', () {
      expect(testBody.isStatic, false);
      expect(testBody.isDynamic, true);
      expect(testBody.isKinematic, false);

      final staticBody = ARPhysicsBody(
        id: 'body2',
        nodeId: 'node2',
        type: PhysicsBodyType.static,
        material: const PhysicsMaterial(),
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        velocity: const Vector3(0, 0, 0),
        angularVelocity: const Vector3(0, 0, 0),
        isActive: true,
        mass: 0.0,
        createdAt: now,
        lastUpdated: now,
      );
      expect(staticBody.isStatic, true);
      expect(staticBody.isDynamic, false);
      expect(staticBody.isKinematic, false);
    });

    test('converts to and from map', () {
      final map = testBody.toMap();
      final fromMap = ARPhysicsBody.fromMap(map);
      expect(fromMap, testBody);
    });

    test('parses body types correctly', () {
      final map = testBody.toMap();
      map['type'] = 'unknown';
      final fromMap = ARPhysicsBody.fromMap(map);
      expect(fromMap.type, PhysicsBodyType.static);
    });

    test('equality works correctly', () {
      final anotherBody = ARPhysicsBody(
        id: 'body1',
        nodeId: 'node1',
        type: PhysicsBodyType.dynamic,
        material: const PhysicsMaterial(
          density: 1.0,
          friction: 0.5,
          restitution: 0.0,
        ),
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        velocity: const Vector3(0, 0, 0),
        angularVelocity: const Vector3(0, 0, 0),
        isActive: true,
        mass: 1.0,
        createdAt: now,
        lastUpdated: now,
        metadata: {'key': 'value'},
      );
      expect(testBody, anotherBody);
      expect(testBody == anotherBody, true);

      final differentBody = ARPhysicsBody(
        id: 'body_diff',
        nodeId: 'node1',
        type: PhysicsBodyType.dynamic,
        material: const PhysicsMaterial(
          density: 1.0,
          friction: 0.5,
          restitution: 0.0,
        ),
        position: const Vector3(1, 2, 3),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
        velocity: const Vector3(0, 0, 0),
        angularVelocity: const Vector3(0, 0, 0),
        isActive: true,
        mass: 1.0,
        createdAt: now,
        lastUpdated: now,
        metadata: {'key': 'value'},
      );
      expect(testBody == differentBody, false);
    });

    test('toString works correctly', () {
      expect(testBody.toString(), contains('ARPhysicsBody(id: body1'));
    });
  });

  group('PhysicsConstraintType', () {
    test('has correct enum values', () {
      expect(PhysicsConstraintType.values, [
        PhysicsConstraintType.fixed,
        PhysicsConstraintType.hinge,
        PhysicsConstraintType.ballSocket,
        PhysicsConstraintType.slider,
        PhysicsConstraintType.universal,
      ]);
    });

    test('enum names are correct', () {
      expect(PhysicsConstraintType.fixed.name, 'fixed');
      expect(PhysicsConstraintType.hinge.name, 'hinge');
      expect(PhysicsConstraintType.ballSocket.name, 'ballSocket');
      expect(PhysicsConstraintType.slider.name, 'slider');
      expect(PhysicsConstraintType.universal.name, 'universal');
    });
  });

  group('PhysicsConstraint', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch);
    final testConstraint = PhysicsConstraint(
      id: 'constraint1',
      bodyAId: 'bodyA',
      bodyBId: 'bodyB',
      type: PhysicsConstraintType.hinge,
      anchorA: const Vector3(0, 0, 0),
      anchorB: const Vector3(1, 0, 0),
      axisA: const Vector3(0, 1, 0),
      axisB: const Vector3(0, 1, 0),
      lowerLimit: -1.0,
      upperLimit: 1.0,
      isActive: true,
      createdAt: now,
      lastUpdated: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testConstraint.id, 'constraint1');
      expect(testConstraint.bodyAId, 'bodyA');
      expect(testConstraint.bodyBId, 'bodyB');
      expect(testConstraint.type, PhysicsConstraintType.hinge);
      expect(testConstraint.anchorA, const Vector3(0, 0, 0));
      expect(testConstraint.anchorB, const Vector3(1, 0, 0));
      expect(testConstraint.axisA, const Vector3(0, 1, 0));
      expect(testConstraint.axisB, const Vector3(0, 1, 0));
      expect(testConstraint.lowerLimit, -1.0);
      expect(testConstraint.upperLimit, 1.0);
      expect(testConstraint.isActive, true);
      expect(testConstraint.createdAt, now);
      expect(testConstraint.lastUpdated, now);
      expect(testConstraint.metadata, {'key': 'value'});
    });

    test('converts to and from map', () {
      final map = testConstraint.toMap();
      final fromMap = PhysicsConstraint.fromMap(map);
      expect(fromMap, testConstraint);
    });

    test('parses constraint types correctly', () {
      final map = testConstraint.toMap();
      map['type'] = 'unknown';
      final fromMap = PhysicsConstraint.fromMap(map);
      expect(fromMap.type, PhysicsConstraintType.fixed);
    });

    test('equality works correctly', () {
      final anotherConstraint = PhysicsConstraint(
        id: 'constraint1',
        bodyAId: 'bodyA',
        bodyBId: 'bodyB',
        type: PhysicsConstraintType.hinge,
        anchorA: const Vector3(0, 0, 0),
        anchorB: const Vector3(1, 0, 0),
        axisA: const Vector3(0, 1, 0),
        axisB: const Vector3(0, 1, 0),
        lowerLimit: -1.0,
        upperLimit: 1.0,
        isActive: true,
        createdAt: now,
        lastUpdated: now,
        metadata: {'key': 'value'},
      );
      expect(testConstraint, anotherConstraint);
      expect(testConstraint == anotherConstraint, true);

      final differentConstraint = PhysicsConstraint(
        id: 'constraint_diff',
        bodyAId: 'bodyA',
        bodyBId: 'bodyB',
        type: PhysicsConstraintType.hinge,
        anchorA: const Vector3(0, 0, 0),
        anchorB: const Vector3(1, 0, 0),
        axisA: const Vector3(0, 1, 0),
        axisB: const Vector3(0, 1, 0),
        lowerLimit: -1.0,
        upperLimit: 1.0,
        isActive: true,
        createdAt: now,
        lastUpdated: now,
        metadata: {'key': 'value'},
      );
      expect(testConstraint == differentConstraint, false);
    });

    test('toString works correctly', () {
      expect(testConstraint.toString(), contains('PhysicsConstraint(id: constraint1'));
    });
  });

  group('PhysicsWorldConfig', () {
    const testConfig = PhysicsWorldConfig(
      gravity: Vector3(0, -9.81, 0),
      timeStep: 1.0 / 60.0,
      maxSubSteps: 10,
      enableSleeping: true,
      enableContinuousCollision: true,
      contactBreakingThreshold: 0.0,
      contactERP: 0.2,
      contactCFM: 0.0,
    );

    test('creates with correct properties', () {
      expect(testConfig.gravity, const Vector3(0, -9.81, 0));
      expect(testConfig.timeStep, 1.0 / 60.0);
      expect(testConfig.maxSubSteps, 10);
      expect(testConfig.enableSleeping, true);
      expect(testConfig.enableContinuousCollision, true);
      expect(testConfig.contactBreakingThreshold, 0.0);
      expect(testConfig.contactERP, 0.2);
      expect(testConfig.contactCFM, 0.0);
    });

    test('creates with default values', () {
      const defaultConfig = PhysicsWorldConfig();
      expect(defaultConfig.gravity, const Vector3(0, -9.81, 0));
      expect(defaultConfig.timeStep, 1.0 / 60.0);
      expect(defaultConfig.maxSubSteps, 10);
      expect(defaultConfig.enableSleeping, true);
      expect(defaultConfig.enableContinuousCollision, true);
      expect(defaultConfig.contactBreakingThreshold, 0.0);
      expect(defaultConfig.contactERP, 0.2);
      expect(defaultConfig.contactCFM, 0.0);
    });

    test('converts to and from map', () {
      final map = testConfig.toMap();
      final fromMap = PhysicsWorldConfig.fromMap(map);
      expect(fromMap, testConfig);
    });

    test('equality works correctly', () {
      const anotherConfig = PhysicsWorldConfig(
        gravity: Vector3(0, -9.81, 0),
        timeStep: 1.0 / 60.0,
        maxSubSteps: 10,
        enableSleeping: true,
        enableContinuousCollision: true,
        contactBreakingThreshold: 0.0,
        contactERP: 0.2,
        contactCFM: 0.0,
      );
      expect(testConfig, anotherConfig);
      expect(testConfig == anotherConfig, true);

      const differentConfig = PhysicsWorldConfig(
        gravity: Vector3(0, -9.81, 0),
        timeStep: 1.0 / 60.0,
        maxSubSteps: 5,
        enableSleeping: true,
        enableContinuousCollision: true,
        contactBreakingThreshold: 0.0,
        contactERP: 0.2,
        contactCFM: 0.0,
      );
      expect(testConfig == differentConfig, false);
    });

    test('toString works correctly', () {
      expect(testConfig.toString(), contains('PhysicsWorldConfig(gravity:'));
    });
  });

  group('PhysicsStatus', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch);
    final testStatus = PhysicsStatus(
      status: 'simulating',
      progress: 0.5,
      timestamp: now,
      metadata: {'key': 'value'},
    );

    test('creates with correct properties', () {
      expect(testStatus.status, 'simulating');
      expect(testStatus.progress, 0.5);
      expect(testStatus.errorMessage, isNull);
      expect(testStatus.timestamp, now);
      expect(testStatus.metadata, {'key': 'value'});
    });

    test('computed properties work correctly', () {
      expect(testStatus.isComplete, false);
      expect(testStatus.isSuccessful, false);
      expect(testStatus.isFailed, false);

      final completeStatus = PhysicsStatus(
        status: 'completed',
        progress: 1.0,
        timestamp: now,
      );
      expect(completeStatus.isComplete, true);
      expect(completeStatus.isSuccessful, true);
      expect(completeStatus.isFailed, false);

      final failedStatus = PhysicsStatus(
        status: 'failed',
        progress: 0.8,
        errorMessage: 'Simulation failed',
        timestamp: now,
      );
      expect(failedStatus.isComplete, false);
      expect(failedStatus.isSuccessful, false);
      expect(failedStatus.isFailed, true);
    });

    test('converts to and from map', () {
      final map = testStatus.toMap();
      final fromMap = PhysicsStatus.fromMap(map);
      expect(fromMap, testStatus);
    });

    test('equality works correctly', () {
      final anotherStatus = PhysicsStatus(
        status: 'simulating',
        progress: 0.5,
        timestamp: now,
        metadata: {'key': 'value'},
      );
      expect(testStatus, anotherStatus);
      expect(testStatus == anotherStatus, true);

      final differentStatus = PhysicsStatus(
        status: 'different',
        progress: 0.5,
        timestamp: now,
        metadata: {'key': 'value'},
      );
      expect(testStatus == differentStatus, false);
    });

    test('toString works correctly', () {
      expect(testStatus.toString(), contains('PhysicsStatus(status: simulating'));
    });
  });
}
