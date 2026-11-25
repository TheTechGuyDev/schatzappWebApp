import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

/// Screenshot / screen-recording protection for Private Chat Lock on the
/// web, as strong as a browser allows.
///
/// A browser can't block the OS screenshot key or screen recorders the way
/// Android (FLAG_SECURE) can, so the content is hidden whenever it is most
/// likely being captured:
///  * the tab or window loses focus (snipping tools, screen-share pickers,
///    switching to a recorder)
///  * the tab is hidden or the page is being printed
///  * the PrintScreen key is pressed (the clipboard copy is also cleared)
/// Right-click is already replaced by the app's own menu, so "Save image"
/// is not offered for private media.
class PrivacyGuard extends StatefulWidget {
  const PrivacyGuard({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends State<PrivacyGuard> {
  bool _hidden = false;
  final List<StreamSubscription<web.Event>> _subs = [];
  Timer? _printTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _listen();
  }

  @override
  void didUpdateWidget(covariant PrivacyGuard old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) {
      _stop();
      if (widget.enabled) {
        _listen();
      } else if (_hidden) {
        setState(() => _hidden = false);
      }
    }
  }

  void _listen() {
    _hidden = !web.document.hasFocus() || web.document.hidden;
    _subs.addAll([
      web.EventStreamProviders.blurEvent
          .forTarget(web.window)
          .listen((_) => _set(true)),
      web.EventStreamProviders.focusEvent
          .forTarget(web.window)
          .listen((_) => _set(web.document.hidden)),
      const web.EventStreamProvider<web.Event>('visibilitychange')
          .forTarget(web.document)
          .listen((_) => _set(web.document.hidden || !web.document.hasFocus())),
      const web.EventStreamProvider<web.Event>('beforeprint')
          .forTarget(web.window)
          .listen((_) => _set(true)),
      const web.EventStreamProvider<web.Event>('afterprint')
          .forTarget(web.window)
          .listen((_) => _set(!web.document.hasFocus())),
      web.EventStreamProviders.keyUpEvent.forTarget(web.window).listen((e) {
        final k = e.key;
        if (k == 'PrintScreen') _onPrintScreen();
      }),
      web.EventStreamProviders.keyDownEvent.forTarget(web.window).listen((e) {
        final k = e;
        // Windows Snipping Tool (Win+Shift+S) and macOS (Cmd+Shift+3/4/5).
        final snip =
            k.shiftKey &&
            (k.metaKey || k.getModifierState('OS')) &&
            ['s', 'S', '3', '4', '5'].contains(k.key);
        if (k.key == 'PrintScreen' || snip) _onPrintScreen();
      }),
    ]);
  }

  /// Hide for a moment and clear what the screenshot key just copied.
  void _onPrintScreen() {
    _set(true);
    try {
      web.window.navigator.clipboard.writeText('');
    } catch (_) {}
    _printTimer?.cancel();
    _printTimer = Timer(const Duration(seconds: 3), () {
      _set(!web.document.hasFocus() || web.document.hidden);
    });
  }

  void _set(bool hidden) {
    if (!mounted || _hidden == hidden) return;
    setState(() => _hidden = hidden);
  }

  void _stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _printTimer?.cancel();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ImageFiltered(
          enabled: _hidden,
          imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: widget.child,
        ),
        if (_hidden)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _set(false),
              child: Container(
                color: const Color(0xCCF6F2FF),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: Color(0xFF935CCC),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Private chat hidden',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Click here to show it again.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
