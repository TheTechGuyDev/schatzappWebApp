import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// True when the browser is running on a phone.
///
/// SchatzApp Web is for computers and tablets only (laptops, desktops,
/// iPads, Android tablets, Surface Go and similar). Phones are sent to the
/// "Get the app" page instead.
///
/// Checks the user agent first, then falls back to the physical screen size
/// so a phone using "Request desktop site" is still caught. A desktop browser
/// window that is simply resized small is NOT treated as a phone.
final bool isPhoneDevice = _detectPhone();

bool _detectPhone() {
  final nav = web.window.navigator;
  final ua = nav.userAgent.toLowerCase();

  // Tablets explicitly allowed.
  if (ua.contains('ipad') || ua.contains('tablet')) return false;

  // Phones by user agent.
  if (ua.contains('iphone') || ua.contains('ipod')) return true;
  if (ua.contains('android') && ua.contains('mobile')) return true;
  if (ua.contains('mobi') || ua.contains('windows phone')) return true;

  // Touch device with a small physical screen (phone in desktop mode).
  final screen = web.window.screen;
  final shortSide = math.min(screen.width, screen.height);
  final hasTouch = nav.maxTouchPoints > 0;
  return hasTouch && shortSide < 600;
}
