import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/live/call_service.dart';
import '../data/live/chat_repo.dart';
import 'device_info.dart';

/// Web session state for SchatzApp Web.
///
/// Rules (also enforced on the server):
///  * 4 hours with no activity  -> logged out
///  * "Keep me signed in" ticked -> up to 7 days, unticked -> up to 24 hours
///  * Logging the device out on the phone signs this tab out at once
class WebAuth extends ChangeNotifier {
  WebAuth._();
  static final WebAuth instance = WebAuth._();

  static const _kDeviceId = 'schatz_web_device_id';
  static const _kExpires = 'schatz_web_device_expires';
  static const _kLastActive = 'schatz_web_last_active';
  static const idleLimit = Duration(hours: 4);
  static const _heartbeatEvery = Duration(minutes: 2);

  SupabaseClient get _sb => Supabase.instance.client;
  late SharedPreferences _prefs;

  String? _deviceId;
  DateTime? _expiresAt;
  DateTime _lastActivity = DateTime.now();
  DateTime? _lastHeartbeat;
  bool _activitySinceHeartbeat = true;
  Timer? _ticker;
  RealtimeChannel? _channel;

  /// Temporary: opened with "Log in with Phone Number" until real phone OTP
  /// is wired (next phase). Shows demo data only.
  bool demoMode = false;

  /// Shown on the sign-in page after an automatic logout.
  String? logoutReason;

  /// Signed in with a real account (not the demo preview).
  bool get isLive =>
      !demoMode && _sb.auth.currentSession != null && _deviceId != null;

  bool get signedIn =>
      demoMode || (_sb.auth.currentSession != null && _deviceId != null);

  // -------------------------------------------------------------------------
  // Start-up
  // -------------------------------------------------------------------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs.getString(_kDeviceId);
    final exp = _prefs.getString(_kExpires);
    _expiresAt = exp == null ? null : DateTime.tryParse(exp);
    final last = _prefs.getInt(_kLastActive);
    if (last != null) {
      _lastActivity = DateTime.fromMillisecondsSinceEpoch(last);
    }

