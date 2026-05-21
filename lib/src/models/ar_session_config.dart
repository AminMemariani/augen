import 'ar_marker_config.dart';

/// Configuration for AR session
class ARSessionConfig {
  final bool planeDetection;
  final bool lightEstimation;
  final bool depthData;
  final bool autoFocus;
  final bool markerTracking;
  final ARMarkerDetectionOptions? markerDetectionOptions;

  const ARSessionConfig({
    this.planeDetection = true,
    this.lightEstimation = true,
    this.depthData = false,
    this.autoFocus = true,
    this.markerTracking = false,
    this.markerDetectionOptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'planeDetection': planeDetection,
      'lightEstimation': lightEstimation,
      'depthData': depthData,
      'autoFocus': autoFocus,
      'markerTracking': markerTracking,
      if (markerDetectionOptions != null)
        'markerDetectionOptions': markerDetectionOptions!.toMap(),
    };
  }

  factory ARSessionConfig.fromMap(Map<dynamic, dynamic> map) {
    return ARSessionConfig(
      planeDetection: map['planeDetection'] as bool? ?? true,
      lightEstimation: map['lightEstimation'] as bool? ?? true,
      depthData: map['depthData'] as bool? ?? false,
      autoFocus: map['autoFocus'] as bool? ?? true,
      markerTracking: map['markerTracking'] as bool? ?? false,
      markerDetectionOptions: map['markerDetectionOptions'] != null
          ? ARMarkerDetectionOptions.fromMap(
              map['markerDetectionOptions'] as Map)
          : null,
    );
  }

  ARSessionConfig copyWith({
    bool? planeDetection,
    bool? lightEstimation,
    bool? depthData,
    bool? autoFocus,
    bool? markerTracking,
    ARMarkerDetectionOptions? markerDetectionOptions,
  }) {
    return ARSessionConfig(
      planeDetection: planeDetection ?? this.planeDetection,
      lightEstimation: lightEstimation ?? this.lightEstimation,
      depthData: depthData ?? this.depthData,
      autoFocus: autoFocus ?? this.autoFocus,
      markerTracking: markerTracking ?? this.markerTracking,
      markerDetectionOptions:
          markerDetectionOptions ?? this.markerDetectionOptions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARSessionConfig &&
          planeDetection == other.planeDetection &&
          lightEstimation == other.lightEstimation &&
          depthData == other.depthData &&
          autoFocus == other.autoFocus &&
          markerTracking == other.markerTracking &&
          markerDetectionOptions == other.markerDetectionOptions;

  @override
  int get hashCode => Object.hash(
        planeDetection,
        lightEstimation,
        depthData,
        autoFocus,
        markerTracking,
        markerDetectionOptions,
      );
}
