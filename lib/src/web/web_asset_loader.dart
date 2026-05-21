import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('AugenWebAR')
external JSObject? get _augenWebARGlobal;

/// Loads Wasm, JS, marker patterns, and 3D models for web.
class WebAssetLoader {
  bool _bridgeLoaded = false;
  static Completer<void>? _bridgeLoadCompleter;

  bool get isBridgeLoaded => _bridgeLoaded;

  /// Load the AugenWebAR JS bridge script.
  /// Uses a static completer to prevent duplicate loads (race condition guard).
  /// If the bridge is already available on window (e.g. loaded via index.html),
  /// this is a no-op.
  Future<void> loadBridgeScript({String path = 'assets/packages/augen/web/augen_web_ar.js'}) async {
    if (_bridgeLoaded) return;

    // Check if already loaded globally (e.g. via <script> in index.html)
    try {
      if (_augenWebARGlobal != null) {
        _bridgeLoaded = true;
        return;
      }
    } catch (_) {
      // Not available, proceed to load
    }

    // If already loading, await the existing completer
    if (_bridgeLoadCompleter != null) {
      await _bridgeLoadCompleter!.future;
      return;
    }

    _bridgeLoadCompleter = Completer<void>();

    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.src = path;
    script.type = 'text/javascript';

    script.onload = (web.Event event) {
      _bridgeLoaded = true;
      _bridgeLoadCompleter!.complete();
    }.toJS;
    script.onerror = (web.Event event) {
      _bridgeLoadCompleter!.completeError(StateError('Failed to load bridge script: $path'));
      _bridgeLoadCompleter = null;
    }.toJS;

    web.document.head!.appendChild(script);
    await _bridgeLoadCompleter!.future;
  }

  /// Load a marker pattern file and return its content.
  ///
  /// Restricts paths to relative paths starting with `assets/` to prevent
  /// path traversal or absolute URL injection.
  Future<String> loadPatternFile(String path) async {
    // Validate path: must be relative, start with assets/, no traversal
    if (path.contains('://') || path.startsWith('/') || path.contains('..')) {
      throw ArgumentError(
        'Invalid pattern path: "$path". '
        'Path must be relative and start with "assets/" (no absolute URLs or ".." traversal).',
      );
    }
    if (!path.startsWith('assets/')) {
      throw ArgumentError(
        'Invalid pattern path: "$path". Path must start with "assets/".',
      );
    }

    final response = await web.window.fetch(path.toJS).toDart;
    if (!response.ok) {
      throw StateError('Failed to load pattern file: $path (${response.status})');
    }
    final text = await response.text().toDart;
    return text.toDart;
  }

  /// Load a binary asset (wasm, glb, etc.) and return bytes.
  ///
  /// Restricts paths to relative paths to prevent path traversal or absolute
  /// URL injection.
  Future<web.Response> loadBinaryAsset(String path) async {
    if (path.contains('://') || path.startsWith('/') || path.contains('..')) {
      throw ArgumentError(
        'Invalid asset path: "$path". '
        'Path must be relative (no absolute URLs, no ".." traversal).',
      );
    }
    final response = await web.window.fetch(path.toJS).toDart;
    if (!response.ok) {
      throw StateError('Failed to load asset: $path (${response.status})');
    }
    return response;
  }
}
