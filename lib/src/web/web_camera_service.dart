import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Manages camera access on web.
class WebCameraService {
  web.HTMLVideoElement? _videoElement;
  web.MediaStream? _mediaStream;
  bool _isActive = false;
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get errorStream => _errorController.stream;
  web.HTMLVideoElement? get videoElement => _videoElement;
  bool get isActive => _isActive;

  Future<web.HTMLVideoElement> start({
    required web.HTMLElement container,
    bool preferRear = true,
    int? width,
    int? height,
  }) async {
    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video.autoplay = true;
    video.setAttribute('muted', '');
    video.setAttribute('playsinline', '');
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'cover';
    video.style.position = 'absolute';
    video.style.top = '0';
    video.style.left = '0';

    // Use facingMode as a SOFT hint (ideal) so we never hang or reject when
    // the preferred camera doesn't exist on the device (e.g. desktop laptops
    // only have a front-facing camera; specifying 'environment' as a hard
    // constraint causes getUserMedia to hang or throw OverconstrainedError).
    final constraints = <String, dynamic>{
      'video': <String, dynamic>{
        'facingMode': {'ideal': preferRear ? 'environment' : 'user'},
        if (width != null) 'width': {'ideal': width},
        if (height != null) 'height': {'ideal': height},
      },
      'audio': false,
    };

    // Check secure context (HTTPS required for getUserMedia)
    if (!web.window.isSecureContext) {
      throw UnsupportedError(
        '[web_camera_unavailable] Camera access requires HTTPS. '
        'Serve your app over HTTPS or use localhost for development.',
      );
    }

    // Append the video to the container BEFORE calling play(). Some browsers
    // (Safari especially) won't resolve play() if the element is detached.
    container.appendChild(video);

    try {
      // getUserMedia hangs indefinitely if the user neither allows nor denies
      // the permission prompt. Bound it with a timeout so the AR pipeline can
      // surface a clear error instead of getting stuck on "Initializing…".
      const permissionTimeout = Duration(seconds: 10);
      web.MediaStream? mediaStream;
      try {
        mediaStream = await web.window.navigator.mediaDevices
            .getUserMedia(constraints.jsify() as web.MediaStreamConstraints)
            .toDart
            .timeout(
              permissionTimeout,
              onTimeout: () {
                throw TimeoutException(
                  '[web_camera_permission_pending] getUserMedia did not '
                  'resolve within ${permissionTimeout.inSeconds}s with the '
                  'requested constraints.',
                );
              },
            );
      } catch (preferErr) {
        // Fallback: if the preferred camera (e.g. rear) isn't available,
        // try ANY camera. This is critical on desktops which only have a
        // front-facing webcam — without this fallback, getUserMedia hangs.
        _errorController.add(
          '[web_camera_fallback] Preferred camera unavailable, retrying with any camera: $preferErr',
        );
        try {
          final fallbackConstraints = {'video': true, 'audio': false};
          mediaStream = await web.window.navigator.mediaDevices
              .getUserMedia(
                fallbackConstraints.jsify() as web.MediaStreamConstraints,
              )
              .toDart
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  throw TimeoutException(
                    '[web_camera_permission_pending] Fallback getUserMedia '
                    'also timed out. Browser may have blocked the request.',
                  );
                },
              );
        } catch (_) {
          // Both attempts failed — rethrow the ORIGINAL error so the catch
          // block below can classify it (NotAllowed, NotFound, etc.).
          rethrow;
        }
      }

      _mediaStream = mediaStream;
      video.srcObject = mediaStream;

      // play() can also hang if autoplay is blocked. The video is already
      // in the DOM at this point (appended above) which gives it the best
      // chance of starting. Use a generous timeout but never indefinite.
      try {
        await video.play().toDart.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Some browsers silently fail play() without rejecting. Don't
            // treat this as fatal — the video may still render frames.
            _errorController.add(
              '[web_camera_play_timeout] video.play() did not resolve in 5s '
              '(continuing anyway; video may still render).',
            );
            return;
          },
        );
      } catch (playErr) {
        // play() rejected. Log and continue — the stream is still attached
        // and the browser may auto-play once visible.
        _errorController.add('[web_camera_play_error] $playErr');
      }
    } catch (e) {
      // Handle timeout explicitly so it surfaces a clear, actionable error
      // instead of being rethrown as a generic JS error.
      if (e is TimeoutException) {
        final msg = e.message ?? 'Camera permission timeout';
        _errorController.add(msg);
        throw UnsupportedError(msg);
      }
      final errorName = _getErrorName(e);
      switch (errorName) {
        case 'NotAllowedError':
          _errorController.add('[web_camera_permission_denied] Camera permission denied by user.');
          throw UnsupportedError(
            '[web_camera_permission_denied] Camera permission was denied. '
            'Please allow camera access to use AR features.',
          );
        case 'NotFoundError':
          _errorController.add('[web_camera_unavailable] No camera device found.');
          throw UnsupportedError(
            '[web_camera_unavailable] No camera device found on this device.',
          );
        case 'OverconstrainedError':
          _errorController.add('[web_camera_overconstrained] Camera constraints cannot be satisfied.');
          throw UnsupportedError(
            '[web_camera_overconstrained] The requested camera constraints '
            'cannot be satisfied by any available device.',
          );
        case 'SecurityError':
          _errorController.add('[web_camera_unavailable] Camera blocked by security policy.');
          throw UnsupportedError(
            '[web_camera_unavailable] Camera access blocked by browser security policy. '
            'Ensure HTTPS is used.',
          );
        default:
          _errorController.add('Camera error: $e');
          // Remove the detached video element since startup failed.
          try { video.remove(); } catch (_) {}
          rethrow;
      }
    }

    // Video element is already in the container (appended before getUserMedia).
    _videoElement = video;
    _isActive = true;
    return video;
  }

  void stop() {
    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      _mediaStream = null;
    }
    _videoElement?.remove();
    _videoElement = null;
    _isActive = false;
  }

  void dispose() {
    stop();
    _errorController.close();
  }

  String _getErrorName(dynamic error) {
    // Try to extract DOMException name from JS error
    try {
      if (error is web.DOMException) {
        return error.name;
      }
      final str = error.toString();
      // Common pattern: "DOMException: ..., name: NotAllowedError"
      for (final name in [
        'NotAllowedError',
        'NotFoundError',
        'OverconstrainedError',
        'SecurityError',
      ]) {
        if (str.contains(name)) return name;
      }
    } catch (_) {}
    return '';
  }
}
