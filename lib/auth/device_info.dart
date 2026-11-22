import 'package:web/web.dart' as web;

/// Browser, OS and a readable device name, sent with the QR request so the
/// phone can show "Chrome on Windows" before approving.
class DeviceInfo {
  DeviceInfo._(this.browser, this.os);

  factory DeviceInfo.current() {
    final ua = web.window.navigator.userAgent;
    String browser;
    if (ua.contains('Edg/')) {
      browser = 'Edge';
    } else if (ua.contains('OPR/') || ua.contains('Opera')) {
      browser = 'Opera';
    } else if (ua.contains('Firefox/')) {
      browser = 'Firefox';
    } else if (ua.contains('Chrome/')) {
      browser = 'Chrome';
    } else if (ua.contains('Safari/')) {
      browser = 'Safari';
    } else {
      browser = 'Browser';
    }
    String os;
    if (ua.contains('Windows')) {
      os = 'Windows';
    } else if (ua.contains('iPad')) {
      os = 'iPadOS';
    } else if (ua.contains('Mac OS X') || ua.contains('Macintosh')) {
      os = 'macOS';
    } else if (ua.contains('CrOS')) {
      os = 'ChromeOS';
    } else if (ua.contains('Android')) {
      os = 'Android';
    } else if (ua.contains('Linux')) {
      os = 'Linux';
    } else {
      os = 'Unknown OS';
    }
    return DeviceInfo._(browser, os);
  }

  final String browser;
  final String os;

  String get deviceName => '$browser on $os';

  /// Approximate location from the computer's time zone (no permission
  /// prompt). Example: "WAT (UTC+1)".
  String get location {
    final now = DateTime.now();
    final off = now.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs();
    final m = off.inMinutes.abs() % 60;
    final utc = m == 0
        ? 'UTC$sign$h'
        : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
    return '${now.timeZoneName} ($utc)';
  }
}
