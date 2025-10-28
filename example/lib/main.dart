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
  List<ARFace> _trackedFaces = [];
  List<ARCloudAnchor> _cloudAnchors = [];
  List<AROcclusion> _occlusions = [];
  List<ARPhysicsBody> _physicsBodies = [];
  List<PhysicsConstraint> _physicsConstraints = [];
  List<ARLight> _lights = [];
  ARLightingConfig? _lightingConfig;
  bool _lightingSupported = false;
  bool _shadowsEnabled = true;
  ShadowQuality _shadowQuality = ShadowQuality.medium;
  List<AREnvironmentalProbe> _environmentalProbes = [];
  AREnvironmentalProbeConfig? _probeConfig;
  bool _environmentalProbesSupported = false;
  int _nodeCounter = 0;
  String _statusMessage = 'Initializing...';
  bool _imageTrackingEnabled = false;
  bool _faceTrackingEnabled = false;
  bool _cloudAnchorsSupported = false;
  bool _occlusionSupported = false;
  bool _occlusionEnabled = false;
  bool _physicsSupported = false;
  bool _physicsEnabled = false;
  String? _currentSessionId;
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
  StreamSubscription<List<ARFace>>? _facesSubscription;
  StreamSubscription<List<ARCloudAnchor>>? _cloudAnchorsSubscription;
  StreamSubscription<CloudAnchorStatus>? _cloudAnchorStatusSubscription;
  StreamSubscription<List<AROcclusion>>? _occlusionsSubscription;
  StreamSubscription<OcclusionStatus>? _occlusionStatusSubscription;
  StreamSubscription<List<ARPhysicsBody>>? _physicsBodiesSubscription;
  StreamSubscription<List<PhysicsConstraint>>? _physicsConstraintsSubscription;
  StreamSubscription<PhysicsStatus>? _physicsStatusSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<augen.AnimationStatus>? _animationStatusSubscription;
  StreamSubscription<TransitionStatus>? _transitionStatusSubscription;
  StreamSubscription<StateMachineStatus>? _stateMachineStatusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 11,
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

      // Check cloud anchor support
      await _checkCloudAnchorSupport();

      // Check occlusion support
      await _checkOcclusionSupport();

      // Check physics support
      await _checkPhysicsSupport();

      // Check lighting support
      await _checkLightingSupport();
      await _checkEnvironmentalProbesSupport();
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

    // Tracked faces
    _facesSubscription = _controller!.facesStream.listen((faces) {
      if (!mounted) return;
      setState(() {
        _trackedFaces = faces;
      });
      for (final face in faces) {
        if (face.isTracked && face.isReliable) {
          _addContentToTrackedFace(face);
        }
      }
    });

    _cloudAnchorsSubscription = _controller!.cloudAnchorsStream.listen((
      anchors,
    ) {
      if (!mounted) return;
      setState(() {
        _cloudAnchors = anchors;
      });
    });

    _cloudAnchorStatusSubscription = _controller!.cloudAnchorStatusStream
        .listen((status) {
          if (!mounted) return;
          if (status.isComplete) {
            if (status.isSuccessful) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cloud anchor ${status.cloudAnchorId} ready!'),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cloud anchor failed: ${status.errorMessage}'),
                ),
              );
            }
          }
        });

    // Occlusion streams
    _occlusionsSubscription = _controller!.occlusionsStream.listen((
      occlusions,
    ) {
      if (!mounted) return;
      setState(() {
        _occlusions = occlusions;
      });
    });

    _occlusionStatusSubscription = _controller!.occlusionStatusStream.listen((
      status,
    ) {
      if (!mounted) return;
      if (status.isComplete) {
        if (status.isSuccessful) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Occlusion ${status.occlusionId} ready!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Occlusion failed: ${status.errorMessage}')),
          );
        }
      }
    });

    _physicsBodiesSubscription = _controller!.physicsBodiesStream.listen((
      bodies,
    ) {
      if (!mounted) return;
      setState(() {
        _physicsBodies = bodies;
      });
    });

    _physicsConstraintsSubscription = _controller!.physicsConstraintsStream
        .listen((constraints) {
          if (!mounted) return;
          setState(() {
            _physicsConstraints = constraints;
          });
        });

    _physicsStatusSubscription = _controller!.physicsStatusStream.listen((
      status,
    ) {
      if (!mounted) return;
      if (status.isComplete) {
        if (status.isSuccessful) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Physics simulation complete!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Physics simulation failed: ${status.errorMessage}',
              ),
            ),
          );
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

  Future<void> _addContentToTrackedFace(ARFace face) async {
    if (_controller == null) return;

    try {
      final nodeId = 'face_content_${face.id}';

      // Create a 3D model node for the face
      final contentNode = ARNode.fromModel(
        id: nodeId,
        modelPath: 'https://example.com/models/face_model.glb',
        position: const Vector3(0, 0, 0.1), // 10cm in front of the face
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.1, 0.1, 0.1),
      );

      await _controller!.addNodeToTrackedFace(
        nodeId: nodeId,
        faceId: face.id,
        node: contentNode,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Content added to face ${face.id}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add content to face: $e')),
      );
    }
  }

  // Cloud Anchor Methods
  Future<void> _checkCloudAnchorSupport() async {
    if (_controller == null) return;

    try {
      _cloudAnchorsSupported = await _controller!.isCloudAnchorsSupported();

      if (!mounted) return;
      setState(() {});

      if (_cloudAnchorsSupported) {
        await _controller!.setCloudAnchorConfig(
          maxCloudAnchors: 10,
          timeout: const Duration(seconds: 30),
          enableSharing: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check cloud anchor support: $e')),
      );
    }
  }

  Future<void> _createCloudAnchor() async {
    if (_controller == null || !_cloudAnchorsSupported) return;

    try {
      // Create a local anchor first
      // Create a local anchor at a specific position
      const anchorPosition = Vector3(0, 0, -1);
      final localAnchor = await _controller!.addAnchor(anchorPosition);

      if (localAnchor != null) {
        // Convert to cloud anchor
        final cloudAnchorId = await _controller!.createCloudAnchor(
          localAnchor.id,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creating cloud anchor: $cloudAnchorId')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create cloud anchor: $e')),
      );
    }
  }

  Future<void> _shareCloudAnchor() async {
    if (_controller == null || _cloudAnchors.isEmpty) return;

    try {
      final sessionId = await _controller!.shareCloudAnchor(
        _cloudAnchors.first.id,
      );

      if (!mounted) return;
      setState(() {
        _currentSessionId = sessionId;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Session ID: $sessionId')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share cloud anchor: $e')),
      );
    }
  }

  Future<void> _joinCloudAnchorSession() async {
    if (_controller == null) return;

    // Show dialog to enter session ID
    final sessionId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Cloud Anchor Session'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Session ID',
            hintText: 'Enter session ID to join',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final textController = TextEditingController();
              Navigator.pop(context, textController.text);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await _controller!.joinCloudAnchorSession(sessionId);

        if (!mounted) return;
        setState(() {
          _currentSessionId = sessionId;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joined session: $sessionId')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join session: $e')));
      }
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

  Future<void> _toggleFaceTracking() async {
    if (_controller == null) return;

    try {
      _faceTrackingEnabled = !_faceTrackingEnabled;
      await _controller!.setFaceTrackingEnabled(_faceTrackingEnabled);

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _faceTrackingEnabled
                ? 'Face tracking enabled'
                : 'Face tracking disabled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle face tracking: $e')),
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

  // Physics Methods
  Future<void> _checkPhysicsSupport() async {
    if (_controller == null) return;

    try {
      _physicsSupported = await _controller!.isPhysicsSupported();

      if (!mounted) return;
      setState(() {});

      if (_physicsSupported) {
        // Initialize physics world
        const config = PhysicsWorldConfig(
          gravity: Vector3(0, -9.81, 0),
          timeStep: 1.0 / 60.0,
          maxSubSteps: 10,
          enableSleeping: true,
          enableContinuousCollision: true,
        );

        await _controller!.initializePhysics(config);
        await _controller!.startPhysics();
        _physicsEnabled = true;

        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Physics support check failed: $e';
      });
    }
  }

  Future<void> _togglePhysics() async {
    if (_controller == null || !_physicsSupported) return;

    try {
      if (_physicsEnabled) {
        await _controller!.pausePhysics();
        _physicsEnabled = false;
      } else {
        await _controller!.resumePhysics();
        _physicsEnabled = true;
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to toggle physics: $e';
      });
    }
  }

  Future<void> _createPhysicsBody() async {
    if (_controller == null || !_physicsSupported) return;

    try {
      const material = PhysicsMaterial(
        density: 1.0,
        friction: 0.5,
        restitution: 0.3,
        linearDamping: 0.1,
        angularDamping: 0.1,
      );

      final bodyId = await _controller!.createPhysicsBody(
        nodeId: 'physics_node_${DateTime.now().millisecondsSinceEpoch}',
        type: PhysicsBodyType.dynamic,
        material: material,
        position: const Vector3(0, 2, -1),
        mass: 1.0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created physics body: $bodyId')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to create physics body: $e';
      });
    }
  }

  Future<void> _applyForce() async {
    if (_controller == null || _physicsBodies.isEmpty) return;

    try {
      final body = _physicsBodies.first;
      await _controller!.applyForce(
        bodyId: body.id,
        force: const Vector3(0, 0, -5),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Applied force to ${body.id}')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to apply force: $e';
      });
    }
  }

  // Lighting Methods
  Future<void> _checkLightingSupport() async {
    if (_controller == null) return;

    try {
      _lightingSupported = await _controller!.isLightingSupported();

      if (!mounted) return;
      setState(() {});

      if (_lightingSupported) {
        // Get lighting capabilities
        final capabilities = await _controller!.getLightingCapabilities();
        print('Lighting capabilities: $capabilities');

        // Set up default lighting configuration
        const config = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.medium,
          globalShadowFilterMode: ShadowFilterMode.soft,
          ambientIntensity: 0.3,
          ambientColor: Vector3(1.0, 1.0, 1.0),
          shadowDistance: 50.0,
          maxShadowCasters: 4,
          enableCascadedShadows: true,
          shadowCascadeCount: 4,
          shadowCascadeDistances: [10.0, 25.0, 50.0, 100.0],
          enableContactShadows: false,
          contactShadowDistance: 5.0,
          enableScreenSpaceShadows: false,
          enableRayTracedShadows: false,
        );

        await _controller!.setLightingConfig(config);
        _lightingConfig = config;

        // Add a default directional light
        final now = DateTime.now();
        final directionalLight = ARLight(
          id: 'sun_light',
          type: ARLightType.directional,
          position: const Vector3(0, 10, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          intensityUnit: LightIntensityUnit.lux,
          color: const Vector3(1.0, 0.95, 0.8), // Warm sunlight
          isEnabled: true,
          castShadows: true,
          shadowQuality: ShadowQuality.medium,
          shadowFilterMode: ShadowFilterMode.soft,
          createdAt: now,
          lastModified: now,
        );

        await _controller!.addLight(directionalLight);
        _lights.add(directionalLight);

        // Add an ambient light
        final ambientLight = ARLight(
          id: 'ambient_light',
          type: ARLightType.ambient,
          position: const Vector3(0, 0, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, 0, 0),
          intensity: 200.0,
          intensityUnit: LightIntensityUnit.lux,
          color: const Vector3(0.8, 0.9, 1.0), // Cool ambient
          isEnabled: true,
          castShadows: false,
          createdAt: now,
          lastModified: now,
        );

        await _controller!.addLight(ambientLight);
        _lights.add(ambientLight);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Lighting support check failed: $e';
      });
    }
  }

  Future<void> _checkEnvironmentalProbesSupport() async {
    if (_controller == null) return;

    try {
      _environmentalProbesSupported = await _controller!
          .isEnvironmentalProbesSupported();

      if (!mounted) return;
      setState(() {});

      if (_environmentalProbesSupported) {
        // Get environmental probes capabilities
        final capabilities = await _controller!
            .getEnvironmentalProbesCapabilities();
        print('Environmental probes capabilities: $capabilities');

        // Set up default environmental probes configuration
        const config = AREnvironmentalProbeConfig(
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

        await _controller!.setEnvironmentalProbeConfig(config);
        _probeConfig = config;

        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Environmental probes support check failed: $e';
      });
    }
  }

  Future<void> _addPointLight() async {
    if (_controller == null || !_lightingSupported) return;

    try {
      final now = DateTime.now();
      final light = ARLight(
        id: 'point_light_${_nodeCounter}',
        type: ARLightType.point,
        position: Vector3(
          (Random().nextDouble() - 0.5) * 4,
          2.0,
          (Random().nextDouble() - 0.5) * 4,
        ),
        rotation: const Quaternion(0, 0, 0, 1),
        direction: const Vector3(0, -1, 0),
        intensity: 500.0 + Random().nextDouble() * 1000.0,
        intensityUnit: LightIntensityUnit.lux,
        color: Vector3(
          Random().nextDouble(),
          Random().nextDouble(),
          Random().nextDouble(),
        ),
        range: 5.0 + Random().nextDouble() * 5.0,
        isEnabled: true,
        castShadows: true,
        shadowQuality: _shadowQuality,
        shadowFilterMode: ShadowFilterMode.soft,
        createdAt: now,
        lastModified: now,
      );

      final addedLight = await _controller!.addLight(light);
      _lights.add(addedLight);

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add point light: $e')));
    }
  }

  Future<void> _addSpotLight() async {
    if (_controller == null || !_lightingSupported) return;

    try {
      final now = DateTime.now();
      final light = ARLight(
        id: 'spot_light_${_nodeCounter}',
        type: ARLightType.spot,
        position: Vector3(
          (Random().nextDouble() - 0.5) * 4,
          3.0,
          (Random().nextDouble() - 0.5) * 4,
        ),
        rotation: const Quaternion(0, 0, 0, 1),
        direction: const Vector3(0, -1, 0),
        intensity: 800.0 + Random().nextDouble() * 1200.0,
        intensityUnit: LightIntensityUnit.lux,
        color: Vector3(
          Random().nextDouble(),
          Random().nextDouble(),
          Random().nextDouble(),
        ),
        range: 8.0 + Random().nextDouble() * 4.0,
        innerConeAngle: 15.0 + Random().nextDouble() * 15.0,
        outerConeAngle: 30.0 + Random().nextDouble() * 30.0,
        isEnabled: true,
        castShadows: true,
        shadowQuality: _shadowQuality,
        shadowFilterMode: ShadowFilterMode.soft,
        createdAt: now,
        lastModified: now,
      );

      final addedLight = await _controller!.addLight(light);
      _lights.add(addedLight);

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add spot light: $e')));
    }
  }

  Future<void> _toggleShadows() async {
    if (_controller == null || !_lightingSupported) return;

    try {
      _shadowsEnabled = !_shadowsEnabled;
      await _controller!.setShadowsEnabled(_shadowsEnabled);

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to toggle shadows: $e')));
    }
  }

  Future<void> _setShadowQuality(ShadowQuality quality) async {
    if (_controller == null || !_lightingSupported) return;

    try {
      _shadowQuality = quality;
      await _controller!.setShadowQuality(quality);

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set shadow quality: $e')),
      );
    }
  }

  Future<void> _clearLights() async {
    if (_controller == null || !_lightingSupported) return;

    try {
      await _controller!.clearLights();
      _lights.clear();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to clear lights: $e')));
    }
  }

  // Environmental Probes Methods
  Future<void> _addSphericalProbe() async {
    if (_controller == null || !_environmentalProbesSupported) return;

    try {
      final now = DateTime.now();
      final probe = AREnvironmentalProbe(
        id: 'spherical_probe_${_nodeCounter}',
        type: ARProbeType.spherical,
        position: Vector3(
          (Random().nextDouble() - 0.5) * 4,
          1.5,
          (Random().nextDouble() - 0.5) * 4,
        ),
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

      final addedProbe = await _controller!.addEnvironmentalProbe(probe);
      _environmentalProbes.add(addedProbe);
      _nodeCounter++;

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add spherical probe: $e')),
      );
    }
  }

  Future<void> _addBoxProbe() async {
    if (_controller == null || !_environmentalProbesSupported) return;

    try {
      final now = DateTime.now();
      final probe = AREnvironmentalProbe(
        id: 'box_probe_${_nodeCounter}',
        type: ARProbeType.box,
        position: Vector3(
          (Random().nextDouble() - 0.5) * 4,
          1.5,
          (Random().nextDouble() - 0.5) * 4,
        ),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(2, 2, 2),
        influenceRadius: 3.0,
        updateMode: ARProbeUpdateMode.automatic,
        quality: ARProbeQuality.high,
        isActive: true,
        captureReflections: true,
        captureLighting: true,
        textureResolution: 1024,
        isRealTime: true,
        updateFrequency: 0.5,
        confidence: 0.9,
        createdAt: now,
        lastModified: now,
      );

      final addedProbe = await _controller!.addEnvironmentalProbe(probe);
      _environmentalProbes.add(addedProbe);
      _nodeCounter++;

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add box probe: $e')));
    }
  }

  Future<void> _addPlanarProbe() async {
    if (_controller == null || !_environmentalProbesSupported) return;

    try {
      final now = DateTime.now();
      final probe = AREnvironmentalProbe(
        id: 'planar_probe_${_nodeCounter}',
        type: ARProbeType.planar,
        position: Vector3(
          (Random().nextDouble() - 0.5) * 4,
          1.0,
          (Random().nextDouble() - 0.5) * 4,
        ),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(4, 0.1, 4),
        influenceRadius: 2.0,
        updateMode: ARProbeUpdateMode.manual,
        quality: ARProbeQuality.low,
        isActive: true,
        captureReflections: true,
        captureLighting: false,
        textureResolution: 256,
        isRealTime: false,
        updateFrequency: 2.0,
        confidence: 0.7,
        createdAt: now,
        lastModified: now,
      );

      final addedProbe = await _controller!.addEnvironmentalProbe(probe);
      _environmentalProbes.add(addedProbe);
      _nodeCounter++;

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add planar probe: $e')));
    }
  }

  Future<void> _clearEnvironmentalProbes() async {
    if (_controller == null || !_environmentalProbesSupported) return;

    try {
      await _controller!.clearEnvironmentalProbes();
      _environmentalProbes.clear();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear environmental probes: $e')),
      );
    }
  }

  // Occlusion Methods
  Future<void> _checkOcclusionSupport() async {
    if (_controller == null) return;

    try {
      _occlusionSupported = await _controller!.isOcclusionSupported();

      if (!mounted) return;
      setState(() {});

      if (_occlusionSupported) {
        await _controller!.setOcclusionConfig(
          type: OcclusionType.depth,
          enableDepthOcclusion: true,
          enablePersonOcclusion: true,
          enablePlaneOcclusion: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check occlusion support: $e')),
      );
    }
  }

  Future<void> _toggleOcclusion() async {
    if (_controller == null) return;

    try {
      _occlusionEnabled = !_occlusionEnabled;
      await _controller!.setOcclusionEnabled(_occlusionEnabled);

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Occlusion ${_occlusionEnabled ? 'enabled' : 'disabled'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to toggle occlusion: $e')));
    }
  }

  Future<void> _createOcclusion() async {
    if (_controller == null) return;

    try {
      final occlusionId = await _controller!.createOcclusion(
        type: OcclusionType.depth,
        position: const Vector3(0, 0, -1),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(1, 1, 1),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created occlusion: $occlusionId')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create occlusion: $e')));
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
            Tab(icon: Icon(Icons.face), text: 'Face Tracking'),
            Tab(icon: Icon(Icons.cloud), text: 'Cloud Anchors'),
            Tab(icon: Icon(Icons.visibility_off), text: 'Occlusion'),
            Tab(icon: Icon(Icons.science), text: 'Physics'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Lighting'),
            Tab(icon: Icon(Icons.refresh), text: 'Probes'),
            Tab(icon: Icon(Icons.animation), text: 'Animations'),
            Tab(icon: Icon(Icons.dashboard), text: 'Demo'),
            Tab(icon: Icon(Icons.info), text: 'Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildARView(),
          _buildImageTrackingView(),
          _buildFaceTrackingView(),
          _buildCloudAnchorView(),
          _buildOcclusionView(),
          _buildPhysicsView(),
          _buildLightingView(),
          _buildEnvironmentalProbesView(),
          _buildAnimationView(),
          _buildDemoView(),
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
                if (_imageTrackingEnabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Image Tracking: ON',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_faceTrackingEnabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Face Tracking: ON',
                    style: const TextStyle(
                      color: Colors.pinkAccent,
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

  Widget _buildFaceTrackingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Face Tracking',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Face tracking toggle
          Card(
            child: ListTile(
              leading: Icon(
                _faceTrackingEnabled ? Icons.face : Icons.face_retouching_off,
              ),
              title: const Text('Face Tracking'),
              subtitle: Text(_faceTrackingEnabled ? 'Enabled' : 'Disabled'),
              trailing: Switch(
                value: _faceTrackingEnabled,
                onChanged: (_) => _toggleFaceTracking(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tracked faces section
          Text(
            'Tracked Faces (${_trackedFaces.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: _trackedFaces.length,
              itemBuilder: (context, index) {
                final face = _trackedFaces[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      face.isTracked
                          ? Icons.tag_faces
                          : Icons.face_retouching_off,
                      color: face.isTracked ? Colors.green : Colors.orange,
                    ),
                    title: Text('Face ID: ${face.id}'),
                    subtitle: Text(
                      'State: ${face.trackingState.name}\n'
                      'Confidence: ${(face.confidence * 100).toStringAsFixed(1)}%\n'
                      'Landmarks: ${face.landmarks.length}',
                    ),
                    trailing: Icon(
                      face.isReliable ? Icons.verified : Icons.warning,
                      color: face.isReliable ? Colors.green : Colors.orange,
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

  Widget _buildCloudAnchorView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cloud Anchors',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Cloud anchor support status
          Card(
            child: ListTile(
              leading: Icon(
                _cloudAnchorsSupported ? Icons.cloud_done : Icons.cloud_off,
                color: _cloudAnchorsSupported ? Colors.green : Colors.red,
              ),
              title: const Text('Cloud Anchor Support'),
              subtitle: Text(
                _cloudAnchorsSupported ? 'Supported' : 'Not Supported',
              ),
              trailing: ElevatedButton(
                onPressed: _checkCloudAnchorSupport,
                child: const Text('Check Support'),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cloud anchor actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Anchor Actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _cloudAnchorsSupported
                              ? _createCloudAnchor
                              : null,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Create Cloud Anchor'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _cloudAnchors.isNotEmpty
                              ? _shareCloudAnchor
                              : null,
                          icon: const Icon(Icons.share),
                          label: const Text('Share Session'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _joinCloudAnchorSession,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Session'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentSessionId != null
                              ? () async {
                                  try {
                                    await _controller
                                        ?.leaveCloudAnchorSession();
                                    if (!mounted) return;
                                    setState(() {
                                      _currentSessionId = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Left session'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to leave session: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Leave Session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cloud anchors list
          Text(
            'Cloud Anchors (${_cloudAnchors.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cloudAnchors.isEmpty
                ? const Center(child: Text('No cloud anchors yet'))
                : ListView.builder(
                    itemCount: _cloudAnchors.length,
                    itemBuilder: (context, index) {
                      final anchor = _cloudAnchors[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            anchor.isActive
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            color: anchor.isActive
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text('Cloud Anchor ${anchor.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('State: ${anchor.state.name}'),
                              Text(
                                'Confidence: ${(anchor.confidence * 100).toInt()}%',
                              ),
                              Text('Position: ${anchor.position}'),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: const Text('Delete'),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await _controller?.deleteCloudAnchor(
                                    anchor.id,
                                  );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Cloud anchor deleted'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Session info
          if (_currentSessionId != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Session',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Session ID: $_currentSessionId'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOcclusionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Occlusion', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          // Occlusion support status
          Card(
            child: ListTile(
              leading: Icon(
                _occlusionSupported ? Icons.visibility_off : Icons.visibility,
                color: _occlusionSupported ? Colors.green : Colors.red,
              ),
              title: const Text('Occlusion Support'),
              subtitle: Text(
                _occlusionSupported ? 'Supported' : 'Not Supported',
              ),
              trailing: ElevatedButton(
                onPressed: _checkOcclusionSupport,
                child: const Text('Check Support'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Occlusion controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Occlusion Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _occlusionSupported
                              ? _toggleOcclusion
                              : null,
                          icon: Icon(
                            _occlusionEnabled
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          label: Text(
                            _occlusionEnabled
                                ? 'Disable Occlusion'
                                : 'Enable Occlusion',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _occlusionSupported
                              ? _createOcclusion
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Occlusion'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Active occlusions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Occlusions (${_occlusions.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_occlusions.isEmpty)
                    const Text('No active occlusions')
                  else
                    ..._occlusions.map(
                      (occlusion) => ListTile(
                        leading: Icon(
                          occlusion.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: occlusion.isActive
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text('${occlusion.type.name} Occlusion'),
                        subtitle: Text(
                          'ID: ${occlusion.id}\n'
                          'Confidence: ${(occlusion.confidence * 100).toStringAsFixed(1)}%\n'
                          'Position: (${occlusion.position.x.toStringAsFixed(2)}, ${occlusion.position.y.toStringAsFixed(2)}, ${occlusion.position.z.toStringAsFixed(2)})',
                        ),
                        trailing: Icon(
                          occlusion.isReliable
                              ? Icons.check_circle
                              : Icons.warning,
                          color: occlusion.isReliable
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Occlusion info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Occlusion Types',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Depth: Uses depth maps for realistic occlusion',
                  ),
                  const Text(
                    '• Person: Uses person segmentation for human occlusion',
                  ),
                  const Text(
                    '• Plane: Uses detected planes for surface occlusion',
                  ),
                  const Text(
                    '• None: No occlusion - virtual objects appear in front',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Physics Simulation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Physics support status
          Card(
            child: ListTile(
              leading: Icon(
                _physicsSupported ? Icons.science : Icons.science_outlined,
                color: _physicsSupported ? Colors.green : Colors.red,
              ),
              title: const Text('Physics Support'),
              subtitle: Text(_physicsSupported ? 'Supported' : 'Not Supported'),
              trailing: ElevatedButton(
                onPressed: _checkPhysicsSupport,
                child: const Text('Check Support'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Physics controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physics Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _physicsSupported ? _togglePhysics : null,
                          icon: Icon(
                            _physicsEnabled ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            _physicsEnabled
                                ? 'Pause Physics'
                                : 'Resume Physics',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _physicsSupported
                              ? _createPhysicsBody
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Body'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _physicsSupported && _physicsBodies.isNotEmpty
                              ? _applyForce
                              : null,
                          icon: const Icon(Icons.speed),
                          label: const Text('Apply Force'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Active physics bodies
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physics Bodies (${_physicsBodies.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_physicsBodies.isEmpty)
                    const Text('No physics bodies')
                  else
                    ..._physicsBodies.map(
                      (body) => ListTile(
                        leading: Icon(
                          body.isActive
                              ? Icons.science
                              : Icons.science_outlined,
                          color: body.isActive ? Colors.green : Colors.grey,
                        ),
                        title: Text('${body.type.name} Body'),
                        subtitle: Text(
                          'ID: ${body.id}\n'
                          'Mass: ${body.mass.toStringAsFixed(2)}\n'
                          'Position: (${body.position.x.toStringAsFixed(2)}, ${body.position.y.toStringAsFixed(2)}, ${body.position.z.toStringAsFixed(2)})',
                        ),
                        trailing: Text(
                          'Velocity: ${sqrt(body.velocity.x * body.velocity.x + body.velocity.y * body.velocity.y + body.velocity.z * body.velocity.z).toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Physics constraints
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physics Constraints (${_physicsConstraints.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_physicsConstraints.isEmpty)
                    const Text('No constraints')
                  else
                    ..._physicsConstraints.map(
                      (c) => ListTile(
                        leading: const Icon(Icons.link),
                        title: Text('${c.type.name} Constraint'),
                        subtitle: Text('ID: ${c.id}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-time Lighting',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Lighting support status
          Card(
            child: ListTile(
              leading: Icon(
                _lightingSupported ? Icons.lightbulb : Icons.lightbulb_outline,
                color: _lightingSupported ? Colors.green : Colors.red,
              ),
              title: const Text('Lighting Support'),
              subtitle: Text(
                _lightingSupported ? 'Supported' : 'Not Supported',
              ),
              trailing: ElevatedButton(
                onPressed: _checkLightingSupport,
                child: const Text('Check Support'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Lighting controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lighting Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _lightingSupported ? _addPointLight : null,
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Add Point Light'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _lightingSupported ? _addSpotLight : null,
                        icon: const Icon(Icons.flashlight_on),
                        label: const Text('Add Spot Light'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _lightingSupported ? _toggleShadows : null,
                        icon: Icon(
                          _shadowsEnabled
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        label: Text(
                          _shadowsEnabled
                              ? 'Disable Shadows'
                              : 'Enable Shadows',
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _lightingSupported ? _clearLights : null,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear All Lights'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Shadow quality controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shadow Quality',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<ShadowQuality>(
                          value: _shadowQuality,
                          isExpanded: true,
                          onChanged: _lightingSupported
                              ? (value) {
                                  if (value != null) {
                                    _setShadowQuality(value);
                                  }
                                }
                              : null,
                          items: ShadowQuality.values.map((quality) {
                            return DropdownMenuItem(
                              value: quality,
                              child: Text(quality.name.toUpperCase()),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Current lights
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Lights (${_lights.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_lights.isEmpty)
                    const Text('No lights added yet')
                  else
                    ..._lights.map(
                      (light) => ListTile(
                        leading: Icon(
                          light.type == ARLightType.directional
                              ? Icons.wb_sunny
                              : light.type == ARLightType.point
                              ? Icons.lightbulb
                              : light.type == ARLightType.spot
                              ? Icons.flashlight_on
                              : light.type == ARLightType.ambient
                              ? Icons.brightness_6
                              : Icons.lightbulb_outline,
                          color: light.isEnabled ? Colors.orange : Colors.grey,
                        ),
                        title: Text(light.id),
                        subtitle: Text(
                          '${light.type.name.toUpperCase()} - '
                          'Intensity: ${light.intensity.toStringAsFixed(0)} '
                          '${light.intensityUnit.name} - '
                          'Shadows: ${light.castShadows ? "On" : "Off"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  try {
                                    await _controller!.setLightEnabled(
                                      lightId: light.id,
                                      enabled: !light.isEnabled,
                                    );
                                    setState(() {});
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to toggle light: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: Icon(
                                light.isEnabled
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  try {
                                    await _controller!.removeLight(light.id);
                                    _lights.removeWhere(
                                      (l) => l.id == light.id,
                                    );
                                    setState(() {});
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to remove light: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Lighting configuration
          if (_lightingConfig != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lighting Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.lightbulb),
                      title: const Text('Global Illumination'),
                      subtitle: Text(
                        _lightingConfig!.enableGlobalIllumination
                            ? 'Enabled'
                            : 'Disabled',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.visibility),
                      title: const Text('Shadows'),
                      subtitle: Text(
                        _lightingConfig!.enableShadows ? 'Enabled' : 'Disabled',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('Shadow Quality'),
                      subtitle: Text(
                        _lightingConfig!.globalShadowQuality.name.toUpperCase(),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: const Text('Ambient Intensity'),
                      subtitle: Text(
                        _lightingConfig!.ambientIntensity.toStringAsFixed(2),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.straighten),
                      title: const Text('Shadow Distance'),
                      subtitle: Text(
                        '${_lightingConfig!.shadowDistance.toStringAsFixed(1)}m',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalProbesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental Probes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Environmental probes support status
          Card(
            child: ListTile(
              leading: Icon(
                _environmentalProbesSupported
                    ? Icons.refresh
                    : Icons.refresh_outlined,
                color: _environmentalProbesSupported
                    ? Colors.green
                    : Colors.red,
              ),
              title: const Text('Environmental Probes Support'),
              subtitle: Text(
                _environmentalProbesSupported ? 'Supported' : 'Not Supported',
              ),
              trailing: ElevatedButton(
                onPressed: _checkEnvironmentalProbesSupport,
                child: const Text('Check Support'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Environmental probes controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environmental Probes Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _environmentalProbesSupported
                            ? _addSphericalProbe
                            : null,
                        icon: const Icon(Icons.circle),
                        label: const Text('Add Spherical Probe'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _environmentalProbesSupported
                            ? _addBoxProbe
                            : null,
                        icon: const Icon(Icons.crop_square),
                        label: const Text('Add Box Probe'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _environmentalProbesSupported
                            ? _addPlanarProbe
                            : null,
                        icon: const Icon(Icons.rectangle),
                        label: const Text('Add Planar Probe'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _environmentalProbesSupported
                            ? _clearEnvironmentalProbes
                            : null,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear All Probes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Current environmental probes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Environmental Probes (${_environmentalProbes.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_environmentalProbes.isEmpty)
                    const Text('No environmental probes added yet')
                  else
                    ..._environmentalProbes.map(
                      (probe) => ListTile(
                        leading: Icon(
                          probe.type == ARProbeType.spherical
                              ? Icons.circle
                              : probe.type == ARProbeType.box
                              ? Icons.crop_square
                              : probe.type == ARProbeType.planar
                              ? Icons.rectangle
                              : Icons.refresh,
                          color: probe.isActive ? Colors.blue : Colors.grey,
                        ),
                        title: Text(probe.id),
                        subtitle: Text(
                          '${probe.type.name.toUpperCase()} - '
                          'Quality: ${probe.quality.name.toUpperCase()} - '
                          'Radius: ${probe.influenceRadius.toStringAsFixed(1)}m - '
                          'Active: ${probe.isActive ? "Yes" : "No"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  try {
                                    await _controller!
                                        .setEnvironmentalProbeEnabled(
                                          probeId: probe.id,
                                          enabled: !probe.isActive,
                                        );
                                    setState(() {});
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to toggle probe: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: Icon(
                                probe.isActive
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  try {
                                    await _controller!.removeEnvironmentalProbe(
                                      probe.id,
                                    );
                                    _environmentalProbes.removeWhere(
                                      (p) => p.id == probe.id,
                                    );
                                    setState(() {});
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to remove probe: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Environmental probes configuration
          if (_probeConfig != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Environmental Probes Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Probes Enabled'),
                      subtitle: Text(
                        _probeConfig!.enableProbes ? 'Enabled' : 'Disabled',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.high_quality),
                      title: const Text('Default Quality'),
                      subtitle: Text(
                        _probeConfig!.defaultQuality.name.toUpperCase(),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Default Update Mode'),
                      subtitle: Text(
                        _probeConfig!.defaultUpdateMode.name.toUpperCase(),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.texture),
                      title: const Text('Texture Resolution'),
                      subtitle: Text(
                        '${_probeConfig!.defaultTextureResolution}x${_probeConfig!.defaultTextureResolution}',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.group),
                      title: const Text('Max Active Probes'),
                      subtitle: Text('${_probeConfig!.maxActiveProbes}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.straighten),
                      title: const Text('Default Influence Radius'),
                      subtitle: Text(
                        '${_probeConfig!.defaultInfluenceRadius.toStringAsFixed(1)}m',
                      ),
                    ),
                  ],
                ),
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

  Widget _buildDemoView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Demonstrations',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Quick setup section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Setup',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addSampleImageTargets,
                          icon: const Icon(Icons.image_search),
                          label: const Text('Add Image Targets'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleImageTracking,
                          icon: Icon(
                            _imageTrackingEnabled
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          label: Text(
                            _imageTrackingEnabled
                                ? 'Disable Image Tracking'
                                : 'Enable Image Tracking',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleFaceTracking,
                          icon: Icon(
                            _faceTrackingEnabled
                                ? Icons.face
                                : Icons.face_retouching_off,
                          ),
                          label: Text(
                            _faceTrackingEnabled
                                ? 'Disable Face Tracking'
                                : 'Enable Face Tracking',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetSession,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Feature demonstrations
          Text(
            'Feature Demonstrations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              children: [
                _buildDemoCard(
                  'Basic AR Objects',
                  'Place spheres, cubes, and cylinders in the AR scene',
                  Icons.crop_square,
                  () => _addObjectAtScreenCenter(),
                ),
                _buildDemoCard(
                  '3D Models',
                  'Load and display custom 3D models from URLs',
                  Icons.model_training,
                  () => _addModelFromUrl(),
                ),
                _buildDemoCard(
                  'Image Tracking',
                  'Track specific images and anchor content to them',
                  Icons.image_search,
                  () => _toggleImageTracking(),
                ),
                _buildDemoCard(
                  'Face Tracking',
                  'Detect and track human faces with landmarks',
                  Icons.face,
                  () => _toggleFaceTracking(),
                ),
                _buildDemoCard(
                  'Cloud Anchors',
                  'Create persistent AR experiences that can be shared',
                  Icons.cloud,
                  () => _createCloudAnchor(),
                ),
                _buildDemoCard(
                  'Animations',
                  'Play, blend, and transition between animations',
                  Icons.animation,
                  () => _playSampleAnimation(),
                ),
                _buildDemoCard(
                  'Hit Testing',
                  'Detect surfaces and place objects precisely',
                  Icons.touch_app,
                  () => _performHitTest(),
                ),
                _buildDemoCard(
                  'Anchors',
                  'Create persistent AR anchors in the scene',
                  Icons.anchor,
                  () => _addAnchor(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatusView() {
    return SingleChildScrollView(
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
                  _buildStatRow(
                    'Tracked Faces',
                    _trackedFaces.length.toString(),
                  ),
                  _buildStatRow('Objects Placed', _nodeCounter.toString()),
                  _buildStatRow(
                    'Image Tracking',
                    _imageTrackingEnabled ? 'Enabled' : 'Disabled',
                  ),
                  _buildStatRow(
                    'Face Tracking',
                    _faceTrackingEnabled ? 'Enabled' : 'Disabled',
                  ),
                  _buildStatRow(
                    'Cloud Anchors',
                    '${_cloudAnchors.length} anchors, ${_cloudAnchorsSupported ? 'Supported' : 'Not Supported'}',
                  ),
                  _buildStatRow(
                    'Occlusions',
                    '${_occlusions.length} active, ${_occlusionSupported ? 'Supported' : 'Not Supported'}',
                  ),
                  _buildStatRow(
                    'Physics',
                    '${_physicsBodies.length} bodies, ${_physicsSupported ? 'Supported' : 'Not Supported'}',
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
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addModelFromUrl() async {
    if (_controller == null) return;

    try {
      final nodeId = 'model_${DateTime.now().millisecondsSinceEpoch}';
      final modelNode = ARNode.fromModel(
        id: nodeId,
        modelPath: 'https://example.com/models/character.glb',
        position: const Vector3(0, 0, -1),
        rotation: const Quaternion(0, 0, 0, 1),
        scale: const Vector3(0.1, 0.1, 0.1),
      );

      await _controller!.addNode(modelNode);

      if (!mounted) return;
      setState(() {
        _nodeCounter++;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('3D model added to scene')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add model: $e')));
    }
  }

  Future<void> _playSampleAnimation() async {
    if (_controller == null) return;

    try {
      // Try to play animation on the most recent model
      if (_nodeCounter > 0) {
        await _controller!.playAnimation(
          nodeId: 'model_${DateTime.now().millisecondsSinceEpoch}',
          animationId: 'idle',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Animation started')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a model first to play animations')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to play animation: $e')));
    }
  }

  Future<void> _performHitTest() async {
    if (_controller == null) return;

    try {
      final results = await _controller!.hitTest(0.5, 0.5);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hit test found ${results.length} surfaces')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hit test failed: $e')));
    }
  }

  @override
  void dispose() {
    _planesSubscription?.cancel();
    _imageTargetsSubscription?.cancel();
    _trackedImagesSubscription?.cancel();
    _facesSubscription?.cancel();
    _cloudAnchorsSubscription?.cancel();
    _cloudAnchorStatusSubscription?.cancel();
    _occlusionsSubscription?.cancel();
    _occlusionStatusSubscription?.cancel();
    _physicsBodiesSubscription?.cancel();
    _physicsConstraintsSubscription?.cancel();
    _physicsStatusSubscription?.cancel();
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
}
