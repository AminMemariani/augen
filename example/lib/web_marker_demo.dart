import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:augen/augen.dart' hide AnimationStatus;

/// Demonstrates web marker-based AR using AugenView with marker tracking.
///
/// This demo registers a Hiro pattern marker, listens to the tracked-markers
/// stream, displays debug info (camera status, detector status, marker
/// visibility, confidence, FPS), and anchors a cube to the detected marker.
///
/// Primary target: **web** (Chrome/Edge). Mobile platforms are not yet
/// supported for marker tracking and will show an informational message.
class WebMarkerDemo extends StatefulWidget {
  const WebMarkerDemo({super.key});

  @override
  State<WebMarkerDemo> createState() => _WebMarkerDemoState();
}

class _WebMarkerDemoState extends State<WebMarkerDemo> {
  AugenController? _controller;
  bool _initialized = false;
  String _cameraStatus = 'Waiting…';
  String _detectorStatus = 'Waiting…';
  bool _markerVisible = false;
  double _confidence = 0.0;
  int _fps = 0;
  String? _error;

  // FPS calculation
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  StreamSubscription<List<ARTrackedMarker>>? _markersSub;
  StreamSubscription<String>? _errorSub;

  // ---------- lifecycle ----------

  @override
  void dispose() {
    _markersSub?.cancel();
    _errorSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ---------- AR setup ----------

  Future<void> _onViewCreated(AugenController controller) async {
    _controller = controller;

    // Subscribe to error stream EARLY so init-time errors surface.
    _errorSub = controller.errorStream.listen((err) {
      if (!mounted) return;
      setState(() {
        _error = err;
        if (err.contains('camera') || err.contains('Camera')) {
          _cameraStatus = 'Camera error';
        }
        if (err.contains('detector') || err.contains('Detector')) {
          _detectorStatus = 'Detector error';
        }
      });
    });

    try {
      setState(() => _cameraStatus = 'Initializing…');

      // Bound initialize() so the UI never gets stuck if the browser
      // permission prompt is ignored or the JS bridge hangs.
      await controller
          .initialize(
            const ARSessionConfig(
              markerTracking: true,
              planeDetection: false,
              markerDetectionOptions: ARMarkerDetectionOptions(
                maxDetectionFps: 20,
                debug: true,
              ),
            ),
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () {
              throw TimeoutException(
                'initialize() timed out — camera permission may have been ignored.',
              );
            },
          );

      if (!mounted) return;
      setState(() {
        _cameraStatus = 'Camera active';
        _detectorStatus = 'Loading detector…';
      });

      // Register the Hiro pattern marker
      await controller.addMarkerTarget(
        const ARMarkerTarget(
          id: 'hiro',
          name: 'Hiro marker',
          type: ARMarkerType.pattern,
          imagePath: 'assets/markers/Hiro_marker.png',
          physicalWidth: 0.08, // 8 cm
        ),
      );

      await controller.setMarkerTrackingEnabled(true);

      setState(() {
        _detectorStatus = 'Detector ready';
        _initialized = true;
      });

      // Listen to tracked markers (error stream is already subscribed above)
      _markersSub = controller.trackedMarkersStream.listen(_onMarkers);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cameraStatus = 'Error';
        _detectorStatus = 'Error';
      });
    }
  }

  void _onMarkers(List<ARTrackedMarker> markers) {
    if (!mounted) return;

    // FPS calculation
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
    if (elapsed >= 1000) {
      _fps = (_frameCount * 1000 / elapsed).round();
      _frameCount = 0;
      _lastFpsUpdate = now;
    }

    final hiro = markers.where((m) => m.targetId == 'hiro').firstOrNull;
    final visible = hiro != null && hiro.isTracked;

    setState(() {
      _markerVisible = visible;
      _confidence = hiro?.confidence ?? 0.0;
    });

    // Anchor a cube when the marker is reliably tracked
    if (hiro != null && hiro.isTracked && hiro.isReliable) {
      _anchorCube(hiro);
    }
  }

  bool _cubeAdded = false;

  Future<void> _anchorCube(ARTrackedMarker marker) async {
    if (_cubeAdded || _controller == null) return;
    _cubeAdded = true;

    try {
      await _controller!.addNode(
        ARNode(
          id: 'marker_cube',
          type: NodeType.cube,
          position: marker.position,
          rotation: marker.rotation,
          scale: const Vector3(0.04, 0.04, 0.04),
          properties: const {'color': 'green'},
        ),
      );
    } catch (e) {
      _cubeAdded = false; // allow retry
      if (mounted) setState(() => _error = 'Failed to add cube: $e');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.web, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Web Marker AR is only supported on web.\n'
                'Run with: flutter run -d chrome --wasm',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // AR camera + scene
        AugenView(
          config: const ARSessionConfig(
            markerTracking: true,
            planeDetection: false,
          ),
          onViewCreated: _onViewCreated,
        ),

        // Debug overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _debugRow('📷 Camera', _cameraStatus),
                _debugRow('🔍 Detector', _detectorStatus),
                _debugRow(
                  '🎯 Marker',
                  _markerVisible ? 'VISIBLE ✅' : 'Lost ❌',
                ),
                _debugRow(
                  '📊 Confidence',
                  '${(_confidence * 100).toStringAsFixed(1)}%',
                ),
                _debugRow('⚡ FPS', '$_fps'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ $_error',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Help text
        if (_initialized && !_markerVisible)
          const Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Center(
              child: Text(
                'Point camera at a Hiro marker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
