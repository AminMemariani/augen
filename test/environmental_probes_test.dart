import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Environmental Probes Tests', () {
    group('ARProbeType', () {
      test('has correct enum values', () {
        expect(ARProbeType.values.length, 3);
        expect(ARProbeType.values, contains(ARProbeType.spherical));
        expect(ARProbeType.values, contains(ARProbeType.box));
        expect(ARProbeType.values, contains(ARProbeType.planar));
      });

      test('enum names are correct', () {
        expect(ARProbeType.spherical.name, 'spherical');
        expect(ARProbeType.box.name, 'box');
        expect(ARProbeType.planar.name, 'planar');
      });
    });

    group('ARProbeUpdateMode', () {
      test('has correct enum values', () {
        expect(ARProbeUpdateMode.values.length, 3);
        expect(ARProbeUpdateMode.values, contains(ARProbeUpdateMode.automatic));
        expect(ARProbeUpdateMode.values, contains(ARProbeUpdateMode.manual));
        expect(
          ARProbeUpdateMode.values,
          contains(ARProbeUpdateMode.onMovement),
        );
      });

      test('enum names are correct', () {
        expect(ARProbeUpdateMode.automatic.name, 'automatic');
        expect(ARProbeUpdateMode.manual.name, 'manual');
        expect(ARProbeUpdateMode.onMovement.name, 'onMovement');
      });
    });

    group('ARProbeQuality', () {
      test('has correct enum values', () {
        expect(ARProbeQuality.values.length, 4);
        expect(ARProbeQuality.values, contains(ARProbeQuality.low));
        expect(ARProbeQuality.values, contains(ARProbeQuality.medium));
        expect(ARProbeQuality.values, contains(ARProbeQuality.high));
        expect(ARProbeQuality.values, contains(ARProbeQuality.ultra));
      });

      test('enum names are correct', () {
        expect(ARProbeQuality.low.name, 'low');
        expect(ARProbeQuality.medium.name, 'medium');
        expect(ARProbeQuality.high.name, 'high');
        expect(ARProbeQuality.ultra.name, 'ultra');
      });
    });

    group('AREnvironmentalProbe', () {
      test('creates with correct properties', () {
        final now = DateTime.now();
        final probe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        expect(probe.id, 'test_probe');
        expect(probe.type, ARProbeType.spherical);
        expect(probe.position, const Vector3(1, 2, 3));
        expect(probe.rotation, const Quaternion(0, 0, 0, 1));
        expect(probe.scale, const Vector3(1, 1, 1));
        expect(probe.influenceRadius, 5.0);
        expect(probe.updateMode, ARProbeUpdateMode.automatic);
        expect(probe.quality, ARProbeQuality.medium);
        expect(probe.isActive, true);
        expect(probe.captureReflections, true);
        expect(probe.captureLighting, true);
        expect(probe.textureResolution, 512);
        expect(probe.isRealTime, true);
        expect(probe.updateFrequency, 1.0);
        expect(probe.confidence, 0.8);
        expect(probe.createdAt, now);
        expect(probe.lastModified, now);
      });

      test('computed properties work correctly', () {
        final now = DateTime.now();
        final probe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.high,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        expect(probe.isReliable, true);
        expect(probe.isHighQuality, true);
        expect(probe.needsUpdate, false);
      });

      test('converts to and from map', () {
        final now = DateTime.now();
        final originalProbe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
          metadata: {'test': 'value'},
        );

        final map = originalProbe.toMap();
        final restoredProbe = AREnvironmentalProbe.fromMap(map);

        expect(restoredProbe.id, originalProbe.id);
        expect(restoredProbe.type, originalProbe.type);
        expect(restoredProbe.position, originalProbe.position);
        expect(restoredProbe.rotation, originalProbe.rotation);
        expect(restoredProbe.scale, originalProbe.scale);
        expect(restoredProbe.influenceRadius, originalProbe.influenceRadius);
        expect(restoredProbe.updateMode, originalProbe.updateMode);
        expect(restoredProbe.quality, originalProbe.quality);
        expect(restoredProbe.isActive, originalProbe.isActive);
        expect(
          restoredProbe.captureReflections,
          originalProbe.captureReflections,
        );
        expect(restoredProbe.captureLighting, originalProbe.captureLighting);
        expect(
          restoredProbe.textureResolution,
          originalProbe.textureResolution,
        );
        expect(restoredProbe.isRealTime, originalProbe.isRealTime);
        expect(restoredProbe.updateFrequency, originalProbe.updateFrequency);
        expect(restoredProbe.confidence, originalProbe.confidence);
        expect(
          restoredProbe.createdAt.millisecondsSinceEpoch,
          originalProbe.createdAt.millisecondsSinceEpoch,
        );
        expect(
          restoredProbe.lastModified.millisecondsSinceEpoch,
          originalProbe.lastModified.millisecondsSinceEpoch,
        );
        expect(restoredProbe.metadata, originalProbe.metadata);
      });

      test('parses probe types correctly', () {
        final sphericalMap = {'type': 'spherical'};
        final boxMap = {'type': 'box'};
        final planarMap = {'type': 'planar'};

        expect(
          ARProbeType.values.firstWhere((e) => e.name == sphericalMap['type']),
          ARProbeType.spherical,
        );
        expect(
          ARProbeType.values.firstWhere((e) => e.name == boxMap['type']),
          ARProbeType.box,
        );
        expect(
          ARProbeType.values.firstWhere((e) => e.name == planarMap['type']),
          ARProbeType.planar,
        );
      });

      test('equality works correctly', () {
        final now = DateTime.now();
        final probe1 = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        final probe2 = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        expect(probe1, equals(probe2));
        expect(probe1.hashCode, equals(probe2.hashCode));
      });

      test('toString works correctly', () {
        final now = DateTime.now();
        final probe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        final str = probe.toString();
        expect(str, contains('test_probe'));
        expect(str, contains('spherical'));
        expect(str, contains('5.0'));
        expect(str, contains('medium'));
        expect(str, contains('true'));
      });

      test('copyWith creates modified copy', () {
        final now = DateTime.now();
        final originalProbe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        final modifiedProbe = originalProbe.copyWith(
          quality: ARProbeQuality.high,
          isActive: false,
          confidence: 0.9,
        );

        expect(modifiedProbe.quality, ARProbeQuality.high);
        expect(modifiedProbe.isActive, false);
        expect(modifiedProbe.confidence, 0.9);
        expect(modifiedProbe.id, originalProbe.id);
        expect(modifiedProbe.type, originalProbe.type);
        expect(modifiedProbe.position, originalProbe.position);
      });
    });

    group('AREnvironmentalProbeConfig', () {
      test('creates with correct properties', () {
        final config = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
          metadata: {'test': 'value'},
        );

        expect(config.enableProbes, true);
        expect(config.defaultQuality, ARProbeQuality.medium);
        expect(config.defaultUpdateMode, ARProbeUpdateMode.automatic);
        expect(config.defaultTextureResolution, 512);
        expect(config.maxActiveProbes, 4);
        expect(config.defaultInfluenceRadius, 5.0);
        expect(config.defaultRealTime, true);
        expect(config.defaultUpdateFrequency, 1.0);
        expect(config.autoCreateProbes, true);
        expect(config.optimizePlacement, true);
        expect(config.metadata, {'test': 'value'});
      });

      test('converts to and from map', () {
        final originalConfig = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
          metadata: {'test': 'value'},
        );

        final map = originalConfig.toMap();
        final restoredConfig = AREnvironmentalProbeConfig.fromMap(map);

        expect(restoredConfig.enableProbes, originalConfig.enableProbes);
        expect(restoredConfig.defaultQuality, originalConfig.defaultQuality);
        expect(
          restoredConfig.defaultUpdateMode,
          originalConfig.defaultUpdateMode,
        );
        expect(
          restoredConfig.defaultTextureResolution,
          originalConfig.defaultTextureResolution,
        );
        expect(restoredConfig.maxActiveProbes, originalConfig.maxActiveProbes);
        expect(
          restoredConfig.defaultInfluenceRadius,
          originalConfig.defaultInfluenceRadius,
        );
        expect(restoredConfig.defaultRealTime, originalConfig.defaultRealTime);
        expect(
          restoredConfig.defaultUpdateFrequency,
          originalConfig.defaultUpdateFrequency,
        );
        expect(
          restoredConfig.autoCreateProbes,
          originalConfig.autoCreateProbes,
        );
        expect(
          restoredConfig.optimizePlacement,
          originalConfig.optimizePlacement,
        );
        expect(restoredConfig.metadata, originalConfig.metadata);
      });

      test('equality works correctly', () {
        final config1 = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
        );

        final config2 = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('toString works correctly', () {
        final config = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
        );

        final str = config.toString();
        expect(str, contains('true'));
        expect(str, contains('medium'));
        expect(str, contains('4'));
      });

      test('copyWith creates modified copy', () {
        final originalConfig = AREnvironmentalProbeConfig(
          enableProbes: true,
          defaultQuality: ARProbeQuality.medium,
          defaultUpdateMode: ARProbeUpdateMode.automatic,
          defaultTextureResolution: 512,
          maxActiveProbes: 4,
          defaultInfluenceRadius: 5.0,
          defaultRealTime: true,
          defaultUpdateFrequency: 1.0,
          autoCreateProbes: true,
          optimizePlacement: true,
        );

        final modifiedConfig = originalConfig.copyWith(
          defaultQuality: ARProbeQuality.high,
          maxActiveProbes: 8,
        );

        expect(modifiedConfig.defaultQuality, ARProbeQuality.high);
        expect(modifiedConfig.maxActiveProbes, 8);
        expect(modifiedConfig.enableProbes, originalConfig.enableProbes);
        expect(
          modifiedConfig.defaultUpdateMode,
          originalConfig.defaultUpdateMode,
        );
      });
    });

    group('AREnvironmentalProbeStatus', () {
      test('creates with correct properties', () {
        final now = DateTime.now();
        final status = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: null,
          timestamp: now,
          metadata: {'test': 'value'},
        );

        expect(status.status, 'in_progress');
        expect(status.progress, 0.5);
        expect(status.errorMessage, null);
        expect(status.timestamp, now);
        expect(status.metadata, {'test': 'value'});
      });

      test('computed properties work correctly', () {
        final now = DateTime.now();
        final inProgressStatus = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          timestamp: now,
        );

        final completedStatus = AREnvironmentalProbeStatus(
          status: 'completed',
          progress: 1.0,
          timestamp: now,
        );

        final failedStatus = AREnvironmentalProbeStatus(
          status: 'failed',
          progress: 0.0,
          errorMessage: 'Test error',
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
        final originalStatus = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: 'Test error',
          timestamp: now,
          metadata: {'test': 'value'},
        );

        final map = originalStatus.toMap();
        final restoredStatus = AREnvironmentalProbeStatus.fromMap(map);

        expect(restoredStatus.status, originalStatus.status);
        expect(restoredStatus.progress, originalStatus.progress);
        expect(restoredStatus.errorMessage, originalStatus.errorMessage);
        expect(
          restoredStatus.timestamp.millisecondsSinceEpoch,
          originalStatus.timestamp.millisecondsSinceEpoch,
        );
        expect(restoredStatus.metadata, originalStatus.metadata);
      });

      test('equality works correctly', () {
        final now = DateTime.now();
        final status1 = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: 'Test error',
          timestamp: now,
        );

        final status2 = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: 'Test error',
          timestamp: now,
        );

        expect(status1, equals(status2));
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('toString works correctly', () {
        final now = DateTime.now();
        final status = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: 'Test error',
          timestamp: now,
        );

        final str = status.toString();
        expect(str, contains('in_progress'));
        expect(str, contains('0.5'));
        expect(str, contains('Test error'));
      });

      test('copyWith creates modified copy', () {
        final now = DateTime.now();
        final originalStatus = AREnvironmentalProbeStatus(
          status: 'in_progress',
          progress: 0.5,
          errorMessage: 'Test error',
          timestamp: now,
        );

        final modifiedStatus = originalStatus.copyWith(
          status: 'completed',
          progress: 1.0,
          errorMessage: null,
        );

        expect(modifiedStatus.status, 'completed');
        expect(modifiedStatus.progress, 1.0);
        expect(modifiedStatus.errorMessage, null);
        expect(modifiedStatus.timestamp, originalStatus.timestamp);
      });
    });
  });
}
