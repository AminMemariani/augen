import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Lighting Tests', () {
    group('ARLightType', () {
      test('has correct enum values', () {
        expect(ARLightType.values.length, 5);
        expect(ARLightType.values, contains(ARLightType.directional));
        expect(ARLightType.values, contains(ARLightType.point));
        expect(ARLightType.values, contains(ARLightType.spot));
        expect(ARLightType.values, contains(ARLightType.ambient));
        expect(ARLightType.values, contains(ARLightType.environment));
      });

      test('enum names are correct', () {
        expect(ARLightType.directional.name, 'directional');
        expect(ARLightType.point.name, 'point');
        expect(ARLightType.spot.name, 'spot');
        expect(ARLightType.ambient.name, 'ambient');
        expect(ARLightType.environment.name, 'environment');
      });
    });

    group('ShadowQuality', () {
      test('has correct enum values', () {
        expect(ShadowQuality.values.length, 4);
        expect(ShadowQuality.values, contains(ShadowQuality.low));
        expect(ShadowQuality.values, contains(ShadowQuality.medium));
        expect(ShadowQuality.values, contains(ShadowQuality.high));
        expect(ShadowQuality.values, contains(ShadowQuality.ultra));
      });

      test('enum names are correct', () {
        expect(ShadowQuality.low.name, 'low');
        expect(ShadowQuality.medium.name, 'medium');
        expect(ShadowQuality.high.name, 'high');
        expect(ShadowQuality.ultra.name, 'ultra');
      });
    });

    group('ShadowFilterMode', () {
      test('has correct enum values', () {
        expect(ShadowFilterMode.values.length, 4);
        expect(ShadowFilterMode.values, contains(ShadowFilterMode.hard));
        expect(ShadowFilterMode.values, contains(ShadowFilterMode.soft));
        expect(ShadowFilterMode.values, contains(ShadowFilterMode.pcf));
        expect(ShadowFilterMode.values, contains(ShadowFilterMode.pcss));
      });

      test('enum names are correct', () {
        expect(ShadowFilterMode.hard.name, 'hard');
        expect(ShadowFilterMode.soft.name, 'soft');
        expect(ShadowFilterMode.pcf.name, 'pcf');
        expect(ShadowFilterMode.pcss.name, 'pcss');
      });
    });

    group('LightIntensityUnit', () {
      test('has correct enum values', () {
        expect(LightIntensityUnit.values.length, 4);
        expect(LightIntensityUnit.values, contains(LightIntensityUnit.lux));
        expect(LightIntensityUnit.values, contains(LightIntensityUnit.candela));
        expect(LightIntensityUnit.values, contains(LightIntensityUnit.lumen));
        expect(LightIntensityUnit.values, contains(LightIntensityUnit.watt));
      });

      test('enum names are correct', () {
        expect(LightIntensityUnit.lux.name, 'lux');
        expect(LightIntensityUnit.candela.name, 'candela');
        expect(LightIntensityUnit.lumen.name, 'lumen');
        expect(LightIntensityUnit.watt.name, 'watt');
      });
    });

    group('ARLight', () {
      test('creates with correct properties', () {
        final now = DateTime.now();
        final light = ARLight(
          id: 'light_1',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        expect(light.id, 'light_1');
        expect(light.type, ARLightType.directional);
        expect(light.position, const Vector3(0, 5, 0));
        expect(light.rotation, const Quaternion(0, 0, 0, 1));
        expect(light.direction, const Vector3(0, -1, 0));
        expect(light.intensity, 1000.0);
        expect(light.intensityUnit, LightIntensityUnit.lux);
        expect(light.color, const Vector3(1.0, 1.0, 1.0));
        expect(light.range, 10.0);
        expect(light.innerConeAngle, 0.0);
        expect(light.outerConeAngle, 45.0);
        expect(light.isEnabled, true);
        expect(light.castShadows, true);
        expect(light.shadowQuality, ShadowQuality.medium);
        expect(light.shadowFilterMode, ShadowFilterMode.soft);
        expect(light.shadowBias, 0.005);
        expect(light.shadowNormalBias, 0.0);
        expect(light.shadowNearPlane, 0.1);
        expect(light.shadowFarPlane, 100.0);
        expect(light.createdAt, now);
        expect(light.lastModified, now);
        expect(light.metadata, {});
      });

      test('computed properties work correctly', () {
        final now = DateTime.now();
        final directionalLight = ARLight(
          id: 'directional',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        final pointLight = ARLight(
          id: 'point',
          type: ARLightType.point,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          range: 20.0,
          createdAt: now,
          lastModified: now,
        );

        expect(directionalLight.isDirectional, true);
        expect(directionalLight.isPoint, false);
        expect(directionalLight.isSpot, false);
        expect(directionalLight.isAmbient, false);
        expect(directionalLight.isEnvironment, false);
        expect(directionalLight.effectiveRange, double.infinity);

        expect(pointLight.isDirectional, false);
        expect(pointLight.isPoint, true);
        expect(pointLight.effectiveRange, 20.0);
      });

      test('shadow map resolution works correctly', () {
        final now = DateTime.now();
        final light = ARLight(
          id: 'test',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          shadowQuality: ShadowQuality.high,
          createdAt: now,
          lastModified: now,
        );

        expect(light.shadowMapResolution, 2048);
      });

      test('converts to and from map', () {
        final now = DateTime.now();
        final originalLight = ARLight(
          id: 'light_1',
          type: ARLightType.spot,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0.1, 0.2, 0.3, 0.9),
          direction: const Vector3(0, -1, 0),
          intensity: 500.0,
          intensityUnit: LightIntensityUnit.candela,
          color: const Vector3(1.0, 0.5, 0.2),
          range: 15.0,
          innerConeAngle: 10.0,
          outerConeAngle: 30.0,
          isEnabled: false,
          castShadows: false,
          shadowQuality: ShadowQuality.ultra,
          shadowFilterMode: ShadowFilterMode.pcss,
          shadowBias: 0.01,
          shadowNormalBias: 0.005,
          shadowNearPlane: 0.5,
          shadowFarPlane: 200.0,
          createdAt: now,
          lastModified: now,
          metadata: {'custom': 'value'},
        );

        final map = originalLight.toMap();
        final restoredLight = ARLight.fromMap(map);

        expect(restoredLight.id, originalLight.id);
        expect(restoredLight.type, originalLight.type);
        expect(restoredLight.position, originalLight.position);
        expect(restoredLight.rotation, originalLight.rotation);
        expect(restoredLight.direction, originalLight.direction);
        expect(restoredLight.intensity, originalLight.intensity);
        expect(restoredLight.intensityUnit, originalLight.intensityUnit);
        expect(restoredLight.color, originalLight.color);
        expect(restoredLight.range, originalLight.range);
        expect(restoredLight.innerConeAngle, originalLight.innerConeAngle);
        expect(restoredLight.outerConeAngle, originalLight.outerConeAngle);
        expect(restoredLight.isEnabled, originalLight.isEnabled);
        expect(restoredLight.castShadows, originalLight.castShadows);
        expect(restoredLight.shadowQuality, originalLight.shadowQuality);
        expect(restoredLight.shadowFilterMode, originalLight.shadowFilterMode);
        expect(restoredLight.shadowBias, originalLight.shadowBias);
        expect(restoredLight.shadowNormalBias, originalLight.shadowNormalBias);
        expect(restoredLight.shadowNearPlane, originalLight.shadowNearPlane);
        expect(restoredLight.shadowFarPlane, originalLight.shadowFarPlane);
        expect(restoredLight.createdAt.millisecondsSinceEpoch, originalLight.createdAt.millisecondsSinceEpoch);
        expect(restoredLight.lastModified.millisecondsSinceEpoch, originalLight.lastModified.millisecondsSinceEpoch);
        expect(restoredLight.metadata, originalLight.metadata);
      });

      test('parses light types correctly', () {
        final now = DateTime.now();
        final map = {
          'id': 'test',
          'type': 'point',
          'position': {'x': 0, 'y': 0, 'z': 0},
          'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
          'direction': {'x': 0, 'y': -1, 'z': 0},
          'intensity': 100.0,
          'intensityUnit': 'lux',
          'color': {'x': 1, 'y': 1, 'z': 1},
          'range': 10.0,
          'innerConeAngle': 0.0,
          'outerConeAngle': 45.0,
          'isEnabled': true,
          'castShadows': true,
          'shadowQuality': 'medium',
          'shadowFilterMode': 'soft',
          'shadowBias': 0.005,
          'shadowNormalBias': 0.0,
          'shadowNearPlane': 0.1,
          'shadowFarPlane': 100.0,
          'createdAt': now.millisecondsSinceEpoch,
          'lastModified': now.millisecondsSinceEpoch,
          'metadata': {},
        };

        final light = ARLight.fromMap(map);
        expect(light.type, ARLightType.point);
      });

      test('equality works correctly', () {
        final now = DateTime.now();
        final light1 = ARLight(
          id: 'light_1',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        final light2 = ARLight(
          id: 'light_1',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        final light3 = ARLight(
          id: 'light_2',
          type: ARLightType.point,
          position: const Vector3(1, 1, 1),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 500.0,
          createdAt: now,
          lastModified: now,
        );

        expect(light1, equals(light2));
        expect(light1, isNot(equals(light3)));
        expect(light1.hashCode, equals(light2.hashCode));
        expect(light1.hashCode, isNot(equals(light3.hashCode)));
      });

      test('toString works correctly', () {
        final now = DateTime.now();
        final light = ARLight(
          id: 'test_light',
          type: ARLightType.spot,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 750.0,
          createdAt: now,
          lastModified: now,
        );

        final str = light.toString();
        expect(str, contains('test_light'));
        expect(str, contains('spot'));
        expect(str, contains('750.0'));
        expect(str, contains('true'));
      });

      test('copyWith creates modified copy', () {
        final now = DateTime.now();
        final originalLight = ARLight(
          id: 'light_1',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        final modifiedLight = originalLight.copyWith(
          intensity: 2000.0,
          color: const Vector3(1.0, 0.0, 0.0),
          isEnabled: false,
        );

        expect(modifiedLight.id, originalLight.id);
        expect(modifiedLight.type, originalLight.type);
        expect(modifiedLight.position, originalLight.position);
        expect(modifiedLight.intensity, 2000.0);
        expect(modifiedLight.color, const Vector3(1.0, 0.0, 0.0));
        expect(modifiedLight.isEnabled, false);
        expect(modifiedLight.range, originalLight.range);
      });
    });

    group('ARLightingConfig', () {
      test('creates with correct properties', () {
        const config = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.high,
          globalShadowFilterMode: ShadowFilterMode.pcf,
          ambientIntensity: 0.5,
          ambientColor: Vector3(0.8, 0.9, 1.0),
          shadowDistance: 100.0,
          maxShadowCasters: 8,
          enableCascadedShadows: true,
          shadowCascadeCount: 4,
          shadowCascadeDistances: [10.0, 25.0, 50.0, 100.0],
          enableContactShadows: true,
          contactShadowDistance: 10.0,
          enableScreenSpaceShadows: true,
          enableRayTracedShadows: false,
          metadata: {'custom': 'value'},
        );

        expect(config.enableGlobalIllumination, true);
        expect(config.enableShadows, true);
        expect(config.globalShadowQuality, ShadowQuality.high);
        expect(config.globalShadowFilterMode, ShadowFilterMode.pcf);
        expect(config.ambientIntensity, 0.5);
        expect(config.ambientColor, const Vector3(0.8, 0.9, 1.0));
        expect(config.shadowDistance, 100.0);
        expect(config.maxShadowCasters, 8);
        expect(config.enableCascadedShadows, true);
        expect(config.shadowCascadeCount, 4);
        expect(config.shadowCascadeDistances, [10.0, 25.0, 50.0, 100.0]);
        expect(config.enableContactShadows, true);
        expect(config.contactShadowDistance, 10.0);
        expect(config.enableScreenSpaceShadows, true);
        expect(config.enableRayTracedShadows, false);
        expect(config.metadata, {'custom': 'value'});
      });

      test('creates with default values', () {
        const config = ARLightingConfig();

        expect(config.enableGlobalIllumination, true);
        expect(config.enableShadows, true);
        expect(config.globalShadowQuality, ShadowQuality.medium);
        expect(config.globalShadowFilterMode, ShadowFilterMode.soft);
        expect(config.ambientIntensity, 0.3);
        expect(config.ambientColor, const Vector3(1.0, 1.0, 1.0));
        expect(config.shadowDistance, 50.0);
        expect(config.maxShadowCasters, 4);
        expect(config.enableCascadedShadows, true);
        expect(config.shadowCascadeCount, 4);
        expect(config.shadowCascadeDistances, [10.0, 25.0, 50.0, 100.0]);
        expect(config.enableContactShadows, false);
        expect(config.contactShadowDistance, 5.0);
        expect(config.enableScreenSpaceShadows, false);
        expect(config.enableRayTracedShadows, false);
        expect(config.metadata, {});
      });

      test('converts to and from map', () {
        const originalConfig = ARLightingConfig(
          enableGlobalIllumination: false,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.ultra,
          globalShadowFilterMode: ShadowFilterMode.pcss,
          ambientIntensity: 0.7,
          ambientColor: Vector3(0.9, 0.8, 0.7),
          shadowDistance: 150.0,
          maxShadowCasters: 16,
          enableCascadedShadows: false,
          shadowCascadeCount: 2,
          shadowCascadeDistances: [20.0, 80.0],
          enableContactShadows: true,
          contactShadowDistance: 15.0,
          enableScreenSpaceShadows: true,
          enableRayTracedShadows: true,
          metadata: {'advanced': true},
        );

        final map = originalConfig.toMap();
        final restoredConfig = ARLightingConfig.fromMap(map);

        expect(restoredConfig.enableGlobalIllumination, originalConfig.enableGlobalIllumination);
        expect(restoredConfig.enableShadows, originalConfig.enableShadows);
        expect(restoredConfig.globalShadowQuality, originalConfig.globalShadowQuality);
        expect(restoredConfig.globalShadowFilterMode, originalConfig.globalShadowFilterMode);
        expect(restoredConfig.ambientIntensity, originalConfig.ambientIntensity);
        expect(restoredConfig.ambientColor, originalConfig.ambientColor);
        expect(restoredConfig.shadowDistance, originalConfig.shadowDistance);
        expect(restoredConfig.maxShadowCasters, originalConfig.maxShadowCasters);
        expect(restoredConfig.enableCascadedShadows, originalConfig.enableCascadedShadows);
        expect(restoredConfig.shadowCascadeCount, originalConfig.shadowCascadeCount);
        expect(restoredConfig.shadowCascadeDistances, originalConfig.shadowCascadeDistances);
        expect(restoredConfig.enableContactShadows, originalConfig.enableContactShadows);
        expect(restoredConfig.contactShadowDistance, originalConfig.contactShadowDistance);
        expect(restoredConfig.enableScreenSpaceShadows, originalConfig.enableScreenSpaceShadows);
        expect(restoredConfig.enableRayTracedShadows, originalConfig.enableRayTracedShadows);
        expect(restoredConfig.metadata, originalConfig.metadata);
      });

      test('equality works correctly', () {
        const config1 = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.medium,
        );

        const config2 = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.medium,
        );

        const config3 = ARLightingConfig(
          enableGlobalIllumination: false,
          enableShadows: false,
          globalShadowQuality: ShadowQuality.high,
        );

        expect(config1, equals(config2));
        expect(config1, isNot(equals(config3)));
        expect(config1.hashCode, equals(config2.hashCode));
        expect(config1.hashCode, isNot(equals(config3.hashCode)));
      });

      test('toString works correctly', () {
        const config = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.high,
        );

        final str = config.toString();
        expect(str, contains('true'));
        expect(str, contains('high'));
      });

      test('copyWith creates modified copy', () {
        const originalConfig = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.medium,
        );

        final modifiedConfig = originalConfig.copyWith(
          enableGlobalIllumination: false,
          globalShadowQuality: ShadowQuality.ultra,
          ambientIntensity: 0.8,
        );

        expect(modifiedConfig.enableGlobalIllumination, false);
        expect(modifiedConfig.enableShadows, originalConfig.enableShadows);
        expect(modifiedConfig.globalShadowQuality, ShadowQuality.ultra);
        expect(modifiedConfig.ambientIntensity, 0.8);
        expect(modifiedConfig.ambientColor, originalConfig.ambientColor);
      });
    });

    group('ARLightingStatus', () {
      test('creates with correct properties', () {
        final now = DateTime.now();
        final status = ARLightingStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: null,
          timestamp: now,
          metadata: {'operation': 'lighting_update'},
        );

        expect(status.status, 'in_progress');
        expect(status.progress, 0.5);
        expect(status.errorMessage, null);
        expect(status.timestamp, now);
        expect(status.metadata, {'operation': 'lighting_update'});
      });

      test('computed properties work correctly', () {
        final now = DateTime.now();
        final inProgressStatus = ARLightingStatus(
          status: 'in_progress',
          progress: 0.3,
          timestamp: now,
        );

        final completedStatus = ARLightingStatus(
          status: 'completed',
          progress: 1.0,
          timestamp: now,
        );

        final failedStatus = ARLightingStatus(
          status: 'failed',
          progress: 0.0,
          errorMessage: 'Lighting error',
          timestamp: now,
        );

        expect(inProgressStatus.isInProgress, true);
        expect(inProgressStatus.isCompleted, false);
        expect(inProgressStatus.isFailed, false);

        expect(completedStatus.isInProgress, false);
        expect(completedStatus.isCompleted, true);
        expect(completedStatus.isFailed, false);

        expect(failedStatus.isInProgress, false);
        expect(failedStatus.isCompleted, false);
        expect(failedStatus.isFailed, true);
      });

      test('converts to and from map', () {
        final now = DateTime.now();
        final originalStatus = ARLightingStatus(
          status: 'completed',
          progress: 1.0,
          errorMessage: null,
          timestamp: now,
          metadata: {'lights_updated': 5},
        );

        final map = originalStatus.toMap();
        final restoredStatus = ARLightingStatus.fromMap(map);

        expect(restoredStatus.status, originalStatus.status);
        expect(restoredStatus.progress, originalStatus.progress);
        expect(restoredStatus.errorMessage, originalStatus.errorMessage);
        expect(restoredStatus.timestamp.millisecondsSinceEpoch, originalStatus.timestamp.millisecondsSinceEpoch);
        expect(restoredStatus.metadata, originalStatus.metadata);
      });

      test('equality works correctly', () {
        final now = DateTime.now();
        final status1 = ARLightingStatus(
          status: 'completed',
          progress: 1.0,
          timestamp: now,
        );

        final status2 = ARLightingStatus(
          status: 'completed',
          progress: 1.0,
          timestamp: now,
        );

        final status3 = ARLightingStatus(
          status: 'failed',
          progress: 0.0,
          errorMessage: 'Error',
          timestamp: now,
        );

        expect(status1, equals(status2));
        expect(status1, isNot(equals(status3)));
        expect(status1.hashCode, equals(status2.hashCode));
        expect(status1.hashCode, isNot(equals(status3.hashCode)));
      });

      test('toString works correctly', () {
        final now = DateTime.now();
        final status = ARLightingStatus(
          status: 'in_progress',
          progress: 0.7,
          errorMessage: 'Processing',
          timestamp: now,
        );

        final str = status.toString();
        expect(str, contains('in_progress'));
        expect(str, contains('0.7'));
        expect(str, contains('Processing'));
      });
    });
  });
}
