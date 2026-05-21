import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:augen/augen.dart' hide AnimationStatus;

void main() {
  runApp(const WebMarkerARApp());
}

class WebMarkerARApp extends StatelessWidget {
  const WebMarkerARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Augen Web Marker AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MarkerARScreen(),
    );
  }
}

class MarkerARScreen extends StatefulWidget {
  const MarkerARScreen({super.key});

  @override
  State<MarkerARScreen> createState() => _MarkerARScreenState();
}

class _MarkerARScreenState extends State<MarkerARScreen> {
  AugenController? _controller;
  bool _initialized = false;
  bool _trackingEnabled = true;
  bool _showDebug = true;
  String _cameraStatus = 'Waiting…';
  String _detectorStatus = 'Waiting…';
  bool _markerVisible = false;
  double _confidence = 0.0;
  int _fps = 0;
  String? _markerId;
  String? _markerType;
  String? _error;

  // FPS calculation
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  StreamSubscription<List<ARTrackedMarker>>? _markersSub;
  StreamSubscription<String>? _errorSub;
  bool _cubeAdded = false;

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

    // Subscribe to error stream early so we capture init-time errors.
    _errorSub = controller.errorStream.listen((err) {
      if (!mounted) return;
      setState(() => _error = err);
      // Update status labels for known error codes
      if (err.contains('Camera') || err.contains('camera')) {
        setState(() => _cameraStatus = 'Camera unavailable ❌');
      }
      if (err.contains('Detector') || err.contains('detector')) {
        setState(() => _detectorStatus = 'Detector failed ❌');
      }
      _showSnackBar('⚠️ $err');
    });

    try {
      setState(() => _cameraStatus = 'Requesting permission…');

      await controller.initialize(
        const ARSessionConfig(
          markerTracking: true,
          planeDetection: false,
          markerDetectionOptions: ARMarkerDetectionOptions(
            maxDetectionFps: 20,
            debug: true,
          ),
        ),
      );

      setState(() {
        // Only mark camera active if no error was reported
        if (!(_cameraStatus.contains('❌'))) {
          _cameraStatus = 'Camera active ✅';
        }
        if (!(_detectorStatus.contains('❌'))) {
          _detectorStatus = 'Loading detector…';
        }
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
        if (!(_detectorStatus.contains('❌'))) {
          _detectorStatus = 'Detector ready ✅';
        }
        _initialized = true;
      });

      _markersSub = controller.trackedMarkersStream.listen(_onMarkers);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cameraStatus = 'Error ❌';
        _detectorStatus = 'Error ❌';
      });
      _showSnackBar('Initialization failed: $e');
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
      _markerId = hiro?.targetId;
      _markerType = hiro != null ? 'pattern' : null;
    });

    if (hiro != null && hiro.isTracked && hiro.isReliable) {
      _anchorCube(hiro);
    }
  }

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
      _showSnackBar('🟩 Cube anchored to marker!');
    } catch (e) {
      _cubeAdded = false;
      _showSnackBar('Failed to add cube: $e');
    }
  }

  Future<void> _toggleTracking() async {
    if (_controller == null) return;
    final newState = !_trackingEnabled;
    try {
      await _controller!.setMarkerTrackingEnabled(newState);
      setState(() => _trackingEnabled = newState);
      _showSnackBar(
        newState ? '▶️ Tracking enabled' : '⏸️ Tracking paused',
      );
    } catch (e) {
      _showSnackBar('Failed to toggle tracking: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Web Marker AR')),
        body: const Center(
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
        ),
      );
    }

    return Scaffold(
      body: Stack(
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
          if (_showDebug)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.black.withValues(alpha: 0.8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Augen Web Marker AR',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 12),
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
                      if (_markerId != null)
                        _debugRow('🏷️ ID', _markerId!),
                      if (_markerType != null)
                        _debugRow('📐 Type', _markerType!),
                      _debugRow(
                        '▶️ Tracking',
                        _trackingEnabled ? 'ON' : 'OFF',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠️ $_error',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Instruction text
          if (_initialized && !_markerVisible)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    '📸 Point camera at a Hiro marker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // FABs
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'debug',
            onPressed: () => setState(() => _showDebug = !_showDebug),
            tooltip: 'Toggle debug overlay',
            child: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
          ),
          const SizedBox(height: 8),
          if (_initialized)
            FloatingActionButton.small(
              heroTag: 'tracking',
              onPressed: _toggleTracking,
              tooltip: _trackingEnabled ? 'Pause tracking' : 'Resume tracking',
              child: Icon(
                _trackingEnabled ? Icons.pause : Icons.play_arrow,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
