import 'package:flutter/material.dart';
import 'package:augen/augen.dart' hide AnimationStatus;
import 'package:augen/augen.dart' as augen;
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
      title: 'Augen AR Demo - Complete Features',
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

class _ARHomePageState extends State<ARHomePage> with TickerProviderStateMixin {
  AugenController? _controller;
  bool _isInitialized = false;
  List<ARPlane> _detectedPlanes = [];
  List<ARImageTarget> _imageTargets = [];
  List<ARTrackedImage> _trackedImages = [];
  int _nodeCounter = 0;
  String _statusMessage = 'Initializing...';
  bool _imageTrackingEnabled = false;
  int _currentTabIndex = 0;
  late TabController _tabController;

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _blendController;
  String? _currentAnimation;
  double _blendWeight = 0.5;

  // Stream subscriptions
  StreamSubscription<List<ARPlane>>? _planesSubscription;
  StreamSubscription<List<ARImageTarget>>? _imageTargetsSubscription;
  StreamSubscription<List<ARTrackedImage>>? _trackedImagesSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<augen.AnimationStatus>? _animationStatusSubscription;
  StreamSubscription<TransitionStatus>? _transitionStatusSubscription;
  StreamSubscription<StateMachineStatus>? _stateMachineStatusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _blendController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _planesSubscription?.cancel();
    _imageTargetsSubscription?.cancel();
    _trackedImagesSubscription?.cancel();
    _errorSubscription?.cancel();
    _animationStatusSubscription?.cancel();
    _transitionStatusSubscription?.cancel();
    _stateMachineStatusSubscription?.cancel();
    _tabController.dispose();
    _animationController.dispose();
    _blendController.dispose();
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
        _statusMessage = 'AR Session Active - All features ready!';
      });

      // Set up all stream listeners
      _setupStreamListeners();

      // Add sample image targets
      await _addSampleImageTargets();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _setupStreamListeners() {
    if (_controller == null) return;

    // Plane detection
    _planesSubscription = _controller!.planesStream.listen((planes) {
      if (!mounted) return;
      setState(() {
        _detectedPlanes = planes;
      });
    });

    // Image targets
    _imageTargetsSubscription = _controller!.imageTargetsStream.listen((
      targets,
    ) {
      if (!mounted) return;
      setState(() {
        _imageTargets = targets;
      });
    });

    // Tracked images
    _trackedImagesSubscription = _controller!.trackedImagesStream.listen((
      tracked,
    ) {
      if (!mounted) return;
      setState(() {
        _trackedImages = tracked;
      });
      
      // Automatically add content to newly tracked images
      for (final trackedImage in tracked) {
        if (trackedImage.isTracked && trackedImage.isReliable) {
          _addContentToTrackedImage(trackedImage);
        }
      }
    });

    // Error handling
    _errorSubscription = _controller!.errorStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AR Error: $error')));
    });

    // Animation status
    _animationStatusSubscription = _controller!.animationStatusStream.listen((
      status,
    ) {
      if (!mounted) return;
      // Handle animation status updates
    });

    // Transition status
    _transitionStatusSubscription = _controller!.transitionStatusStream.listen((
      status,
    ) {
      if (!mounted) return;
      // Handle transition status updates
    });

    // State machine status
    _stateMachineStatusSubscription = _controller!.stateMachineStatusStream
        .listen((status) {
          if (!mounted) return;
          // Handle state machine status updates
        });
  }

  Future<void> _addSampleImageTargets() async {
    if (_controller == null) return;

    try {
      // Add sample image targets (using URLs for demonstration)
      final targets = [
        ARImageTarget(
          id: 'poster1',
          name: 'Movie Poster',
          imagePath: 'https://example.com/images/sample_poster.jpg',
          physicalSize: const ImageTargetSize(0.3, 0.4), // 30cm x 40cm
        ),
        ARImageTarget(
          id: 'business_card',
          name: 'Business Card',
          imagePath: 'https://example.com/images/sample_card.jpg',
          physicalSize: const ImageTargetSize(
            0.085,
            0.055,
          ), // Standard business card size
        ),
      ];

      for (final target in targets) {
        await _controller!.addImageTarget(target);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample image targets added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add image targets: $e')),
      );
    }
  }

  Future<void> _addContentToTrackedImage(ARTrackedImage trackedImage) async {
    if (_controller == null) return;

    try {
      final nodeId = 'content_${trackedImage.id}';

      // Create a 3D model node
      final contentNode = ARNode.fromModel(
        id: nodeId,
        modelPath: 'https://example.com/models/character.glb',
        position: const Vector3(0, 0, 0.1), // 10cm above the image
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.1, 0.1, 0.1),
      );

      await _controller!.addNodeToTrackedImage(
        nodeId: nodeId,
        trackedImageId: trackedImage.id,
        node: contentNode,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Content added to ${trackedImage.targetId}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add content: $e')));
    }
  }

  // Image Tracking Methods
  Future<void> _toggleImageTracking() async {
    if (_controller == null) return;

    try {
      _imageTrackingEnabled = !_imageTrackingEnabled;
      await _controller!.setImageTrackingEnabled(_imageTrackingEnabled);

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _imageTrackingEnabled
                ? 'Image tracking enabled'
                : 'Image tracking disabled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle image tracking: $e')),
      );
    }
  }

  Future<void> _addCustomImageTarget() async {
    if (_controller == null) return;

    try {
      final target = ARImageTarget(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Custom Target',
        imagePath: 'https://example.com/images/custom_target.jpg',
        physicalSize: const ImageTargetSize(0.2, 0.2), // 20cm x 20cm
      );

      await _controller!.addImageTarget(target);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom image target added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add custom target: $e')),
      );
    }
  }

  // Animation Methods
  Future<void> _playAnimation(String animationName) async {
    if (_controller == null) return;

    try {
      await _controller!.playAnimation(
        nodeId: 'character_node',
        animationId: animationName,
      );
      _currentAnimation = animationName;

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playing animation: $animationName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to play animation: $e')));
    }
  }

  Future<void> _blendAnimations() async {
    if (_controller == null) return;

    try {
      await _controller!.blendAnimations(
        nodeId: 'character_node',
        animationWeights: {'idle': 1.0 - _blendWeight, 'walk': _blendWeight},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animation blending applied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to blend animations: $e')));
    }
  }

  Future<void> _crossfadeAnimation() async {
    if (_controller == null) return;

    try {
      await _controller!.crossfadeToAnimation(
        nodeId: 'character_node',
        fromAnimationId: 'idle',
        toAnimationId: 'walk',
        duration: 1.0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animation crossfade applied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to crossfade animation: $e')),
      );
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
        if (!mounted) return;
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added object: $nodeId')));
    } catch (e) {
      if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Anchor added: ${anchor.id}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add anchor: $e')));
    }
  }

  Future<void> _resetSession() async {
    if (_controller == null) return;

    try {
      await _controller!.reset();
      if (!mounted) return;
      setState(() {
        _nodeCounter = 0;
        _detectedPlanes.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AR Session Reset')));
    } catch (e) {
      if (!mounted) return;
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
        title: const Text('Augen AR Demo - Complete Features'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() => _currentTabIndex = index),
          tabs: const [
            Tab(icon: Icon(Icons.view_in_ar), text: 'AR View'),
            Tab(icon: Icon(Icons.image_search), text: 'Image Tracking'),
            Tab(icon: Icon(Icons.animation), text: 'Animations'),
            Tab(icon: Icon(Icons.info), text: 'Status'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _buildARView(),
          _buildImageTrackingView(),
          _buildAnimationView(),
          _buildStatusView(),
        ],
      ),
    );
  }

  Widget _buildARView() {
    return Stack(
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
              color: Colors.black.withValues(alpha: 0.7),
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
    );
  }

  Widget _buildImageTrackingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image Tracking',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Image tracking toggle
          Card(
            child: ListTile(
              leading: Icon(
                _imageTrackingEnabled ? Icons.visibility : Icons.visibility_off,
              ),
              title: const Text('Image Tracking'),
              subtitle: Text(_imageTrackingEnabled ? 'Enabled' : 'Disabled'),
              trailing: Switch(
                value: _imageTrackingEnabled,
                onChanged: (_) => _toggleImageTracking(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Image targets section
          Text(
            'Image Targets (${_imageTargets.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: _imageTargets.length,
              itemBuilder: (context, index) {
                final target = _imageTargets[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.image),
                    title: Text(target.name),
                    subtitle: Text(
                      'Size: ${target.physicalSize.width}m x ${target.physicalSize.height}m',
                    ),
                    trailing: Icon(
                      target.isActive ? Icons.check_circle : Icons.cancel,
                      color: target.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
          ),

          // Tracked images section
          Text(
            'Tracked Images (${_trackedImages.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: _trackedImages.length,
              itemBuilder: (context, index) {
                final tracked = _trackedImages[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      tracked.isTracked
                          ? Icons.track_changes
                          : Icons.search_off,
                      color: tracked.isTracked ? Colors.green : Colors.orange,
                    ),
                    title: Text('Target: ${tracked.targetId}'),
                    subtitle: Text(
                      'State: ${tracked.trackingState.name}\n'
                      'Confidence: ${(tracked.confidence * 100).toStringAsFixed(1)}%',
                    ),
                    trailing: Icon(
                      tracked.isReliable ? Icons.verified : Icons.warning,
                      color: tracked.isReliable ? Colors.green : Colors.orange,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animation Controls',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Current animation
          if (_currentAnimation != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Current Animation'),
                subtitle: Text(_currentAnimation!),
              ),
            ),

          const SizedBox(height: 16),

          // Animation buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _playAnimation('idle'),
                icon: const Icon(Icons.pause),
                label: const Text('Idle'),
              ),
              ElevatedButton.icon(
                onPressed: () => _playAnimation('walk'),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Walk'),
              ),
              ElevatedButton.icon(
                onPressed: () => _playAnimation('jump'),
                icon: const Icon(Icons.vertical_align_top),
                label: const Text('Jump'),
              ),
              ElevatedButton.icon(
                onPressed: () => _playAnimation('run'),
                icon: const Icon(Icons.directions_run),
                label: const Text('Run'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Animation blending
          Text(
            'Animation Blending',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Blend Weight: ${_blendWeight.toStringAsFixed(2)}'),
                  Slider(
                    value: _blendWeight,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() {
                        _blendWeight = value;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: _blendAnimations,
                    icon: const Icon(Icons.merge),
                    label: const Text('Apply Blend'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Crossfade animation
          Text(
            'Animation Crossfade',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _crossfadeAnimation,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Crossfade to Walk'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AR Status', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Session status
          Card(
            child: ListTile(
              leading: Icon(
                _isInitialized ? Icons.check_circle : Icons.error,
                color: _isInitialized ? Colors.green : Colors.red,
              ),
              title: const Text('AR Session'),
              subtitle: Text(_isInitialized ? 'Active' : 'Not Initialized'),
            ),
          ),

          const SizedBox(height: 16),

          // Statistics
          Text('Statistics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow(
                    'Detected Planes',
                    _detectedPlanes.length.toString(),
                  ),
                  _buildStatRow(
                    'Image Targets',
                    _imageTargets.length.toString(),
                  ),
                  _buildStatRow(
                    'Tracked Images',
                    _trackedImages.length.toString(),
                  ),
                  _buildStatRow('Objects Placed', _nodeCounter.toString()),
                  _buildStatRow(
                    'Image Tracking',
                    _imageTrackingEnabled ? 'Enabled' : 'Disabled',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Control buttons
          Text(
            'Session Controls',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _addObjectAtScreenCenter,
                icon: const Icon(Icons.add),
                label: const Text('Add Object'),
              ),
              ElevatedButton.icon(
                onPressed: _addAnchor,
                icon: const Icon(Icons.place),
                label: const Text('Add Anchor'),
              ),
              ElevatedButton.icon(
                onPressed: _addCustomImageTarget,
                icon: const Icon(Icons.image),
                label: const Text('Add Target'),
              ),
              ElevatedButton.icon(
                onPressed: _resetSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
