import '../models/ar_tracked_marker.dart';
import 'web_scene_renderer.dart';

/// Maps tracked markers to scene nodes.
class WebMarkerAnchorManager {
  final WebSceneRenderer _renderer;
  final Map<String, String> _nodeToMarker = {}; // nodeId -> markerId
  final Map<String, Set<String>> _markerToNodes = {}; // markerId -> nodeIds

  WebMarkerAnchorManager(this._renderer);

  void attachNodeToMarker(String nodeId, String markerId) {
    _nodeToMarker[nodeId] = markerId;
    _markerToNodes.putIfAbsent(markerId, () => {}).add(nodeId);
    _renderer.attachNodeToMarker(nodeId, markerId);
  }

  void detachNode(String nodeId) {
    final markerId = _nodeToMarker.remove(nodeId);
    if (markerId != null) {
      _markerToNodes[markerId]?.remove(nodeId);
    }
    _renderer.detachNodeFromMarker(nodeId);
  }

  void updateTrackedMarkers(List<ARTrackedMarker> markers) {
    for (final marker in markers) {
      // W9: Skip markers with no attached nodes — no need to push a
      // transform across the JS boundary for an empty group.
      final nodes = _markerToNodes[marker.targetId];
      if (nodes == null || nodes.isEmpty) continue;
      _renderer.updateMarkerTransform(
        marker.targetId,
        marker.transform,
        marker.isTracked,
      );
    }
  }

  Set<String> getNodesForMarker(String markerId) {
    return _markerToNodes[markerId] ?? {};
  }

  void dispose() {
    _nodeToMarker.clear();
    _markerToNodes.clear();
  }
}
