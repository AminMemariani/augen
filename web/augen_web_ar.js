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

  // Size of the downsampled grayscale template used for matching.
  const TEMPLATE_SIZE = 16;
  // Step size when scanning the camera frame for matches (in pixels).
  const SCAN_STEP = 8;
  // Window scales (relative to frame min-dimension) to search at.
  const SCAN_SCALES = [0.25, 0.35, 0.5];

  class MarkerDetector {
    constructor(options) {
      this._options = options || {};
      this._targets = new Map();
      // targetId -> { template: Float32Array(TEMPLATE_SIZE*TEMPLATE_SIZE), mean, std }
      this._templates = new Map();
      this._enabled = false;
      this._canvas = document.createElement('canvas');
      this._ctx = this._canvas.getContext('2d', { willReadFrequently: true });
      // Scratch canvas used to rasterize the marker source image.
      this._templateCanvas = document.createElement('canvas');
      this._templateCanvas.width = TEMPLATE_SIZE;
      this._templateCanvas.height = TEMPLATE_SIZE;
      this._templateCtx = this._templateCanvas.getContext('2d', { willReadFrequently: true });
      this._processingWidth = options.processingWidth || 640;
    }

    addMarkerTarget(target) {
      this._targets.set(target.id, target);
      // Eagerly load the image template if provided. PNG/JPG → grayscale 16×16.
      const src = target.imagePath || target.patternPath;
      if (src) {
        this._loadTemplate(target.id, src).catch((err) => {
          console.warn('[AugenWebAR] template load failed for', target.id, err);
        });
      }
    }

    async _loadTemplate(targetId, path) {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      const loaded = new Promise((resolve, reject) => {
        img.onload = () => resolve();
        img.onerror = (e) => reject(new Error('image load failed: ' + path));
      });
      img.src = path;
      await loaded;

      // Rasterize to TEMPLATE_SIZE × TEMPLATE_SIZE grayscale.
      this._templateCtx.drawImage(img, 0, 0, TEMPLATE_SIZE, TEMPLATE_SIZE);
      const data = this._templateCtx.getImageData(0, 0, TEMPLATE_SIZE, TEMPLATE_SIZE).data;
      const len = TEMPLATE_SIZE * TEMPLATE_SIZE;
      const gray = new Float32Array(len);
      let sum = 0;
      for (let i = 0, j = 0; j < len; i += 4, j++) {
        const g = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
        gray[j] = g;
        sum += g;
      }
      const mean = sum / len;
      let sqSum = 0;
      for (let j = 0; j < len; j++) {
        const d = gray[j] - mean;
        gray[j] = d; // store mean-subtracted values for fast NCC
        sqSum += d * d;
      }
      const std = Math.sqrt(sqSum / len) || 1;
      this._templates.set(targetId, { gray, mean, std });
    }

    removeMarkerTarget(targetId) {
      this._targets.delete(targetId);
      this._templates.delete(targetId);
    }

    setEnabled(enabled) {
      this._enabled = enabled;
    }

    async processFrame(videoElement, timestamp) {
      if (!this._enabled || this._targets.size === 0) return [];

      const video = videoElement;
      const w = this._processingWidth;
      const h = Math.round(w * (video.videoHeight / (video.videoWidth || 1)));
      if (!h) return [];

      if (this._canvas.width !== w || this._canvas.height !== h) {
        this._canvas.width = w;
        this._canvas.height = h;
      }
      this._ctx.drawImage(video, 0, 0, w, h);
      const imageData = this._ctx.getImageData(0, 0, w, h);

      // Build a grayscale view of the frame once per call.
      const frameGray = this._frameToGrayscale(imageData, w, h);

      const results = [];
      for (const [targetId, target] of this._targets) {
        const tmpl = this._templates.get(targetId);
        const detected = tmpl
          ? this._detectByTemplate(frameGray, w, h, tmpl, target)
          : this._detectByContrast(imageData, w, h);
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

    _frameToGrayscale(imageData, w, h) {
      const data = imageData.data;
      const out = new Float32Array(w * h);
      for (let i = 0, j = 0; j < out.length; i += 4, j++) {
        out[j] = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
      }
      return out;
    }

    /**
     * Multi-scale template matching using normalized cross-correlation (NCC).
     * Returns { confidence, transform, corners } or null.
     */
    _detectByTemplate(frameGray, w, h, tmpl, target) {
      const minDim = Math.min(w, h);
      let best = null;

      for (const scale of SCAN_SCALES) {
        const windowSize = Math.max(TEMPLATE_SIZE, Math.round(minDim * scale));
        const step = SCAN_STEP;

        for (let y = 0; y + windowSize <= h; y += step) {
          for (let x = 0; x + windowSize <= w; x += step) {
            const score = this._ncc(frameGray, w, x, y, windowSize, tmpl);
            if (best == null || score > best.score) {
              best = { score, x, y, windowSize };
            }
          }
        }
      }

      if (!best) return null;
      const threshold = this._options.confidenceThreshold || 0.6;
      if (best.score < threshold) return null;

      const cx = best.x + best.windowSize / 2;
      const cy = best.y + best.windowSize / 2;
      const size = best.windowSize;
      const physical = target.physicalWidth || 0.08;
      // Pose: place marker in front of camera at distance derived from
      // apparent size. This is a coarse estimate, not a calibrated pose.
      // depth ≈ physicalWidth / (apparentSize / focalLength); we use a
      // synthetic focal length proportional to frame width.
      const focal = w; // synthetic focal in pixels
      const depth = (physical * focal) / size;
      const tx = ((cx - w / 2) / focal) * depth;
      const ty = -((cy - h / 2) / focal) * depth;
      const tz = -depth;

      return {
        confidence: Math.min(best.score, 0.99),
        transform: [
          1, 0, 0, 0,
          0, 1, 0, 0,
          0, 0, 1, 0,
          tx, ty, tz, 1,
        ],
        corners: [
          { x: best.x, y: best.y },
          { x: best.x + size, y: best.y },
          { x: best.x + size, y: best.y + size },
          { x: best.x, y: best.y + size },
        ],
      };
    }

    /**
     * Normalized cross-correlation between a frame window and the template.
     * Resamples the window down to TEMPLATE_SIZE×TEMPLATE_SIZE using
     * nearest-neighbour for speed. Returns a score in [-1, 1].
     */
    _ncc(frameGray, frameWidth, x0, y0, windowSize, tmpl) {
      const N = TEMPLATE_SIZE;
      const len = N * N;
      // Downsample window into a local array.
      const win = new Float32Array(len);
      const stepF = windowSize / N;
      let sum = 0;
      for (let j = 0; j < N; j++) {
        const sy = (y0 + (j + 0.5) * stepF) | 0;
        const rowOff = sy * frameWidth;
        for (let i = 0; i < N; i++) {
          const sx = (x0 + (i + 0.5) * stepF) | 0;
          const v = frameGray[rowOff + sx];
          win[j * N + i] = v;
          sum += v;
        }
      }
      const mean = sum / len;
      // NCC against pre-centered template (tmpl.gray is already mean-subtracted).
      let num = 0;
      let sqSum = 0;
      for (let k = 0; k < len; k++) {
        const d = win[k] - mean;
        num += d * tmpl.gray[k];
        sqSum += d * d;
      }
      const denom = Math.sqrt(sqSum / len) * tmpl.std * len;
      return denom > 1e-6 ? num / denom : 0;
    }

    /**
     * Fallback for targets without an imagePath: very coarse "is there a
     * high-contrast square in the frame" check. Returns identity-pose
     * placeholder when triggered.
     */
    _detectByContrast(imageData, width, height) {
      const data = imageData.data;
      let blackPixels = 0;
      let whitePixels = 0;
      for (let i = 0; i < data.length; i += 16) {
        const gray = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
        if (gray < 80) blackPixels++;
        else if (gray > 180) whitePixels++;
      }
      const sampledPixels = Math.ceil(data.length / 16 / 4);
      const contrastRatio = Math.min(blackPixels, whitePixels) / (sampledPixels || 1);
      if (contrastRatio > 0.15) {
        const confidence = Math.min(contrastRatio * 2, 0.95);
        if (confidence >= (this._options.confidenceThreshold || 0.6)) {
          const cx = width / 2;
          const cy = height / 2;
          const size = Math.min(width, height) * 0.3;
          return {
            confidence: confidence,
            transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,-0.5,1],
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
      this._templates.clear();
      this._enabled = false;
      this._canvas = null;
      this._ctx = null;
      this._templateCanvas = null;
      this._templateCtx = null;
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
