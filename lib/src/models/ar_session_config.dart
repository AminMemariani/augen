/// Configuration for AR session
class ARSessionConfig {
  final bool planeDetection;
  final bool lightEstimation;
  final bool depthData;
  final bool autoFocus;

  const ARSessionConfig({
    this.planeDetection = true,
    this.lightEstimation = true,
    this.depthData = false,
    this.autoFocus = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'planeDetection': planeDetection,
      'lightEstimation': lightEstimation,
      'depthData': depthData,
      'autoFocus': autoFocus,
    };
  }

  factory ARSessionConfig.fromMap(Map<dynamic, dynamic> map) {
    return ARSessionConfig(
      planeDetection: map['planeDetection'] as bool? ?? true,
      lightEstimation: map['lightEstimation'] as bool? ?? true,
      depthData: map['depthData'] as bool? ?? false,
      autoFocus: map['autoFocus'] as bool? ?? true,
    );
  }

  ARSessionConfig copyWith({
    bool? planeDetection,
    bool? lightEstimation,
    bool? depthData,
    bool? autoFocus,
  }) {
    return ARSessionConfig(
      planeDetection: planeDetection ?? this.planeDetection,
      lightEstimation: lightEstimation ?? this.lightEstimation,
      depthData: depthData ?? this.depthData,
      autoFocus: autoFocus ?? this.autoFocus,
    );
  }
}
