# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
