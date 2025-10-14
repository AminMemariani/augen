import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'augen_controller.dart';
import 'models/ar_session_config.dart';

/// Callback for when the AR view is created
typedef AugenViewCreatedCallback = void Function(AugenController controller);

/// Widget for displaying AR view
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
    const String viewType = 'augen_ar_view';

    final Map<String, dynamic> creationParams = widget.config.toMap();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () {
              params.onFocusChanged(true);
            },
          );

          controller.addOnPlatformViewCreatedListener((id) {
            params.onPlatformViewCreated(id);
            _onPlatformViewCreated(id);
          });

          return controller..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    }

    return Center(
      child: Text(
        'AR is not supported on ${defaultTargetPlatform.name}',
        style: const TextStyle(color: Colors.red, fontSize: 18),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    final controller = AugenController(id);
    _controller = controller;
    widget.onViewCreated(controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
