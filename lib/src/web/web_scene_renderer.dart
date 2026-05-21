import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'js_interop/augen_web_ar_interop.dart';

/// Wraps a Three.js-based renderer for web AR.
class WebSceneRenderer {
  RendererJS? _renderer;
  bool _isInitialized = false;

  // W7: Pre-allocated buffer reused per updateMarkerTransform call to
  // avoid allocating a new JS Array of 16 numbers every frame.
  final Float64List _transformBuffer = Float64List(16);

  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    required web.HTMLElement container,
    int? width,
    int? height,
  }) async {
    try {
      final options = <String, dynamic>{
        'width': width ?? container.clientWidth,
        'height': height ?? container.clientHeight,
        'alpha': true,
      }.jsify() as JSObject;

      final result = await augenWebAR.createRenderer(options).toDart;
      _renderer = result as RendererJS;

      // Append WebGL canvas to container
      final domEl = _renderer!.domElement;
      final element = domEl as web.HTMLElement;
      element.style.position = 'absolute';
      element.style.top = '0';
      element.style.left = '0';
      element.style.pointerEvents = 'none';
      container.appendChild(element);

      _isInitialized = true;
    } catch (e) {
      throw StateError('Failed to initialize web renderer: $e');
    }
  }

  void setSize(int width, int height) {
    _renderer?.setSize(width.toJS, height.toJS);
  }

  void addNode(Map<String, dynamic> nodeData) {
    _renderer?.addNode(nodeData.jsify() as JSObject);
  }

  void removeNode(String nodeId) {
    _renderer?.removeNode(nodeId.toJS);
  }

  void updateNode(Map<String, dynamic> nodeData) {
    _renderer?.updateNode(nodeData.jsify() as JSObject);
  }

  void attachNodeToMarker(String nodeId, String markerId) {
    _renderer?.attachNodeToMarker(nodeId.toJS, markerId.toJS);
  }

  void detachNodeFromMarker(String nodeId) {
    _renderer?.detachNodeFromMarker(nodeId.toJS);
  }

  void updateMarkerTransform(
      String markerId, List<double> transform, bool visible) {
    if (_renderer == null) return;
    // W7: Fill pre-allocated Float64List, pass typed-array as JSFloat64Array
    // to avoid per-call JSArray allocation and per-element JSNumber boxing.
    final n = transform.length < 16 ? transform.length : 16;
    for (var i = 0; i < n; i++) {
      _transformBuffer[i] = transform[i];
    }
    for (var i = n; i < 16; i++) {
      _transformBuffer[i] = 0;
    }
    _renderer!.updateMarkerTransform(
        markerId.toJS, _transformBuffer.toJS, visible.toJS);
  }

  void render() {
    _renderer?.render();
  }

  void dispose() {
    _renderer?.dispose();
    _renderer = null;
    _isInitialized = false;
  }
}
