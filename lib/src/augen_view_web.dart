import 'package:flutter/material.dart';
import 'augen_controller.dart';
import 'models/ar_session_config.dart';

/// Callback for when the AR view is created
typedef AugenViewCreatedCallback = void Function(AugenController controller);

/// Widget for displaying AR view on web
class AugenView extends StatefulWidget {
  final AugenViewCreatedCallback onViewCreated;
  final ARSessionConfig config;

  const AugenView({
    super.key,
    required this.onViewCreated,
    this.config = const ARSessionConfig(),
  });

  @override
  State<AugenView> createState() => _AugenViewState();
}

class _AugenViewState extends State<AugenView> {
  AugenController? _controller;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: 'augen_ar_view',
      onPlatformViewCreated: (id) {
        final controller = AugenController(id);
        _controller = controller;
        widget.onViewCreated(controller);
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
