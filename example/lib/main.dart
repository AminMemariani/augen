import 'package:flutter/material.dart';
import 'package:augen/augen.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Augen AR Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ARHomePage(),
    );
  }
}

class ARHomePage extends StatefulWidget {
  const ARHomePage({super.key});

  @override
  State<ARHomePage> createState() => _ARHomePageState();
}

class _ARHomePageState extends State<ARHomePage> {
  AugenController? _controller;
  bool _isInitialized = false;
  List<ARPlane> _detectedPlanes = [];
  int _nodeCounter = 0;
  String _statusMessage = 'Initializing...';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onARViewCreated(AugenController controller) {
    _controller = controller;
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    if (_controller == null) return;

    try {
      // Check AR support
      final isSupported = await _controller!.isARSupported();
      setState(() {
        _statusMessage = isSupported
            ? 'AR Supported - Initializing...'
            : 'AR Not Supported on this device';
      });

      if (!isSupported) return;

      // Initialize AR session
      await _controller!.initialize(
        const ARSessionConfig(
          planeDetection: true,
          lightEstimation: true,
          depthData: false,
          autoFocus: true,
        ),
      );

      setState(() {
        _isInitialized = true;
        _statusMessage = 'AR Session Active - Tap to place objects';
      });

      // Listen to plane detection
      _controller!.planesStream.listen((planes) {
        setState(() {
          _detectedPlanes = planes;
        });
      });

      // Listen to errors
      _controller!.errorStream.listen((error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AR Error: $error')));
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _addObjectAtScreenCenter() async {
    if (_controller == null || !_isInitialized) return;

    try {
      // Perform hit test at screen center
      final size = MediaQuery.of(context).size;
      final results = await _controller!.hitTest(
        size.width / 2,
        size.height / 2,
      );

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No surface detected. Try moving your device around.',
            ),
          ),
        );
        return;
      }

      // Add a node at the hit position
      final hitResult = results.first;
      final nodeId = 'node_${_nodeCounter++}';

      await _controller!.addNode(
        ARNode(
          id: nodeId,
          type: _getRandomNodeType(),
          position: hitResult.position,
          rotation: hitResult.rotation,
          scale: const Vector3(1, 1, 1),
          properties: {'color': 'blue'},
        ),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added object: $nodeId')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add object: $e')));
    }
  }

  NodeType _getRandomNodeType() {
    final types = [NodeType.sphere, NodeType.cube, NodeType.cylinder];
    return types[Random().nextInt(types.length)];
  }

  Future<void> _addAnchor() async {
    if (_controller == null || !_isInitialized) return;

    try {
      final anchor = await _controller!.addAnchor(
        const Vector3(0, 0, -0.5), // 0.5 meters in front of camera
      );

      if (anchor != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Anchor added: ${anchor.id}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add anchor: $e')));
    }
  }

  Future<void> _resetSession() async {
    if (_controller == null) return;

    try {
      await _controller!.reset();
      setState(() {
        _nodeCounter = 0;
        _detectedPlanes.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AR Session Reset')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reset: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Augen AR Demo'),
      ),
      body: Stack(
        children: [
          // AR View
          AugenView(
            onViewCreated: _onARViewCreated,
            config: const ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
              depthData: false,
              autoFocus: true,
            ),
          ),

          // Status overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (_detectedPlanes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Detected planes: ${_detectedPlanes.length}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_nodeCounter > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Objects placed: $_nodeCounter',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Help text
          if (_isInitialized)
            const Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Center(
                child: Text(
                  'Tap the + button to place an object',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isInitialized
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'add_object',
                  onPressed: _addObjectAtScreenCenter,
                  tooltip: 'Add Object',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add_anchor',
                  onPressed: _addAnchor,
                  tooltip: 'Add Anchor',
                  child: const Icon(Icons.place),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: _resetSession,
                  tooltip: 'Reset Session',
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
    );
  }
}
