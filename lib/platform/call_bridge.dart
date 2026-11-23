import 'dart:convert';
import 'dart:js_interop';

/// Dart side of web/agora/call_bridge.js (Agora Web SDK wrapper).
@JS('SchatzCall')
external _Bridge? get _bridge;

extension type _Bridge(JSObject _) implements JSObject {
  external void setListener(JSFunction f);
  external void tone(String kind);
  external JSPromise<JSString> join(
    String sdkUrl,
    String appId,
    String channel,
    String token,
    int uid,
    bool video,
  );
  external void attach(String slot, String elementId);
  external void setMic(bool on);
  external JSPromise<JSString> setCamera(bool on);
  external JSPromise<JSString> startScreen();
  external JSPromise<JSString> stopScreen();
  external JSPromise<JSAny?> leave();
}

class CallBridge {
  CallBridge._();

  /// The Agora SDK is only downloaded when a call starts.
  static const _sdkUrl = 'agora/AgoraRTC_N.min.js';

  static bool get available => _bridge != null;

  static void listen(void Function(Map<String, dynamic> event) onEvent) {
    _bridge?.setListener(
      ((JSString s) {
        try {
          onEvent(Map<String, dynamic>.from(jsonDecode(s.toDart) as Map));
        } catch (_) {}
      }).toJS,
    );
  }

  /// 'ring', 'ringback' or 'stop'.
  static void tone(String kind) => _bridge?.tone(kind);

  /// Returns null on success, or a readable error.
  static Future<String?> join({
    required String appId,
    required String channel,
    required String token,
    required int uid,
    required bool video,
  }) async {
    final b = _bridge;
    if (b == null) return 'Calls are not available in this browser.';
    final r = (await b.join(_sdkUrl, appId, channel, token, uid, video).toDart)
        .toDart;
    return r.isEmpty ? null : r;
  }

  static void attach(String slot, String elementId) =>
      _bridge?.attach(slot, elementId);

  static void setMic(bool on) => _bridge?.setMic(on);

  static Future<String?> setCamera(bool on) async {
    final b = _bridge;
    if (b == null) return 'Not connected';
    final r = (await b.setCamera(on).toDart).toDart;
    return r.isEmpty ? null : r;
  }

  static Future<String?> startScreen() async {
    final b = _bridge;
    if (b == null) return 'Not connected';
    final r = (await b.startScreen().toDart).toDart;
    return r.isEmpty ? null : r;
  }

  static Future<void> stopScreen() async {
    await _bridge?.stopScreen().toDart;
  }

  static Future<void> leave() async {
    await _bridge?.leave().toDart;
  }
}
