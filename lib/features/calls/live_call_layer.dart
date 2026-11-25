import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../data/live/call_service.dart';
import '../../platform/call_bridge.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

/// Shows live calls over the app: the incoming call card and the call
/// screen. Placed once in the signed-in shell.
class CallLayer extends StatefulWidget {
  const CallLayer({super.key, required this.child});

  final Widget child;

  @override
  State<CallLayer> createState() => _CallLayerState();
}

class _CallLayerState extends State<CallLayer> {
  CallService get _calls => CallService.instance;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _calls.addListener(_changed);
    _calls.notice.addListener(_onNotice);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_calls.phase == CallPhase.connected && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _calls.removeListener(_changed);
    _calls.notice.removeListener(_onNotice);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _onNotice() {
    final t = _calls.notice.value;
    if (t == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
    _calls.notice.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        // Not const: these must rebuild on every call change.
        if (_calls.active && !_calls.minimized)
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _calls,
              builder: (_, _) => _LiveCallScreen(tick: DateTime.now()),
            ),
          ),
        if (_calls.active && _calls.minimized)
          Positioned(
            right: 24,
            bottom: 24,
            child: ListenableBuilder(
              listenable: _calls,
              builder: (_, _) => _MiniCall(tick: DateTime.now()),
            ),
          ),
        if (_calls.hasIncoming)
          Positioned(
            right: 24,
            bottom: 24,
            child: ListenableBuilder(
              listenable: _calls,
              builder: (_, _) => _IncomingCard(name: _calls.peerName),
            ),
          ),
      ],
    );
  }
}

