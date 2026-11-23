import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_files.dart';

/// Records a voice note with the browser microphone.
/// Prefers MP4/AAC (plays on iPhone and Android, like the phone's .m4a);
/// falls back to WebM/Opus on browsers without MP4 recording.
class VoiceRecorder {
  web.MediaRecorder? _rec;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  DateTime? _startedAt;
  String mime = 'audio/mp4';

  bool get isRecording => _rec != null;

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Throws a readable message if the microphone can't be used.
  Future<void> start() async {
    try {
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
    } catch (_) {
      throw 'Allow microphone access in your browser to record voice notes.';
    }
    for (final m in const [
      'audio/mp4;codecs=mp4a.40.2',
      'audio/mp4',
      'audio/webm;codecs=opus',
      'audio/webm',
    ]) {
      if (web.MediaRecorder.isTypeSupported(m)) {
        mime = m;
        break;
      }
    }
    _chunks.clear();
    final rec = web.MediaRecorder(
      _stream!,
      web.MediaRecorderOptions(mimeType: mime),
    );
    rec.ondataavailable = ((web.BlobEvent e) {
      if (e.data.size > 0) _chunks.add(e.data);
    }).toJS;
    rec.start();
    _rec = rec;
    _startedAt = DateTime.now();
  }

  /// Stops and returns the recording (null when cancelled or empty).
  Future<({Uint8List bytes, String mime, String ext, int seconds})?> stop({
    bool cancel = false,
  }) async {
    final rec = _rec;
    if (rec == null) return null;
    final seconds = elapsed.inMilliseconds / 1000;
    final stopped = Completer<void>();
    rec.onstop = ((web.Event _) => stopped.complete()).toJS;
    rec.stop();
    await stopped.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    for (final t in _stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      t.stop();
    }
    _rec = null;
    _stream = null;
    _startedAt = null;
    if (cancel || _chunks.isEmpty || seconds < 0.8) return null;
    final base = mime.split(';').first;
    final blob = web.Blob(_chunks.toJS, web.BlobPropertyBag(type: base));
    final bytes = await blobToBytes(blob);
    return (
      bytes: bytes,
      mime: base,
      ext: base.contains('mp4') ? 'm4a' : 'webm',
      seconds: seconds.round(),
    );
  }
}
