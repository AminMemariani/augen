# Changelog

All notable changes to the Augen Flutter AR plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-13

### Added
- Initial release of Augen Flutter AR plugin
- Cross-platform AR support (Android ARCore & iOS RealityKit)
- Pure Dart API for AR development
- AR session configuration and management
- Plane detection (horizontal and vertical)
- 3D object placement (sphere, cube, cylinder)
- Hit testing for surface detection
- Anchor management
- Real-time position tracking
- Light estimation support
- Depth data support (where available)
- Auto-focus configuration
- Stream-based event system for planes, anchors, and errors
- Comprehensive example app
- Full documentation and API reference

### Platform Support
- Android: API 24+ with ARCore
- iOS: iOS 13.0+ with RealityKit and ARKit

### Known Limitations
- Custom 3D model loading not yet supported
- No image or face tracking in this version
- Cloud anchors not implemented
- Physics simulation not available

## [Unreleased]

### Planned Features
- Custom 3D model loading (GLTF, OBJ formats)
- Image tracking and recognition
- Face tracking capabilities
- Cloud anchor support for persistent AR
- Occlusion for realistic object rendering
- Physics simulation for AR objects
- Multi-user AR experiences
- Video texture support
- Environment probe support
- Mesh visualization
- Raycast improvements

---

For more details about each release, visit the [GitHub releases page](https://github.com/yourusername/augen/releases).
