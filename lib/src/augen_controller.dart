import 'dart:async';
import 'package:flutter/services.dart';
import 'models/ar_anchor.dart';
import 'models/ar_node.dart';
import 'models/ar_plane.dart';
import 'models/ar_hit_result.dart';
import 'models/ar_session_config.dart';
import 'models/vector3.dart';

/// Controller for managing AR session
class AugenController {
  final MethodChannel _channel;
  final int viewId;

  final StreamController<List<ARPlane>> _planesController =
      StreamController<List<ARPlane>>.broadcast();
  final StreamController<List<ARAnchor>> _anchorsController =
      StreamController<List<ARAnchor>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  bool _isDisposed = false;

  AugenController(this.viewId) : _channel = MethodChannel('augen_$viewId') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Stream of detected planes
  Stream<List<ARPlane>> get planesStream => _planesController.stream;

  /// Stream of AR anchors
  Stream<List<ARAnchor>> get anchorsStream => _anchorsController.stream;

  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;

  /// Initialize AR session with configuration
  Future<void> initialize(ARSessionConfig config) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('initialize', config.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize AR: ${e.message}');
      rethrow;
    }
  }

  /// Check if AR is supported on this device
  Future<bool> isARSupported() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<bool>('isARSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to check AR support: ${e.message}');
      return false;
    }
  }

  /// Add a node to the AR scene
  Future<void> addNode(ARNode node) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('addNode', node.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to add node: ${e.message}');
      rethrow;
    }
  }

  /// Remove a node from the AR scene
  Future<void> removeNode(String nodeId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeNode', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove node: ${e.message}');
      rethrow;
    }
  }

  /// Update an existing node
  Future<void> updateNode(ARNode node) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('updateNode', node.toMap());
    } on PlatformException catch (e) {
      _errorController.add('Failed to update node: ${e.message}');
      rethrow;
    }
  }

  /// Perform hit test at screen coordinates
  Future<List<ARHitResult>> hitTest(double x, double y) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<List>('hitTest', {
        'x': x,
        'y': y,
      });
      return result?.map((e) => ARHitResult.fromMap(e as Map)).toList() ?? [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to perform hit test: ${e.message}');
      return [];
    }
  }

  /// Add an anchor at the specified position
  Future<ARAnchor?> addAnchor(Vector3 position) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      final result = await _channel.invokeMethod<Map>(
        'addAnchor',
        position.toMap(),
      );
      return result != null ? ARAnchor.fromMap(result) : null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to add anchor: ${e.message}');
      return null;
    }
  }

  /// Remove an anchor
  Future<void> removeAnchor(String anchorId) async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('removeAnchor', {'anchorId': anchorId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to remove anchor: ${e.message}');
      rethrow;
    }
  }

  /// Pause AR session
  Future<void> pause() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException catch (e) {
      _errorController.add('Failed to pause AR: ${e.message}');
      rethrow;
    }
  }

  /// Resume AR session
  Future<void> resume() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('resume');
    } on PlatformException catch (e) {
      _errorController.add('Failed to resume AR: ${e.message}');
      rethrow;
    }
  }

  /// Reset AR session
  Future<void> reset() async {
    if (_isDisposed) throw StateError('Controller is disposed');
    try {
      await _channel.invokeMethod('reset');
    } on PlatformException catch (e) {
      _errorController.add('Failed to reset AR: ${e.message}');
      rethrow;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_isDisposed) return;

    switch (call.method) {
      case 'onPlanesUpdated':
        final planesData = call.arguments as List;
        final planes = planesData
            .map((e) => ARPlane.fromMap(e as Map))
            .toList();
        _planesController.add(planes);
        break;
      case 'onAnchorsUpdated':
        final anchorsData = call.arguments as List;
        final anchors = anchorsData
            .map((e) => ARAnchor.fromMap(e as Map))
            .toList();
        _anchorsController.add(anchors);
        break;
      case 'onError':
        final error = call.arguments as String;
        _errorController.add(error);
        break;
    }
  }

  /// Dispose the controller
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _planesController.close();
    _anchorsController.close();
    _errorController.close();
    _channel.setMethodCallHandler(null);
  }
}
