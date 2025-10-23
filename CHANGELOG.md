# Changelog

All notable changes to this project will be documented in this file.

## [0.8.0] - 2025-01-14

### Added
- 👁️ **Occlusion for Realistic Rendering** - Complete occlusion system
  - Depth-based occlusion using depth maps for realistic object hiding
  - Person occlusion using person segmentation for human-aware AR
  - Plane occlusion using detected planes for surface-aware AR
  - Real-time occlusion status monitoring and management
  - Cross-platform occlusion support (ARCore/ARKit)
  - Occlusion configuration and capabilities detection
  - Comprehensive occlusion data models and streams

### New Features
- **AROcclusion Model**: Complete occlusion data structure with position, rotation, scale, confidence, and metadata
- **OcclusionType Enum**: Support for depth, person, plane, and none occlusion types
- **OcclusionStatus Model**: Real-time status updates for occlusion operations
- **Occlusion Methods**: Full CRUD operations for occlusion management
- **Occlusion Streams**: Real-time updates for active occlusions and status changes
- **Occlusion Configuration**: Flexible setup for different occlusion types
- **Occlusion Capabilities**: Device capability detection and reporting

### Enhanced Examples
- **Occlusion Tab**: Complete occlusion demonstration in example app
- **Occlusion Controls**: Enable/disable occlusion with visual feedback
- **Occlusion Management**: Create, monitor, and manage active occlusions
- **Occlusion Statistics**: Real-time occlusion count and status display
- **Occlusion Integration Tests**: Comprehensive test coverage for occlusion features

### Documentation Updates
- **Occlusion Guide**: Complete documentation with examples and best practices
- **Occlusion API Reference**: Detailed method and model documentation
- **Occlusion Examples**: Code samples for all occlusion features
- **Occlusion Best Practices**: Performance optimization and error handling guides

### Testing
- **50 New Unit Tests**: Comprehensive test coverage for all occlusion features
- **Occlusion Integration Tests**: Full integration test suite for occlusion functionality
- **280 Total Tests**: All tests passing with 100% coverage
- **Occlusion Model Tests**: Complete serialization, deserialization, and equality testing
- **Occlusion Controller Tests**: Full method and stream testing

### Technical Improvements
- **Occlusion Stream Management**: Proper subscription handling and cleanup
- **Occlusion Error Handling**: Comprehensive error management and user feedback
- **Occlusion Type Safety**: Full type safety for all occlusion operations
- **Occlusion Performance**: Optimized occlusion operations and memory management
- **Occlusion Documentation**: Complete inline documentation and examples

## [0.7.1] - 2025-01-14

### Fixed
- Fixed Dart formatting issues in core files
- Improved code formatting consistency across the package
- Updated example app formatting
- Enhanced test file formatting

### Technical Improvements
- Applied `dart format` to all source files
- Maintained 255 passing tests after formatting
- Improved code readability and maintainability
- Ensured consistent code style across the entire codebase

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2025-01-14

### Added
- ☁️ **Cloud Anchors for Persistent AR** - Complete cloud anchor system
  - Create persistent AR experiences that survive app restarts
  - Share AR experiences between multiple users
  - Cross-platform cloud anchor support (ARCore/ARKit)
  - Real-time cloud anchor status monitoring
  - Session-based cloud anchor sharing
  - Automatic cloud anchor resolution and tracking

#### New Cloud Anchor Models
- `ARCloudAnchor` - Represents cloud anchors with position, rotation, scale, and state
- `CloudAnchorState` - Enum for cloud anchor states (creating, created, resolving, resolved, failed, expired)
- `CloudAnchorStatus` - Real-time status updates for cloud anchor operations

