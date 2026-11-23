import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../theme/app_theme.dart';
import 'web_files.dart';

/// Takes a photo with the computer's camera. Returns JPEG bytes or null.
Future<Uint8List?> takeCameraPhoto(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => const _CameraDialog(),
  );
}

class _CameraDialog extends StatefulWidget {
  const _CameraDialog();

  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  static int _seq = 0;
  late final String _viewType = 'schatz-camera-${_seq++}';
  final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true');
  web.MediaStream? _stream;
  String? _error;
  Uint8List? _shot;

  @override
  void initState() {
    super.initState();
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..transform = 'scaleX(-1)';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
    _open();
  }

  Future<void> _open() async {
    try {
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
          .toDart;
      _video.srcObject = _stream;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Allow camera access in your browser to take a photo.',
        );
      }
    }
  }

  Future<void> _capture() async {
    final w = _video.videoWidth;
    final h = _video.videoHeight;
    if (w == 0 || h == 0) return;
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    // Un-mirror the selfie view.
    ctx.translate(w.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video, 0, 0, w.toDouble(), h.toDouble());
    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) => done.complete(b)).toJS,
      'image/jpeg',
      0.85.toJS,
    );
    final blob = await done.future;
    if (blob == null || !mounted) return;
    final bytes = await blobToBytes(blob);
    setState(() => _shot = bytes);
  }

  void _close([Uint8List? result]) {
    for (final t in _stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      t.stop();
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 640,
        height: 520,
        child: Stack(
          children: [
            Positioned.fill(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : _shot != null
                  ? Image.memory(_shot!, fit: BoxFit.cover)
                  : HtmlElementView(viewType: _viewType),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: _close,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (_error == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(
                  child: _shot == null
                      ? InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _capture,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.accent,
                                width: 4,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => setState(() => _shot = null),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                              ),
                              child: const Text('Retake'),
                            ),
                            const SizedBox(width: 14),
                            FilledButton(
                              onPressed: () => _close(_shot),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                              ),
                              child: const Text('Use photo'),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
