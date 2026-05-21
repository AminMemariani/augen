import 'dart:js_interop';

/// JS interop types for the AugenWebAR bridge.

@JS('AugenWebAR')
external AugenWebARNamespace get augenWebAR;

extension type AugenWebARNamespace._(JSObject _) implements JSObject {
  external JSPromise<JSObject> createMarkerDetector(JSObject options);
  external JSPromise<JSObject> createRenderer(JSObject options);
}

extension type MarkerDetectorJS._(JSObject _) implements JSObject {
  external void addMarkerTarget(JSObject target);
  external void removeMarkerTarget(JSString targetId);
  external void setEnabled(JSBoolean enabled);
  external JSPromise<JSArray<JSObject>> processFrame(
      JSObject videoElement, JSNumber timestamp);
  external void dispose();
}

extension type MarkerDetectionResultJS._(JSObject _) implements JSObject {
  external JSString get id;
  external JSString get targetId;
  external JSString get type;
  external JSNumber get confidence;
  external JSArray<JSNumber> get transform;
  external JSArray<JSObject> get corners;
  external JSString get trackingState;
}

extension type CornerJS._(JSObject _) implements JSObject {
  external JSNumber get x;
  external JSNumber get y;
}

extension type RendererJS._(JSObject _) implements JSObject {
  external void setSize(JSNumber width, JSNumber height);
  external void addNode(JSObject nodeData);
  external void removeNode(JSString nodeId);
  external void updateNode(JSObject nodeData);
  external void attachNodeToMarker(JSString nodeId, JSString markerId);
  external void detachNodeFromMarker(JSString nodeId);
  external void updateMarkerTransform(
      JSString markerId, JSFloat64Array transform, JSBoolean visible);
  external void render();
  external void dispose();
  external JSObject get domElement;
}