#### New Cloud Anchor Methods
- `createCloudAnchor(String localAnchorId)` - Convert local anchor to cloud anchor
- `resolveCloudAnchor(String cloudAnchorId)` - Resolve cloud anchor by ID
- `getCloudAnchors()` - Get all cloud anchors in current session
- `getCloudAnchor(String cloudAnchorId)` - Get specific cloud anchor by ID
- `deleteCloudAnchor(String cloudAnchorId)` - Delete cloud anchor
- `isCloudAnchorsSupported()` - Check if cloud anchors are supported
- `setCloudAnchorConfig()` - Configure cloud anchor settings
- `shareCloudAnchor(String cloudAnchorId)` - Share cloud anchor session
- `joinCloudAnchorSession(String sessionId)` - Join shared session
- `leaveCloudAnchorSession()` - Leave current session

#### New Cloud Anchor Streams
- `cloudAnchorsStream` - Stream of cloud anchor updates
- `cloudAnchorStatusStream` - Stream of cloud anchor status updates

#### Enhanced Example App
- Added Cloud Anchors tab with full cloud anchor management
- Cloud anchor support detection and configuration
- Create, share, and join cloud anchor sessions
- Real-time cloud anchor status monitoring
- Cloud anchor list with state information
- Session management UI

#### Updated Documentation
- Added comprehensive Cloud Anchors section to Documentation.md
- Complete cloud anchor setup and usage guide
- Best practices for cloud anchor implementation
- Example code for all cloud anchor features
- Updated README.md with cloud anchor features and examples

#### Testing
- Added 13 new cloud anchor unit tests
- Comprehensive testing of all cloud anchor models and methods
- Updated integration tests to include cloud anchor workflows
- Total test count: 243 passing tests

### Technical Details
- Cloud anchors enable persistent AR experiences across app sessions
- Multi-user AR support through session sharing
- Real-time status monitoring for cloud anchor operations
- Cross-platform compatibility with ARCore and ARKit
- Automatic cloud anchor resolution and tracking
- Session-based sharing for collaborative AR experiences

## [0.6.0] - 2025-01-14

### Added
- 👤 **Face Tracking and Recognition** - Complete face tracking system
  - Real-time detection and tracking of human faces
  - Multiple simultaneous face tracking support
  - High accuracy position, rotation, and scale tracking
  - Confidence scoring for tracking reliability
  - Automatic content anchoring to tracked faces
  - Cross-platform support (ARCore/ARKit)

#### New Face Tracking Models
- `ARFace` - Represents tracked faces with position, rotation, scale, and landmarks
- `FaceLandmark` - Represents specific facial feature points (eyes, nose, mouth, etc.)
- `FaceTrackingState` - Enum for face tracking states (tracked, notTracked, paused, failed)

#### New Face Tracking Methods
- `setFaceTrackingEnabled(bool enabled)` - Enable/disable face tracking
- `isFaceTrackingEnabled()` - Check if face tracking is enabled
- `getTrackedFaces()` - Get all currently tracked faces
- `addNodeToTrackedFace(String nodeId, String faceId, ARNode node)` - Add content to tracked face
- `removeNodeFromTrackedFace(String nodeId, String faceId)` - Remove content from tracked face
- `getFaceLandmarks(String faceId)` - Get facial landmarks for a specific face
- `setFaceTrackingConfig(...)` - Configure face tracking parameters

#### New Face Tracking Streams
- `facesStream` - Stream of tracked faces with real-time updates

#### Enhanced Example App
- Added comprehensive face tracking demonstration
- Interactive face tracking controls
- Real-time face tracking statistics
- Face landmark visualization
- Content anchoring to faces

#### Enhanced Documentation
- Complete face tracking guide in Documentation.md
- Face tracking API reference
- Face tracking best practices
- Face tracking examples and use cases

### Enhanced
- **Example App**: Added face tracking tab with full feature demonstration
- **Integration Tests**: Added comprehensive face tracking integration tests
- **Documentation**: Updated with face tracking features and examples
- **Test Coverage**: Added 14 new face tracking tests (230 total tests)

