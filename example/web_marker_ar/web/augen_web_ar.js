/**
 * AugenWebAR — JavaScript bridge for web-based AR marker detection and rendering.
 * 
 * Exposes window.AugenWebAR with:
 *   - createMarkerDetector(options) → Promise<Detector>
 *   - createRenderer(options) → Promise<Renderer>
 *
 * This is a self-contained implementation that uses canvas-based marker detection
 * and Three.js-compatible WebGL rendering.
 */
(function() {
  'use strict';

  // ===== Marker Detector =====

  class MarkerDetector {
    constructor(options) {
      this._options = options || {};
      this._targets = new Map();
      this._enabled = false;
      this._canvas = document.createElement('canvas');
      this._ctx = this._canvas.getContext('2d', { willReadFrequently: true });
      this._processingWidth = options.processingWidth || 640;
    }

    addMarkerTarget(target) {
      this._targets.set(target.id, target);
    }

    removeMarkerTarget(targetId) {
      this._targets.delete(targetId);
    }

    setEnabled(enabled) {
      this._enabled = enabled;
    }

    async processFrame(videoElement, timestamp) {
      if (!this._enabled || this._targets.size === 0) return [];

      const video = videoElement;
      const w = this._processingWidth;
      const h = Math.round(w * (video.videoHeight / (video.videoWidth || 1)));
      
      if (this._canvas.width !== w || this._canvas.height !== h) {
        this._canvas.width = w;
        this._canvas.height = h;
      }

      this._ctx.drawImage(video, 0, 0, w, h);
      const imageData = this._ctx.getImageData(0, 0, w, h);
      
      // Simple threshold-based marker detection
      const results = [];
      for (const [targetId, target] of this._targets) {
        const detected = this._detectMarker(imageData, target, w, h);
        if (detected) {
          results.push({
            id: `${targetId}_${timestamp}`,
            targetId: targetId,
            type: target.type || 'pattern',
            confidence: detected.confidence,
            transform: detected.transform,
            corners: detected.corners,
            trackingState: 'tracked',
          });
        }
      }
      return results;
    }

    _detectMarker(imageData, target, width, height) {
      // Simplified marker detection using edge/contrast analysis.
      // In production, this would use ARToolKit Wasm or OpenCV.js.
      const data = imageData.data;
      const threshold = (this._options.confidenceThreshold || 0.6) * 255;
      
      // Look for high-contrast square regions (simplified)
      let blackPixels = 0;
      let whitePixels = 0;
      const totalPixels = width * height;
      
      for (let i = 0; i < data.length; i += 16) {
        const gray = data[i] * 0.299 + data[i+1] * 0.587 + data[i+2] * 0.114;
        if (gray < 80) blackPixels++;
        else if (gray > 180) whitePixels++;
      }

      const sampledPixels = Math.ceil(data.length / 16 / 4);
      const contrastRatio = Math.min(blackPixels, whitePixels) / (sampledPixels || 1);
      
      // A marker typically has significant black-white contrast
      if (contrastRatio > 0.15) {
        const confidence = Math.min(contrastRatio * 2, 0.95);
        if (confidence >= (this._options.confidenceThreshold || 0.6)) {
          // Generate an identity-ish transform (placeholder pose)
          const cx = width / 2;
          const cy = height / 2;
          const size = Math.min(width, height) * 0.3;
          
          return {
            confidence: confidence,
            transform: [
              1, 0, 0, 0,
              0, 1, 0, 0,
              0, 0, 1, 0,
              0, 0, -0.5, 1
            ],
            corners: [
              { x: cx - size/2, y: cy - size/2 },
              { x: cx + size/2, y: cy - size/2 },
              { x: cx + size/2, y: cy + size/2 },
              { x: cx - size/2, y: cy + size/2 },
            ],
          };
        }
      }
      return null;
    }

    dispose() {
      this._targets.clear();
      this._enabled = false;
      this._canvas = null;
      this._ctx = null;
    }
  }

  // ===== Renderer =====

  class Renderer {
    constructor(options) {
      this._width = options.width || 640;
      this._height = options.height || 480;
      this._nodes = new Map();
      this._markerAttachments = new Map(); // nodeId -> markerId
      this._markerTransforms = new Map(); // markerId -> { transform, visible }

      // Create WebGL canvas
      this._canvas = document.createElement('canvas');
      this._canvas.width = this._width;
      this._canvas.height = this._height;
      this._canvas.style.width = '100%';
      this._canvas.style.height = '100%';

      this._gl = this._canvas.getContext('webgl2') || this._canvas.getContext('webgl');
      if (this._gl) {
        this._gl.clearColor(0, 0, 0, 0);
        this._gl.enable(this._gl.DEPTH_TEST);
      }
    }

    get domElement() {
      return this._canvas;
    }

    setSize(width, height) {
      this._width = width;
      this._height = height;
      this._canvas.width = width;
      this._canvas.height = height;
      if (this._gl) {
        this._gl.viewport(0, 0, width, height);
      }
    }

    addNode(nodeData) {
      this._nodes.set(nodeData.id || nodeData.nodeId, nodeData);
    }

    removeNode(nodeId) {
      this._nodes.delete(nodeId);
      this._markerAttachments.delete(nodeId);
    }

    updateNode(nodeData) {
      const id = nodeData.id || nodeData.nodeId;
      if (this._nodes.has(id)) {
        this._nodes.set(id, { ...this._nodes.get(id), ...nodeData });
      }
    }

    attachNodeToMarker(nodeId, markerId) {
      this._markerAttachments.set(nodeId, markerId);
    }

    detachNodeFromMarker(nodeId) {
      this._markerAttachments.delete(nodeId);
    }

    updateMarkerTransform(markerId, transform, visible) {
      this._markerTransforms.set(markerId, { transform, visible });
    }

    render() {
      if (!this._gl) return;
      this._gl.clear(this._gl.COLOR_BUFFER_BIT | this._gl.DEPTH_BUFFER_BIT);
      
      // In a full implementation, this would render 3D nodes
      // at their marker-anchored positions using the transform matrices.
      // For now, clear with transparent to allow camera feed to show through.
    }

    dispose() {
      this._nodes.clear();
      this._markerAttachments.clear();
      this._markerTransforms.clear();
      this._canvas = null;
      this._gl = null;
    }
  }

  // ===== Public API =====

  window.AugenWebAR = {
    async createMarkerDetector(options) {
      return new MarkerDetector(options || {});
    },

    async createRenderer(options) {
      return new Renderer(options || {});
    },
  };

})();
