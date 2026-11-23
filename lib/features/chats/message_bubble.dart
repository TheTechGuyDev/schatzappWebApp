import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../data/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sunset_painter.dart';

final bubbleShadow = [
  BoxShadow(
    color: const Color(0xFF5B1CD3).withValues(alpha: 0.06),
    blurRadius: 10,
    offset: const Offset(0, 3),
  ),
];

void _openUrl(String? url) {
  if (url != null && url.isNotEmpty) web.window.open(url, '_blank');
}

/// One message in a conversation: text, photos, video, voice note,
/// document, call log or gift card, with ticks, reactions and group names.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.compact,
    this.theme,
  });

  final DemoMessage message;
  final bool compact;
  final ChatThemeDef? theme;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.isMine;
    final maxW = MediaQuery.sizeOf(context).width * (compact ? 0.78 : 0.42);

    final Widget body = switch (m.kind) {
      MessageKind.image => _Images(message: m, compact: compact),
      MessageKind.video => _Video(message: m, compact: compact),
      MessageKind.voice => _Voice(message: m),
      MessageKind.document => _FileChip(
        icon: Icons.description_outlined,
        title: m.text.isEmpty ? 'Document' : m.text,
        subtitle: 'Click to open',
        mine: mine,
        onTap: () => _openUrl(m.mediaUrl),
      ),
      MessageKind.call => _FileChip(
        icon: Icons.call_outlined,
        title: m.text.isEmpty ? 'Call' : m.text,
        subtitle: m.durationSeconds == null
            ? null
            : _duration(m.durationSeconds!),
        mine: mine,
      ),
      MessageKind.gift => _FileChip(
        icon: Icons.redeem_outlined,
        title: 'Gift card',
        subtitle: 'Open the mobile app to view',
        mine: mine,
      ),
      _ => Text(
        m.text.isEmpty ? 'Message not supported on web yet' : m.text,
        style: TextStyle(
          fontSize: 16,
          height: 1.3,
          color: mine && theme == null ? Colors.white : AppColors.heading,
          fontStyle: m.text.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    };

    final isMedia = m.kind == MessageKind.image || m.kind == MessageKind.video;
    final onPurple = mine && theme == null && !isMedia;
    final metaColor = onPurple
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.meta;

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'Edited',
              style: TextStyle(fontSize: 11, color: metaColor),
            ),
          ),
        Text(m.time, style: TextStyle(fontSize: 12, color: metaColor)),
        if (mine) ...[
          const SizedBox(width: 4),
          Icon(
            m.pending
                ? Icons.schedule
                : (m.isRead ? Icons.done_all : Icons.done),
            size: 16,
            color: m.isRead && !m.pending
                ? (onPurple ? const Color(0xFFB9F3FF) : AppColors.teal)
                : metaColor,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: isMedia
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.fromLTRB(14, 9, 12, 8),
                decoration: BoxDecoration(
                  color: onPurple
                      ? null
                      : (mine
                            ? (theme?.sender ?? Colors.white)
                            : (theme?.receiver ?? Colors.white)),
                  gradient: onPurple
                      ? const LinearGradient(
                          colors: [Color(0xFFA557EE), Color(0xFF8E3FE8)],
                        )
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  boxShadow: onPurple ? null : bubbleShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (m.senderName != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isMedia ? 8 : 0,
                          isMedia ? 4 : 0,
                          0,
                          4,
                        ),
                        child: Text(
                          m.senderName!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    if (m.isForwarded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shortcut, size: 14, color: metaColor),
                            const SizedBox(width: 4),
                            Text(
                              'Forwarded',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: metaColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (m.replyTo != null && m.replyTo!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: onPurple
                              ? Colors.white.withValues(alpha: 0.18)
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: onPurple ? Colors.white : AppColors.accent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          m.replyTo!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: onPurple ? Colors.white : AppColors.body,
                          ),
                        ),
                      ),
                    if (m.kind == MessageKind.text)
                      // Time sits on the same line when there is room.
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 10,
                        runSpacing: 2,
                        children: [body, meta],
                      )
                    else ...[
                      body,
                      const SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.only(right: isMedia ? 6 : 0),
                        child: SizedBox(
                          width: isMedia ? (compact ? 240 : 280) : null,
                          child: Align(
                            alignment: Alignment.centerRight,
                            widthFactor: isMedia ? null : 1,
                            child: meta,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (m.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: bubbleShadow,
                    ),
                    child: Text(
                      _reactionSummary(m.reactions),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _reactionSummary(List<String> r) {
    final unique = <String>{...r}.take(3).join();
    return r.length > 1 ? '$unique ${r.length}' : unique;
  }
}

String _duration(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class _Images extends StatelessWidget {
  const _Images({required this.message, required this.compact});

  final DemoMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final urls = [
      if (message.mediaUrls.isNotEmpty)
        ...message.mediaUrls
      else if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
        message.mediaUrl!,
    ];
    final w = compact ? 240.0 : 280.0;
    Widget tile(String url, {double? h}) => GestureDetector(
      onTap: () => _openUrl(url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          height: h,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            height: h ?? 160,
            color: AppColors.accentSoft,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );

    Widget content;
    if (urls.isEmpty) {
      content = SizedBox(
        height: 160,
        width: w,
        child: CustomPaint(painter: SunsetPainter()),
      );
    } else if (urls.length == 1) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: tile(urls.first),
      );
    } else {
      final shown = urls.take(4).toList();
      content = GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        children: [
          for (var i = 0; i < shown.length; i++)
            Stack(
              fit: StackFit.expand,
              children: [
                tile(shown[i]),
                if (i == 3 && urls.length > 4)
                  IgnorePointer(
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Text(
                        '+${urls.length - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      );
    }
    return SizedBox(
      width: w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: content),
          if (message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 15, color: AppColors.heading),
              ),
            ),
        ],
      ),
    );
  }
}

class _Video extends StatelessWidget {
  const _Video({required this.message, required this.compact});

  final DemoMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final thumb = message.thumbUrl;
    return GestureDetector(
      onTap: () => _openUrl(message.mediaUrl),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: compact ? 240 : 280,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null && thumb.isNotEmpty)
                  Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: const Color(0xFF2A1450)),
                  )
                else
                  Container(color: const Color(0xFF2A1450)),
                const Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.black45,
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                if (message.durationSeconds != null)
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Text(
                      _duration(message.durationSeconds!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Voice note player using the browser's audio element.
class _Voice extends StatefulWidget {
  const _Voice({required this.message});

  final DemoMessage message;

  @override
  State<_Voice> createState() => _VoiceState();
}

class _VoiceState extends State<_Voice> {
  web.HTMLAudioElement? _audio;
  bool _playing = false;
  double _pos = 0;
  double _len = 0;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _audio?.pause();
    super.dispose();
  }

  void _toggle() {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;
    final a = _audio ??= web.HTMLAudioElement()..src = url;
    if (_playing) {
      a.pause();
      _tick?.cancel();
      setState(() => _playing = false);
    } else {
      a.play();
      setState(() => _playing = true);
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        final d = a.duration;
        setState(() {
          _pos = a.currentTime.toDouble();
          _len = d.isFinite ? d.toDouble() : 0;
          if (a.ended) {
            _playing = false;
            _pos = 0;
            _tick?.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.message.isMine;
    final fg = mine ? Colors.white : AppColors.accent;
    final total = _len > 0
        ? _len
        : (widget.message.durationSeconds ?? 0).toDouble();
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: fg,
              size: 36,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: total > 0 ? (_pos / total).clamp(0, 1) : 0,
                  minHeight: 3,
                  backgroundColor: fg.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(fg),
                ),
                const SizedBox(height: 4),
                Text(
                  _duration((_playing ? _pos : total).round()),
                  style: TextStyle(fontSize: 12, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({
    required this.icon,
    required this.title,
    required this.mine,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : AppColors.heading;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: mine ? Colors.white : AppColors.accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: mine ? Colors.white70 : AppColors.meta,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
