import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'js_interop/augen_web_ar_interop.dart';
import '../models/ar_marker_target.dart';
import '../models/ar_tracked_marker.dart';
import '../models/ar_marker_config.dart';
import '../models/vector2.dart';
import '../models/vector3.dart';
import '../models/quaternion.dart';

/// Wraps the JS/Wasm marker detector.
class WasmMarkerDetector {
  MarkerDetectorJS? _detector;
  bool _isInitialized = false;
  bool _isEnabled = false;
  bool _disposed = false;
  ARMarkerDetectionOptions _options;
  final Map<String, ARMarkerTarget> _targets = {};
  final _trackedMarkersController =
      StreamController<List<ARTrackedMarker>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // RAF-based loop state (W1)
  int? _rafHandle;
  double _lastFrameTime = 0;
  JSFunction? _frameCallback;
  bool _frameInFlight = false;
  web.EventListener? _visibilityListener;

  WasmMarkerDetector({
    ARMarkerDetectionOptions options = const ARMarkerDetectionOptions(),
  }) : _options = options;

  Stream<List<ARTrackedMarker>> get trackedMarkersStream =>
      _trackedMarkersController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final optionsJs = _options.toMap().jsify() as JSObject;
      final result = await augenWebAR.createMarkerDetector(optionsJs).toDart;
      _detector = result as MarkerDetectorJS;
      _isInitialized = true;
    } catch (e) {
      throw StateError('Failed to initialize marker detector: $e');
    }
  }

  void addTarget(ARMarkerTarget target) {
    _targets[target.id] = target;
    if (_isInitialized && _detector != null) {
      _detector!.addMarkerTarget(target.toMap().jsify() as JSObject);
    }
  }

  void removeTarget(String targetId) {
    _targets.remove(targetId);
    if (_isInitialized && _detector != null) {
      _detector!.removeMarkerTarget(targetId.toJS);
    }
  }

  List<ARMarkerTarget> getTargets() => _targets.values.toList();

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (_detector != null) {
      _detector!.setEnabled(enabled.toJS);
    }
    // Start detection loop when enabled if we have a pending video element
    if (enabled && _pendingVideoElement != null && _rafHandle == null) {
      startDetectionLoop(_pendingVideoElement!);
    } else if (!enabled) {
      _cancelRaf();
    }
  }

  web.HTMLVideoElement? _pendingVideoElement;

  void setOptions(ARMarkerDetectionOptions options) {
    _options = options;
  }

  void startDetectionLoop(web.HTMLVideoElement videoElement) {
    if (_disposed) return;
    _pendingVideoElement = videoElement;
    _cancelRaf();

    // Remove existing visibility listener to prevent leaks
    if (_visibilityListener != null) {
      web.document.removeEventListener('visibilitychange', _visibilityListener);
      _visibilityListener = null;
    }

    _visibilityListener = (web.Event event) {
      if (web.document.hidden) {
        _cancelRaf();
      } else if (_isEnabled && _isInitialized && !_disposed) {
        _scheduleNextFrame(videoElement);
      }
    }.toJS;
    web.document.addEventListener('visibilitychange', _visibilityListener);

    _scheduleNextFrame(videoElement);
  }

  void _scheduleNextFrame(web.HTMLVideoElement video) {
    if (_disposed) return;
    _frameCallback = ((JSAny timestamp) {
      final ts = (timestamp as JSNumber).toDartDouble;
      _onAnimationFrame(video, ts);
    }).toJS;
    _rafHandle = web.window.requestAnimationFrame(_frameCallback!);
  }

  void _onAnimationFrame(web.HTMLVideoElement video, double timestamp) {
    if (_disposed || !_isEnabled) {
      _rafHandle = null;
      return;
    }

    // FPS gate: only process if enough time has elapsed
    final intervalMs = 1000 / _options.maxDetectionFps;
    final elapsed = timestamp - _lastFrameTime;

    if (elapsed >= intervalMs && !_frameInFlight) {
      _lastFrameTime = timestamp;
      // Fire and forget; _processFrame manages _frameInFlight
      _processFrame(video);
    }

    // Schedule next frame
    if (_isEnabled && !_disposed) {
      _scheduleNextFrame(video);
    } else {
      _rafHandle = null;
    }
  }

  void _cancelRaf() {
    if (_rafHandle != null) {
      web.window.cancelAnimationFrame(_rafHandle!);
      _rafHandle = null;
    }
  }

  void stopDetectionLoop() {
    _cancelRaf();
    if (_visibilityListener != null) {
      web.document.removeEventListener('visibilitychange', _visibilityListener);
      _visibilityListener = null;
    }
  }

  Future<void> _processFrame(web.HTMLVideoElement videoElement) async {
    if (_disposed) return;
    if (_trackedMarkersController.isClosed) return;
    if (!_isEnabled || _detector == null) return;
    // Skip frame if video is not ready or has no dimensions
    if (videoElement.readyState < 2 || videoElement.videoWidth == 0) return;
    _frameInFlight = true;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final results = await _detector!
          .processFrame(videoElement as JSObject, timestamp.toJS)
          .toDart;
      if (_trackedMarkersController.isClosed) return;
      // W2: allocate DateTime.now() once per batch instead of per marker.
      final batchTime = DateTime.now();
      final markers =
          results.toDart.map((r) => _convertResult(r, batchTime)).toList();
      _trackedMarkersController.add(markers);
    } catch (e) {
      // Only report unexpected errors to the error stream
      final message = e.toString();
      if (!_errorController.isClosed) {
        _errorController.add('Frame processing error: $message');
      }
    } finally {
      _frameInFlight = false;
    }
  }

  ARTrackedMarker _convertResult(JSObject jsResult, DateTime batchTime) {
    final result = jsResult as MarkerDetectionResultJS;
    // W3: pre-allocate buffers to avoid intermediate .map().toList() chains.
    final transformJs = result.transform;
    final transformLength = transformJs.length;
    final transformArr = List<double>.filled(transformLength, 0.0);
    for (var i = 0; i < transformLength; i++) {
      transformArr[i] = (transformJs[i]).toDartDouble;
    }

    final cornersJs = result.corners;
    final cornersLength = cornersJs.length;
    final cornersArr = List<Vector2>.filled(
      cornersLength,
      const Vector2(0, 0),
      growable: false,
    );
    for (var i = 0; i < cornersLength; i++) {
      final corner = cornersJs[i] as CornerJS;
      cornersArr[i] = Vector2(corner.x.toDartDouble, corner.y.toDartDouble);
    }

    return ARTrackedMarker(
      id: result.id.toDart,
      targetId: result.targetId.toDart,
      type: _parseType(result.type.toDart),
      position: Vector3(
        transformArr.length > 12 ? transformArr[12] : 0,
        transformArr.length > 13 ? transformArr[13] : 0,
        transformArr.length > 14 ? transformArr[14] : 0,
      ),
      // TODO(augen): Decompose rotation from transform matrix elements 0-11
      rotation: const Quaternion(0, 0, 0, 1),
      transform: transformArr,
      corners: cornersArr,
      confidence: result.confidence.toDartDouble,
      trackingState: _parseTrackingState(result.trackingState.toDart),
      lastUpdated: batchTime,
    );
  }

  ARMarkerType _parseType(String type) {
    switch (type) {
      case 'pattern':
        return ARMarkerType.pattern;
      case 'barcode':
        return ARMarkerType.barcode;
      case 'aruco':
        return ARMarkerType.aruco;
      default:
        return ARMarkerType.pattern;
    }
  }

  ARMarkerTrackingState _parseTrackingState(String state) {
    switch (state) {
      case 'tracked':
        return ARMarkerTrackingState.tracked;
      case 'lost':
      case 'notTracked':
        return ARMarkerTrackingState.notTracked;
      default:
        return ARMarkerTrackingState.notTracked;
    }
  }

  void dispose() {
    _disposed = true;
    stopDetectionLoop();
    _detector?.dispose();
    _detector = null;
    _trackedMarkersController.close();
    _errorController.close();
    _isInitialized = false;
  }
}