    if (_sb.auth.currentSession == null || _deviceId == null) {
      await _clearLocal();
      return;
    }
    // Closed the tab and came back: check the rules before showing anything.
    if (DateTime.now().difference(_lastActivity) > idleLimit) {
      await signOut(reason: 'You were logged out after 4 hours of inactivity.');
      return;
    }
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
      await signOut(reason: 'Your web session ended. Scan the QR code again.');
      return;
    }
    _start();
    unawaited(_heartbeat(force: true));
  }

  // -------------------------------------------------------------------------
  // QR login (talks to the web-login Edge Function)
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final res = await _sb.functions.invoke('web-login', body: body);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception('Unexpected response');
  }

  Future<QrRequest> createQr({required bool keepSignedIn}) async {
    final d = DeviceInfo.current();
    final r = await _call({
      'action': 'create',
      'device_name': d.deviceName,
      'browser': d.browser,
      'os': d.os,
      'location': d.location,
      'keep_signed_in': keepSignedIn,
    });
    if (r['ok'] != true) throw Exception(r['message'] ?? 'QR error');
    return QrRequest(
      id: r['request_id'] as String,
      pollSecret: r['poll_secret'] as String,
      qr: r['qr'] as String,
      expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
    );
  }

  /// Returns: pending | expired | rejected | used | device_limit | approved.
  /// On "approved" this signs the browser in.
  Future<String> poll(QrRequest q) async {
    final r = await _call({
      'action': 'poll',
      'request_id': q.id,
      'poll_secret': q.pollSecret,
    });
    if (r['ok'] != true) return 'expired';
    final status = r['status'] as String;
    if (status != 'approved') return status;

    await _sb.auth.setSession(
      r['refresh_token'] as String,
      accessToken: r['access_token'] as String,
    );
    _deviceId = r['device_id'] as String;
    _expiresAt = DateTime.parse(r['device_expires_at'] as String).toLocal();
    await _prefs.setString(_kDeviceId, _deviceId!);
    await _prefs.setString(_kExpires, _expiresAt!.toIso8601String());
    logoutReason = null;
    _markActive(save: true);
    _start();
    notifyListeners();
    return 'approved';
  }

  // -------------------------------------------------------------------------
  // Phone number + code login (no SMS): the code comes from the phone app
  // (Linked Devices > Link with code), so there is no Twilio cost.
  // -------------------------------------------------------------------------

  /// Signs in with the phone number and the 6-digit code shown in the app.
  /// Throws a readable message on failure.
  Future<void> codeLogin({
    required String phone,
    required String code,
    required bool keepSignedIn,
  }) async {
    final d = DeviceInfo.current();
    Map<String, dynamic> r;
    try {
      r = await _call({
        'action': 'code_login',
        'phone': phone,
        'code': code,
        'device_name': d.deviceName,
        'browser': d.browser,
        'os': d.os,
        'location': d.location,
        'keep_signed_in': keepSignedIn,
      });
    } on FunctionException catch (e) {
      final data = e.details;
      r = data is Map<String, dynamic>
          ? data
          : {'ok': false, 'message': 'Could not sign in. Try again.'};
    } catch (_) {
      throw 'Could not reach SchatzApp. Check your connection.';
    }
    if (r['ok'] != true || r['access_token'] == null) {
      throw (r['message'] as String?) ?? 'Could not sign in. Try again.';
    }
    await _sb.auth.setSession(
      r['refresh_token'] as String,
      accessToken: r['access_token'] as String,
    );
    _deviceId = r['device_id'] as String;
    _expiresAt = DateTime.parse(r['device_expires_at'] as String).toLocal();
    await _prefs.setString(_kDeviceId, _deviceId!);
    await _prefs.setString(_kExpires, _expiresAt!.toIso8601String());
    demoMode = false;
    logoutReason = null;
    _markActive(save: true);
    _start();
    notifyListeners();
  }

  /// Active countries from the same supported_countries table as the app.
  Future<List<({String name, String iso, String dial})>> countries() async {
    final rows = await _sb
        .from('supported_countries')
        .select('name, iso_code, dial_code')
        .eq('is_active', true)
        .order('name');
    return [
      for (final r in rows as List)
        (
          name: r['name'] as String,
          iso: (r['iso_code'] as String).toLowerCase(),
          dial: (r['dial_code'] as String).replaceAll('+', ''),
        ),
    ];
  }

  // -------------------------------------------------------------------------
  // Activity, heartbeat, remote logout
  // -------------------------------------------------------------------------

  /// Call on any user input (mouse, keyboard, touch, scroll).
  void onUserActivity() {
    if (!signedIn || demoMode) return;
    _markActive();
    final last = _lastHeartbeat;
    if (last == null || DateTime.now().difference(last) > _heartbeatEvery) {
      unawaited(_heartbeat());
    }
  }

  void _markActive({bool save = false}) {
    final now = DateTime.now();
    final prevSaved = _lastActivity;
    _lastActivity = now;
    _activitySinceHeartbeat = true;
    // Persist at most every 30 seconds.
    if (save || now.difference(prevSaved) > const Duration(seconds: 30)) {
      _prefs.setInt(_kLastActive, now.millisecondsSinceEpoch);
    }
  }

  void _start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _listenForRemoteLogout();
  }

  Future<void> _check() async {
    if (!signedIn || demoMode) return;
    final now = DateTime.now();
    if (now.difference(_lastActivity) > idleLimit) {
      await signOut(reason: 'You were logged out after 4 hours of inactivity.');
    } else if (_expiresAt != null && now.isAfter(_expiresAt!)) {
      await signOut(reason: 'Your web session ended. Scan the QR code again.');
    } else if (_activitySinceHeartbeat &&
        (_lastHeartbeat == null ||
            now.difference(_lastHeartbeat!) > _heartbeatEvery)) {
      await _heartbeat();
    }
  }

  Future<void> _heartbeat({bool force = false}) async {
    final id = _deviceId;
    if (id == null || (!force && !_activitySinceHeartbeat)) return;
    _lastHeartbeat = DateTime.now();
    _activitySinceHeartbeat = false;
    try {
      final status = await _sb.rpc(
        'web_device_heartbeat',
        params: {'p_device_id': id},
      );
      switch (status) {
        case 'inactive':
          await signOut(
            reason: 'You were logged out after 4 hours of inactivity.',
            revoke: false,
          );
        case 'expired':
          await signOut(
            reason: 'Your web session ended. Scan the QR code again.',
            revoke: false,
          );
        case 'revoked':
          await signOut(
            reason: 'This device was logged out from your phone.',
            revoke: false,
          );
      }
    } on AuthException {
      await signOut(
        reason: 'This device was logged out from your phone.',
        revoke: false,
      );
    } catch (_) {
      // Offline: the local 4-hour and expiry checks still apply.
    }
  }

  void _listenForRemoteLogout() {
    final id = _deviceId;
    if (id == null) return;
    _channel?.unsubscribe();
    _channel = _sb
        .channel('web-device-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'web_devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (p) {
            if (p.newRecord['revoked_at'] != null) {
              signOut(
                reason: 'This device was logged out from your phone.',
                revoke: false,
              );
            }
          },
        )
        .subscribe();
  }

  // -------------------------------------------------------------------------
  // Logout
  // -------------------------------------------------------------------------

  Future<void> signOut({String? reason, bool revoke = true}) async {
    if (demoMode) {
      demoMode = false;
      notifyListeners();
      return;
    }
    try {
      await CallService.instance.stop();
    } catch (_) {}
    final id = _deviceId;
    if (revoke && id != null) {
      try {
        await _sb.rpc('revoke_web_device', params: {'p_device_id': id});
      } catch (_) {}
    }
    try {
      // Local scope: only this browser. The phone stays signed in.
      await _sb.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    logoutReason = reason;
    await ChatRepo.instance.stop();
    await _clearLocal();
    notifyListeners();
  }

  Future<void> _clearLocal() async {
    _ticker?.cancel();
    _ticker = null;
    await _channel?.unsubscribe();
    _channel = null;
    _deviceId = null;
    _expiresAt = null;
    await _prefs.remove(_kDeviceId);
    await _prefs.remove(_kExpires);
    await _prefs.remove(_kLastActive);
  }

  void enterDemo() {
    demoMode = true;
    logoutReason = null;
    notifyListeners();
  }
}

class QrRequest {
  QrRequest({
    required this.id,
    required this.pollSecret,
    required this.qr,
    required this.expiresAt,
  });

  final String id;
  final String pollSecret;
  final String qr;
  final DateTime expiresAt;
}
