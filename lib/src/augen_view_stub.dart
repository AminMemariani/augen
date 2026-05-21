import 'package:flutter/material.dart';
import 'augen_controller.dart';
import 'models/ar_session_config.dart';

/// Callback for when the AR view is created
typedef AugenViewCreatedCallback = void Function(AugenController controller);

/// Stub widget for unsupported platforms
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
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'AR is not supported on this platform',
        style: TextStyle(color: Colors.red, fontSize: 18),
      ),
    );
  }
}
