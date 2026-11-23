import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A file chosen in the browser.
class PickedFile {
  PickedFile({required this.name, required this.bytes, required this.mime});

  final String name;
  final Uint8List bytes;
  final String mime;

  bool get isImage => mime.startsWith('image/');
  bool get isVideo => mime.startsWith('video/');
  bool get isAudio => mime.startsWith('audio/');
}

/// Opens the browser file picker. Returns an empty list when cancelled.
Future<List<PickedFile>> pickFiles({
  required String accept,
  bool multiple = false,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple;
  final done = Completer<List<web.File>>();
  web.EventStreamProviders.changeEvent.forTarget(input).first.then((_) {
    final list = input.files;
    final out = <web.File>[];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        final f = list.item(i);
        if (f != null) out.add(f);
      }
    }
    if (!done.isCompleted) done.complete(out);
  });
  web.EventStreamProviders.cancelEvent.forTarget(input).first.then((_) {
    if (!done.isCompleted) done.complete(const []);
  });
  input.click();
  final files = await done.future;
  final picked = <PickedFile>[];
  for (final f in files) {
    final buf = await f.arrayBuffer().toDart;
    picked.add(
      PickedFile(
        name: f.name,
        bytes: buf.toDart.asUint8List(),
        mime: f.type.isEmpty ? _mimeFromName(f.name) : f.type,
      ),
    );
  }
  return picked;
}

String _mimeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

web.Blob bytesToBlob(Uint8List bytes, String mime) =>
    web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));

Future<Uint8List> blobToBytes(web.Blob blob) async {
  final buf = await blob.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}

Future<web.Blob?> _canvasToJpeg(web.HTMLCanvasElement canvas, double q) {
  final c = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? b) => c.complete(b)).toJS, 'image/jpeg', q.toJS);
  return c.future;
}

/// Shrinks a photo in the browser (same sizes as the phone's "Standard"
/// quality: longest side 1280, JPEG 75%). GIFs are kept as they are.
Future<Uint8List> resizeImage(
  Uint8List bytes,
  String mime, {
  int maxDim = 1280,
  double quality = 0.75,
}) async {
  if (mime == 'image/gif') return bytes;
  final url = web.URL.createObjectURL(bytesToBlob(bytes, mime));
  try {
    final img = web.HTMLImageElement()..src = url;
    await img.decode().toDart;
    var w = img.naturalWidth;
    var h = img.naturalHeight;
    if (w == 0 || h == 0) return bytes;
    if (w > maxDim || h > maxDim) {
      if (w >= h) {
        h = (h * maxDim / w).round();
        w = maxDim;
      } else {
        w = (w * maxDim / h).round();
        h = maxDim;
      }
    }
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
    final blob = await _canvasToJpeg(canvas, quality);
    return blob == null ? bytes : await blobToBytes(blob);
  } catch (_) {
    return bytes;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

/// First frame of a video as a JPEG thumbnail (null if it can't be read).
Future<Uint8List?> videoThumbnail(Uint8List bytes, String mime) async {
  final url = web.URL.createObjectURL(bytesToBlob(bytes, mime));
  try {
    final v = web.HTMLVideoElement()
      ..muted = true
      ..preload = 'auto'
      ..src = url;
    await web.EventStreamProviders.loadedDataEvent
        .forTarget(v)
        .first
        .timeout(const Duration(seconds: 8));
    v.currentTime = 0.1;
    await web.EventStreamProviders.seekedEvent
        .forTarget(v)
        .first
        .timeout(const Duration(seconds: 5));
    var w = v.videoWidth;
    var h = v.videoHeight;
    if (w == 0 || h == 0) return null;
    const maxDim = 480;
    if (w > maxDim || h > maxDim) {
      if (w >= h) {
        h = (h * maxDim / w).round();
        w = maxDim;
      } else {
        w = (w * maxDim / h).round();
        h = maxDim;
      }
    }
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0, w.toDouble(), h.toDouble());
    final blob = await _canvasToJpeg(canvas, 0.7);
    return blob == null ? null : await blobToBytes(blob);
  } catch (_) {
    return null;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

/// Length of an audio or video file in seconds (null if unknown).
Future<int?> mediaDuration(Uint8List bytes, String mime) async {
  final url = web.URL.createObjectURL(bytesToBlob(bytes, mime));
  try {
    final a = web.HTMLAudioElement()
      ..preload = 'metadata'
      ..src = url;
    await web.EventStreamProviders.loadedMetadataEvent
        .forTarget(a)
        .first
        .timeout(const Duration(seconds: 8));
    final d = a.duration;
    return d.isFinite ? d.round() : null;
  } catch (_) {
    return null;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