String _clockText(DateTime? since) {
  if (since == null) return '00:00';
  final s = DateTime.now().difference(since).inSeconds;
  final h = s ~/ 3600;
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$sec' : '$m:$sec';
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = CallService.instance;
    return Material(
      elevation: 14,
      shadowColor: const Color(0x555B1CD3),
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Avatar(name: c.peerName, photoUrl: c.peerAvatar, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            c.isBimp
                                ? Icons.notifications_active_rounded
                                : (c.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.call),
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            c.isBimp
                                ? 'Bimp'
                                : c.isVideo
                                ? 'Incoming video call'
                                : 'Incoming voice call',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.meta,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Decline',
                    icon: Icons.call_end_rounded,
                    color: AppColors.missed,
                    onTap: () => CallService.instance.decline(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    label: 'Accept',
                    icon: c.isBimp
                        ? Icons.notifications_active_rounded
                        : (c.isVideo ? Icons.videocam_rounded : Icons.call),
                    color: AppColors.online,
                    onTap: () async {
                      final err = await CallService.instance.accept();
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A `div` element the call bridge draws a video into.
int _slotSeq = 0;

class _VideoSlot extends StatelessWidget {
  const _VideoSlot({super.key, required this.slot});

  /// 'local' or 'remote:' followed by the Agora uid.
  final String slot;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (e) {
        final div = e as web.HTMLDivElement;
        final id = 'sc-${slot.replaceAll(':', '-')}-${_slotSeq++}';
        div
          ..id = id
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#120A22';
        // Wait a frame so the element is in the page before playing.
        Future.delayed(
          const Duration(milliseconds: 50),
          () => CallBridge.attach(slot, id),
        );
      },
    );
  }
}

class _LiveCallScreen extends StatelessWidget {
  const _LiveCallScreen({required this.tick});

  /// Changes every rebuild so the timer and controls always refresh.
  final DateTime tick;

  @override
  Widget build(BuildContext context) {
    final c = CallService.instance;
    final videoPeers = c.peers.where((p) => p.hasVideo).toList();
    final connected = c.phase == CallPhase.connected;
    final status = switch (c.phase) {
      CallPhase.dialing =>
        c.ringing
            ? (c.isVideo ? 'Video ringing...' : 'Ringing...')
            : (c.isVideo ? 'Video calling...' : 'Calling...'),
      CallPhase.connecting => 'Connecting...',
      CallPhase.connected =>
        c.isGroup
            ? '${_clockText(c.connectedAt)}  ·  ${c.peers.length + 1} in call'
            : _clockText(c.connectedAt),
      _ => '',
    };
    // While presenting, the screen preview is the big view instead.
    final showLocal = c.cameraOn && !c.sharing;

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
        child: Stack(
          children: [
            // Presenting: your shared screen fills the view (like Meet).
            if (c.sharing)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 64, 20, 116),
                  child: _PresentingView(peerName: c.peerName),
                ),
              )
            // Remote video
            else if (videoPeers.isNotEmpty)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 64, 20, 116),
                  child: _VideoGrid(peers: videoPeers),
                ),
              ),

            // While presenting, the other person's video sits in a corner.
            if (c.sharing && videoPeers.isNotEmpty)
              Positioned(
                left: 36,
                bottom: 132,
                child: Container(
                  width: 240,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _VideoSlot(
                    key: ValueKey('pip-${videoPeers.first.uid}'),
                    slot: 'remote:${videoPeers.first.uid}',
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
                  if (videoPeers.isNotEmpty || c.sharing)
                    Text(
                      '${c.peerName}  ·  $status',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Minimize and keep chatting',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => c.setMinimized(true),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_fullscreen_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Voice view (or video before anyone's camera is on)
            if (videoPeers.isEmpty && !c.sharing)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Pulse(
                      pulsing: !connected,
                      child: Avatar(
                        name: c.peerName,
                        photoUrl: c.peerAvatar,
                        isGroup: c.isGroup,
                        size: 140,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      c.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 17,
                      ),
                    ),
                    if (c.isVideo && connected && c.peers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Their camera is off',
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
            if (showLocal)
              Positioned(
                right: 36,
                bottom: 132,
                child: Container(
                  width: 240,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: _VideoSlot(key: ValueKey('self'), slot: 'local'),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 8,
                        child: Text(
                          'You',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Video requests (voice calls)
            if (c.incomingVideoRequest != null || c.myVideoRequestPending)
              Positioned(
                left: 0,
                right: 0,
                bottom: 112,
                child: Center(
                  child: _RequestBanner(
                    text: c.incomingVideoRequest != null
                        ? '${c.incomingVideoRequest} wants to switch to video'
                        : 'Video request sent. Waiting for an answer...',
                    actions: c.incomingVideoRequest != null
                        ? [
                            ('Decline', false, c.declineVideoRequest),
                            ('Switch to video', true, c.acceptVideoRequest),
                          ]
                        : [('Cancel', false, c.cancelVideoRequest)],
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
                        icon: c.micOn
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        label: c.micOn ? 'Mute' : 'Unmute',
                        active: !c.micOn,
                        onTap: c.toggleMic,
                      ),
                      _CallButton(
                        icon: c.cameraOn
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: c.cameraOn
                            ? 'Turn camera off'
                            : 'Turn camera on',
                        active: !c.cameraOn,
                        onTap: c.toggleCamera,
                      ),
                      _CallButton(
                        icon: c.sharing
                            ? Icons.stop_screen_share_rounded
                            : Icons.screen_share_rounded,
                        label: c.sharing ? 'Stop sharing' : 'Share screen',
                        active: c.sharing,
                        onTap: c.toggleScreen,
                      ),
                      const SizedBox(width: 8),
                      _CallButton(
                        icon: Icons.call_end_rounded,
                        label: 'End call',
                        danger: true,
                        onTap: c.hangUp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestBanner extends StatelessWidget {
  const _RequestBanner({required this.text, required this.actions});

  final String text;
  final List<(String, bool, Future<void> Function())> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(width: 12),
          for (final (label, primary, onTap) in actions)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: primary
                  ? FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(label),
                    )
                  : TextButton(
                      onPressed: onTap,
                      child: Text(
                        label,
                        style: const TextStyle(color: AppColors.body),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// The call shrunk to a card while the user keeps chatting.
class _MiniCall extends StatelessWidget {
  const _MiniCall({required this.tick});

  final DateTime tick;

  @override
  Widget build(BuildContext context) {
    final c = CallService.instance;
    final video = c.peers.where((p) => p.hasVideo).toList();
    final status = switch (c.phase) {
      CallPhase.dialing => c.ringing ? 'Ringing...' : 'Calling...',
      CallPhase.connecting => 'Connecting...',
      CallPhase.connected => _clockText(c.connectedAt),
      _ => '',
    };
    return Material(
      elevation: 14,
      shadowColor: const Color(0x665B1CD3),
      borderRadius: BorderRadius.circular(20),
      color: const Color(0xFF1C1033),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (video.isNotEmpty)
              SizedBox(
                height: 170,
                child: _VideoSlot(
                  key: ValueKey('mini-${video.first.uid}'),
                  slot: 'remote:${video.first.uid}',
                ),
              ),
            InkWell(
              onTap: () => c.setMinimized(false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Avatar(
                      name: c.peerName,
                      photoUrl: c.peerAvatar,
                      isGroup: c.isGroup,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            c.incomingVideoRequest != null
                                ? 'Wants to switch to video'
                                : status,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MiniButton(
                      icon: c.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      tip: c.micOn ? 'Mute' : 'Unmute',
                      active: !c.micOn,
                      onTap: c.toggleMic,
                    ),
                    _MiniButton(
                      icon: Icons.open_in_full_rounded,
                      tip: 'Open call',
                      onTap: () => c.setMinimized(false),
                    ),
                    _MiniButton(
                      icon: Icons.call_end_rounded,
                      tip: 'End call',
                      danger: true,
                      onTap: c.hangUp,
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

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? const Color(0xFFE53935)
                  : (active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(
              icon,
              size: 19,
              color: active && !danger ? AppColors.heading : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresentingView extends StatelessWidget {
  const _PresentingView({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.present_to_all_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'You are presenting to $peerName',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => CallService.instance.toggleScreen(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.heading,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Stop presenting'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const _VideoSlot(key: ValueKey('present'), slot: 'local'),
          ),
        ),
      ],
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.peers});

  final List<CallPeer> peers;

  @override
  Widget build(BuildContext context) {
    Widget tile(CallPeer p) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: _VideoSlot(
        key: ValueKey('grid-${p.uid}'),
        slot: 'remote:${p.uid}',
      ),
    );
    if (peers.length == 1) return tile(peers.first);
    final cols = peers.length <= 4 ? 2 : 3;
    return LayoutBuilder(
      builder: (_, box) {
        final rows = (peers.length / cols).ceil();
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        final h = (box.maxHeight - gap * (rows - 1)) / rows;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in peers)
              SizedBox(width: w, height: h, child: tile(p)),
          ],
        );
      },
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.pulsing, required this.child});

  final bool pulsing;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
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
        child: widget.child,
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
