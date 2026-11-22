import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

/// Voice and video call screens (mirrors the mobile ModernCallView:
/// Calling..., Ringing..., connected with timer, Mute, Video, Share screen,
/// More, End). Placeholder only: no audio or video until Agora is wired.
Future<void> showCallScreen(
  BuildContext context, {
  required String name,
  Color? color,
  bool isGroup = false,
  required bool video,
  bool incoming = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _CallScreen(
      name: name,
      color: color,
      isGroup: isGroup,
      video: video,
      incoming: incoming,
    ),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

/// Incoming call popup in the bottom-right corner (Decline / Accept).
Future<void> showIncomingCall(
  BuildContext context, {
  required String name,
  Color? color,
  required bool video,
}) async {
  final accepted = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        _IncomingCallCard(name: name, color: color, video: video),
    transitionBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
  if (accepted == true && context.mounted) {
    await showCallScreen(
      context,
      name: name,
      color: color,
      video: video,
      incoming: true,
    );
  }
}

enum _Phase { calling, ringing, connected }

class _CallScreen extends StatefulWidget {
  const _CallScreen({
    required this.name,
    required this.color,
    required this.isGroup,
    required this.video,
    required this.incoming,
  });

  final String name;
  final Color? color;
  final bool isGroup;
  final bool video;
  final bool incoming;

  @override
  State<_CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<_CallScreen> {
  late _Phase _phase = widget.incoming ? _Phase.connected : _Phase.calling;
  late bool _camera = widget.video;
  bool _muted = false;
  int _seconds = 0;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    if (!widget.incoming) {
      _timers.add(
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _phase = _Phase.ringing);
        }),
      );
      _timers.add(
        Timer(const Duration(milliseconds: 4000), () {
          if (mounted) setState(() => _phase = _Phase.connected);
        }),
      );
    }
    _timers.add(
      Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _phase == _Phase.connected) {
          setState(() => _seconds++);
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  String get _status {
    switch (_phase) {
      case _Phase.calling:
        return widget.video ? 'Video calling...' : 'Calling...';
      case _Phase.ringing:
        return widget.video ? 'Video ringing...' : 'Ringing...';
      case _Phase.connected:
        final m = (_seconds ~/ 60).toString().padLeft(2, '0');
        final s = (_seconds % 60).toString().padLeft(2, '0');
        return '$m:$s';
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final showVideo = _camera && _phase == _Phase.connected;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1450), Color(0xFF140B28), Color(0xFF0D0819)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Remote video placeholder.
              if (showVideo)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 80, 20, 120),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF3A2366), Color(0xFF1E1236)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(
                            name: widget.name,
                            color: widget.color,
                            isGroup: widget.isGroup,
                            size: 120,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Video will appear here',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Header
              Positioned(
                top: 18,
                left: 24,
                right: 24,
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SchatzApp call',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const Spacer(),
                    if (showVideo)
                      Text(
                        '${widget.name}  ·  $_status',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // Voice / connecting view
              if (!showVideo)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingAvatar(
                        name: widget.name,
                        color: widget.color,
                        isGroup: widget.isGroup,
                        pulsing: _phase != _Phase.connected,
                      ),
                      const SizedBox(height: 26),
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 17,
                        ),
                      ),
                      if (widget.video && !_camera) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Your camera is off',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Self view
              if (_camera)
                Positioned(
                  right: 36,
                  bottom: 136,
                  child: Container(
                    width: 220,
                    height: 136,
                    decoration: BoxDecoration(
                      color: const Color(0xFF241640),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, color: Colors.white54, size: 30),
                        SizedBox(height: 6),
                        Text('You', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),

              // Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CallButton(
                          icon: _muted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          label: 'Mute',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _CallButton(
                          icon: _camera
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          label: 'Video',
                          active: !_camera,
                          onTap: () {
                            if (!widget.video && !_camera) {
                              _toast('Video request sent');
                            }
                            setState(() => _camera = !_camera);
                          },
                        ),
                        _CallButton(
                          icon: Icons.screen_share_rounded,
                          label: 'Share screen',
                          onTap: () =>
                              _toast('Screen sharing is not available yet'),
                        ),
                        _MoreButton(onSelect: _toast),
                        const SizedBox(width: 8),
                        _CallButton(
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          danger: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({
    required this.name,
    required this.color,
    required this.isGroup,
    required this.pulsing,
  });

  final String name;
  final Color? color;
  final bool isGroup;
  final bool pulsing;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              for (final offset in [0.0, 0.5])
                Builder(
                  builder: (_) {
                    final v = (_c.value + offset) % 1.0;
                    return Container(
                      width: 140 + 80 * v,
                      height: 140 + 80 * v,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(
                          alpha: 0.35 * (1 - v),
                        ),
                      ),
                    );
                  },
                ),
            child!,
          ],
        ),
        child: Avatar(
          name: widget.name,
          color: widget.color,
          isGroup: widget.isGroup,
          size: 140,
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFE53935)
        : (active ? Colors.white : Colors.white.withValues(alpha: 0.14));
    final fg = danger
        ? Colors.white
        : (active ? AppColors.heading : Colors.white);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: danger ? 64 : 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Icon(icon, color: fg, size: 26),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: PopupMenuButton<String>(
        tooltip: 'More',
        position: PopupMenuPosition.over,
        offset: const Offset(0, -180),
        onSelected: (v) => onSelect('$v is coming soon.'),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'People in this call',
            child: ListTile(
              leading: Icon(Icons.people_alt_outlined),
              title: Text('People in this call'),
            ),
          ),
          PopupMenuItem(
            value: 'Invitation link',
            child: ListTile(
              leading: Icon(Icons.link_rounded),
              title: Text('Invitation link'),
            ),
          ),
          PopupMenuItem(
            value: 'Open chat',
            child: ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded),
              title: Text('Open chat'),
            ),
          ),
        ],
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(27),
          ),
          child: const Icon(Icons.more_horiz_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.name,
    required this.color,
    required this.video,
  });

  final String name;
  final Color? color;
  final bool video;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A1450), Color(0xFF140B28)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Avatar(name: name, color: color, size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            video
                                ? 'Incoming video call...'
                                : 'Incoming voice call...',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _PillAction(
                        icon: Icons.call_end_rounded,
                        label: 'Decline',
                        color: const Color(0xFFE53935),
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillAction(
                        icon: video ? Icons.videocam_rounded : Icons.call,
                        label: 'Accept',
                        color: const Color(0xFF1DBF3A),
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