### Technical Details
- Face tracking uses ARCore's face detection on Android
- Face tracking uses ARKit's face tracking on iOS
- Supports multiple faces simultaneously
- Provides detailed facial landmarks (eyes, nose, mouth, ears, etc.)
- Real-time confidence scoring for tracking reliability
- Automatic content positioning relative to face features

## [0.5.0] - 2025-01-14

### Added
- 🖼️ **Image Tracking and Recognition** - Complete image tracking system
  - Real-time detection and tracking of specific images
  - Multiple simultaneous image target support
  - High accuracy position and orientation tracking
  - Confidence scoring for tracking reliability
  - Automatic content anchoring to tracked images
  - Cross-platform support (ARCore/ARKit)

#### New Image Tracking Models
- `ARImageTarget` - Represents image targets for tracking
- `ARTrackedImage` - Represents currently tracked images
- `ImageTargetSize` - Physical dimensions of image targets
- `ImageTrackingState` - Tracking state enumeration

#### New Controller Methods
- `addImageTarget()` - Register image targets for tracking
- `removeImageTarget()` - Remove image targets
- `getImageTargets()` - Get all registered targets
- `getTrackedImages()` - Get currently tracked images
- `setImageTrackingEnabled()` - Enable/disable image tracking
- `isImageTrackingEnabled()` - Check tracking status
- `addNodeToTrackedImage()` - Anchor content to tracked images
- `removeNodeFromTrackedImage()` - Remove anchored content

#### New Streams
- `imageTargetsStream` - Real-time image target updates
- `trackedImagesStream` - Real-time tracked image updates

#### Testing
- 21 new image tracking model tests
- 10 new controller method tests
- 2 new stream tests
- Total test count: 208 tests (all passing)

#### Documentation
- Complete Image Tracking section in Documentation.md
- API reference for all new methods and models
- Best practices and performance optimization guide
- Real-world examples and usage patterns
- Updated README with image tracking features

### Changed
- Updated test count from 177 to 208 tests
- Enhanced documentation with comprehensive image tracking guide

## [0.4.0] - 2025-10-14

### Added
- 🚀 **Advanced Animation Blending and Transitions** - Professional-grade animation system
  - Animation blending with weighted combinations
  - Smooth crossfade transitions with customizable curves
  - Animation state machines with conditional transitions
  - Blend trees (1D, 2D, conditional, selector nodes)
  - Layered and additive animations
  - Bone masking for selective animation
  - Real-time transition and state machine status updates

#### New Animation Models
- `AnimationBlend` and `AnimationBlendSet` - Complex animation blending
- `AnimationTransition` and `CrossfadeTransition` - Smooth transitions
- `AnimationStateMachine` and `AnimationState` - State-based animation workflow
- `AnimationBlendTree` and various blend tree nodes - Parameter-driven animation
- `TransitionStatus` and `StateMachineStatus` - Real-time status tracking

#### New Controller Methods
- **Blending**: `playBlendSet()`, `updateBlendWeights()`, `blendAnimations()`
- **Transitions**: `startCrossfadeTransition()`, `crossfadeToAnimation()`
- **State Machines**: `startStateMachine()`, `updateStateMachineParameters()`
- **Blend Trees**: `startBlendTree()`, `updateBlendTreeParameters()`
- **Layered**: `playAdditiveAnimation()`, `setAnimationLayerWeight()`, `getBoneHierarchy()`

#### New Streams
- `transitionStatusStream` - Monitor transition progress
- `stateMachineStatusStream` - Monitor state machine updates

#### Comprehensive Testing
- 90 new tests for animation blending features
- Total test count increased from 87 to 177 tests
- 100% test coverage maintained

#### Documentation
- Complete `Documentation.md` consolidating all guides (3,500+ lines)
- Advanced animation blending guide with real-world examples
- Performance tips and best practices
- Troubleshooting guide

### Changed
- `AugenController` extended with 18 new animation methods
- Enhanced `ARNode` support for complex animation workflows
- Updated README.md with v0.4.0 and consolidated documentation links
- Fixed `BuildContext` across async gaps in example app (8 fixes)

