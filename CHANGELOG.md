# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
