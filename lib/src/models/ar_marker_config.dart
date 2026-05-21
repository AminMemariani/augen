/// Configuration options for AR marker detection
class ARMarkerDetectionOptions {
  final int maxDetectionFps;
  final int processingWidth;
  final int? processingHeight;
  final double confidenceThreshold;
  final bool debug;
  final bool smoothingEnabled;
  final double positionSmoothing;
  final double rotationSmoothing;
  final Duration lostTimeout;
  final bool hideContentWhenLost;

  const ARMarkerDetectionOptions({
    this.maxDetectionFps = 15,
    this.processingWidth = 640,
    this.processingHeight,
    this.confidenceThreshold = 0.6,
    this.debug = false,
    this.smoothingEnabled = true,
    this.positionSmoothing = 0.6,
    this.rotationSmoothing = 0.6,
    this.lostTimeout = const Duration(milliseconds: 500),
    this.hideContentWhenLost = true,
  }) : assert(maxDetectionFps >= 1, 'maxDetectionFps must be at least 1');

  factory ARMarkerDetectionOptions.fromMap(Map<dynamic, dynamic> map) {
    final fps = map['maxDetectionFps'] as int? ?? 15;
    return ARMarkerDetectionOptions(
      maxDetectionFps: fps < 1 ? 1 : fps,
      processingWidth: map['processingWidth'] as int? ?? 640,
      processingHeight: map['processingHeight'] as int?,
      confidenceThreshold:
          (map['confidenceThreshold'] as num?)?.toDouble() ?? 0.6,
      debug: map['debug'] as bool? ?? false,
      smoothingEnabled: map['smoothingEnabled'] as bool? ?? true,
      positionSmoothing:
          (map['positionSmoothing'] as num?)?.toDouble() ?? 0.6,
      rotationSmoothing:
          (map['rotationSmoothing'] as num?)?.toDouble() ?? 0.6,
      lostTimeout: Duration(
        milliseconds: map['lostTimeoutMs'] as int? ?? 500,
      ),
      hideContentWhenLost: map['hideContentWhenLost'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxDetectionFps': maxDetectionFps,
      'processingWidth': processingWidth,
      if (processingHeight != null) 'processingHeight': processingHeight,
      'confidenceThreshold': confidenceThreshold,
      'debug': debug,
      'smoothingEnabled': smoothingEnabled,
      'positionSmoothing': positionSmoothing,
      'rotationSmoothing': rotationSmoothing,
      'lostTimeoutMs': lostTimeout.inMilliseconds,
      'hideContentWhenLost': hideContentWhenLost,
    };
  }

  ARMarkerDetectionOptions copyWith({
    int? maxDetectionFps,
    int? processingWidth,
    int? processingHeight,
    double? confidenceThreshold,
    bool? debug,
    bool? smoothingEnabled,
    double? positionSmoothing,
    double? rotationSmoothing,
    Duration? lostTimeout,
    bool? hideContentWhenLost,
  }) {
    return ARMarkerDetectionOptions(
      maxDetectionFps: maxDetectionFps ?? this.maxDetectionFps,
      processingWidth: processingWidth ?? this.processingWidth,
      processingHeight: processingHeight ?? this.processingHeight,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      debug: debug ?? this.debug,
      smoothingEnabled: smoothingEnabled ?? this.smoothingEnabled,
      positionSmoothing: positionSmoothing ?? this.positionSmoothing,
      rotationSmoothing: rotationSmoothing ?? this.rotationSmoothing,
      lostTimeout: lostTimeout ?? this.lostTimeout,
      hideContentWhenLost: hideContentWhenLost ?? this.hideContentWhenLost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARMarkerDetectionOptions &&
          maxDetectionFps == other.maxDetectionFps &&
          processingWidth == other.processingWidth &&
          processingHeight == other.processingHeight &&
          confidenceThreshold == other.confidenceThreshold &&
          debug == other.debug &&
          smoothingEnabled == other.smoothingEnabled &&
          positionSmoothing == other.positionSmoothing &&
          rotationSmoothing == other.rotationSmoothing &&
          lostTimeout == other.lostTimeout &&
          hideContentWhenLost == other.hideContentWhenLost;

  @override
  int get hashCode => Object.hash(
    maxDetectionFps,
    processingWidth,
    processingHeight,
    confidenceThreshold,
    debug,
    smoothingEnabled,
    positionSmoothing,
    rotationSmoothing,
    lostTimeout,
    hideContentWhenLost,
  );
}