### Merged Documentation
- All individual documentation files merged into single `Documentation.md`
- Improved navigation with comprehensive table of contents
- Consolidated examples and best practices

### Platform Support
- Animation blending API ready for native implementation
- Data structures optimized for ARCore Filament and RealityKit

## [0.3.1] - 2025-10-14

### Changed
- Updated README.md dependency version to ^0.3.0
- Added comprehensive community feedback section in README
- Added bug reporting, testing feedback, and feature request links
- Improved call-to-action for community involvement

## [0.3.0] - 2025-10-14

### Added
- 🎬 **Model Animation and Skeletal Animation Support**
  - Full animation playback control
  - Skeletal (bone-based) animations
  - Morph target animations
  - Multiple animations per model
- New animation control methods:
  - `playAnimation()` - Play animations with speed and loop mode control
  - `pauseAnimation()` - Pause animation playback
  - `stopAnimation()` - Stop and reset animation
  - `resumeAnimation()` - Resume paused animation
  - `seekAnimation()` - Jump to specific time in animation
  - `getAvailableAnimations()` - Query available animations
  - `setAnimationSpeed()` - Change playback speed dynamically
- New `ARAnimation` model class with full configuration
- New `AnimationStatus` class for animation state tracking
- New enums: `AnimationState`, `AnimationLoopMode`
- `animationStatusStream` for real-time animation updates
- Comprehensive animation tests (25 new tests)
- `ANIMATIONS_GUIDE.md` - Complete animation documentation

### Changed
- `ARNode` now supports `animations` parameter
- `ARNode.fromModel()` accepts animations list
- Updated Android implementation with animation methods
- Updated iOS implementation with RealityKit animation support
- Test count increased from 62 to 87 tests
- Enhanced README with animation examples

### Platform Support
- **Android**: Skeletal animations via Filament Animator
- **iOS**: Native animation support via RealityKit AnimationResource

## [0.2.1] - 2025-10-14

### Fixed
- Formatted all Dart files to match Dart formatter standards
- Fixed formatting issues in `augen_method_channel.dart`
- Fixed formatting issues in `ar_node.dart`

## [0.2.0] - 2025-10-13

### Added
- ✨ **Custom 3D model loading support**
  - Load models from Flutter assets
  - Load models from URLs
  - Support for GLTF, GLB, OBJ, and USDZ formats
  - Auto-detection of model format from file extension
  - `ARNode.fromModel()` factory constructor
  - `addModelFromAsset()` and `addModelFromUrl()` helper methods
- New `ModelFormat` enum (gltf, glb, obj, usdz)
- Comprehensive test coverage for model loading (10 new tests)
- `CUSTOM_MODELS_GUIDE.md` comprehensive documentation
- Enhanced README with model loading examples

### Changed
- `ARNode` now supports `modelPath` and `modelFormat` parameters
- Updated Android (Kotlin) implementation for custom 3D models
- Updated iOS (Swift) implementation for custom 3D models
- Test count increased from 52 to 62 tests
- Version bumped to 0.1.1
- Updated all documentation with model loading information

### Fixed
- Unused variable lint in example app
- Import issues in controller tests

## [0.1.0] - 2025-10-13

### Added
- Initial release of Augen AR plugin
- AR session management (initialize, pause, resume, reset)
- Plane detection (horizontal and vertical)
- 3D object rendering (sphere, cube, cylinder)
- AR anchors management
- Hit testing for surface detection
- Light estimation
- Depth data support
- Auto-focus capability
- Cross-platform support (Android ARCore and iOS RealityKit)
- Comprehensive documentation and examples
- Full test coverage (52 tests)

### Platform Support
- Android: ARCore (API level 24+)
- iOS: RealityKit and ARKit (iOS 13.0+)

---

For more details about each release, visit the [GitHub releases page](https://github.com/AminMemariani/augen/releases).
