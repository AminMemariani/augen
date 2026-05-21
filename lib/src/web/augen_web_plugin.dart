import 'dart:ui_web' as ui_web;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web plugin registration for Augen.
class AugenWebPlugin {
  /// Registry of platform view containers keyed by viewId.
  /// Used by [AugenPlatformWeb] to locate the container element
  /// regardless of whether it is in a shadow DOM or not yet
  /// findable via `document.getElementById`.
  static final Map<int, web.HTMLDivElement> viewRegistry = {};

  static void registerWith(Registrar registrar) {
    ui_web.platformViewRegistry.registerViewFactory(
      'augen_ar_view',
      (int viewId) {
        final container = web.document.createElement('div') as web.HTMLDivElement;
        container.id = 'augen_ar_view_$viewId';
        container.style.width = '100%';
        container.style.height = '100%';
        container.style.position = 'relative';
        container.style.overflow = 'hidden';
        container.style.backgroundColor = 'black';
        container.style.setProperty('touch-action', 'none');
        viewRegistry[viewId] = container;
        return container;
      },
    );
  }
}
