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

/// What the conversation can do with a message. All optional (demo mode).
class BubbleActions {
  const BubbleActions({
    this.onMenu,
    this.onQuickReact,
    this.onOpenMedia,
    this.onOpenDocument,
    this.onReplyTap,
  });

  /// Opens the message menu at a screen position.
  final void Function(DemoMessage m, Offset at)? onMenu;
  final void Function(DemoMessage m, Offset at)? onQuickReact;

  /// A photo or video was clicked (the clicked URL).
  final void Function(DemoMessage m, String url)? onOpenMedia;
  final void Function(DemoMessage m)? onOpenDocument;

  /// The quoted message in a reply was clicked.
  final void Function(String messageId)? onReplyTap;
}

/// True when white text reads better than dark text on this colour.
bool isDarkBubble(Color c) => c.computeLuminance() < 0.55;

/// One message in a conversation: text, photos, video, voice note,
/// document, call log or gift card, with ticks, reactions and group names.
/// Hovering shows react and menu buttons; right-click opens the menu.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.compact,
    this.theme,
    this.actions = const BubbleActions(),
    this.highlighted = false,
  });

  final DemoMessage message;
  final bool compact;
  final ChatThemeDef? theme;
  final BubbleActions actions;

  /// Briefly tinted after jumping to this message.
  final bool highlighted;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hover = false;
  final _menuKey = GlobalKey();
  final _reactKey = GlobalKey();

  Offset _below(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(0, box.size.height + 4));
  }

  void _setHover(bool v) {
    if (_hover != v) setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final theme = widget.theme;
    final compact = widget.compact;
    final a = widget.actions;
    final mine = m.isMine;
    final maxW = MediaQuery.sizeOf(context).width * (compact ? 0.72 : 0.42);

    final isMedia = m.isMedia;
    final onPurple = mine && theme == null && !isMedia;
    final Color bg = onPurple
        ? const Color(0xFF9A4BEB)
        : (mine
              ? (theme?.sender ?? Colors.white)
              : (theme?.receiver ?? Colors.white));
    // Text follows the bubble colour (white on purple, pink, blue...).
    final dark = isDarkBubble(bg);
    final fg = dark ? Colors.white : AppColors.heading;
    final metaColor = dark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.meta;

    final Widget body = switch (m.kind) {
      MessageKind.image => _Images(
        message: m,
        compact: compact,
        fg: fg,
        onOpen: a.onOpenMedia == null ? null : (u) => a.onOpenMedia!(m, u),
      ),
      MessageKind.video => _Video(
        message: m,
        compact: compact,
        fg: fg,
        onOpen: a.onOpenMedia == null
            ? null
            : () => a.onOpenMedia!(m, m.mediaUrl ?? ''),
      ),
      MessageKind.voice => _Voice(message: m, onColor: dark),
      MessageKind.document => _FileChip(
        icon: _docIcon(m.text),
        title: m.text.isEmpty ? 'Document' : m.text,
        subtitle: _docSubtitle(m),
        onColor: dark,
        onTap: a.onOpenDocument == null ? null : () => a.onOpenDocument!(m),
      ),
      MessageKind.call => () {
        final c = _CallInfo.parse(m.text, mine);
        return _FileChip(
          icon: c.icon,
          iconColor: c.missed ? AppColors.missed : null,
          title: c.title,
          subtitle:
              c.status +
              (m.durationSeconds != null && m.durationSeconds! > 0
                  ? ' · ${_duration(m.durationSeconds!)}'
                  : ''),
          onColor: dark,
        );
      }(),
      MessageKind.gift => _FileChip(
        icon: Icons.redeem_outlined,
        title: 'Gift card',
        subtitle: 'Open the mobile app to view',
        onColor: dark,
      ),
      _ => Text(
        m.text.isEmpty ? 'Message not supported on web yet' : m.text,
        style: TextStyle(
          fontSize: 16,
          height: 1.3,
          color: fg,
          fontStyle: m.text.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    };

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(Icons.push_pin, size: 12, color: metaColor),
          ),
        if (m.isStarred)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              Icons.label_important_sharp,
              size: 13,
              color: metaColor,
            ),
          ),
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
                ? (dark ? const Color(0xFFB9F3FF) : AppColors.teal)
                : metaColor,
          ),
        ],
      ],
    );

    final bubble = Container(
      padding: isMedia
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(14, 9, 12, 8),
      decoration: BoxDecoration(
        color: onPurple ? null : bg,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : AppColors.accentDark,
                ),
              ),
            ),
          if (m.isForwarded)
            Padding(
              padding: EdgeInsets.fromLTRB(isMedia ? 8 : 0, 0, 0, 4),
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
            _ReplyQuote(
              label: m.replyLabel,
              text: m.replyTo!,
              dark: dark,
              onTap: (a.onReplyTap != null && m.replyToId != null)
                  ? () => a.onReplyTap!(m.replyToId!)
                  : null,
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
    );

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onSecondaryTapDown: a.onMenu == null
              ? null
              : (d) => a.onMenu!(m, d.globalPosition),
          onLongPressStart: a.onMenu == null
              ? null
              : (d) => a.onMenu!(m, d.globalPosition),
          child: bubble,
        ),
        if (m.reactions.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: a.onQuickReact == null
                  ? null
                  : () => a.onQuickReact!(m, _below(_reactKey)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: m.myReaction != null
                      ? Border.all(color: AppColors.accentSoft, width: 1.5)
                      : null,
                  boxShadow: bubbleShadow,
                ),
                child: Text(
                  _reactionSummary(m.reactions),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
      ],
    );

    final showTools =
        (_hover || compact) &&
        a.onMenu != null &&
        !m.pending &&
        m.id.isNotEmpty;
    final tools = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: showTools ? 1 : 0,
      child: IgnorePointer(
        ignoring: !showTools,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine) const SizedBox(width: 6),
            _HoverButton(
              key: _reactKey,
              tooltip: 'React',
              icon: Icons.add_reaction_outlined,
              onTap: () => a.onQuickReact?.call(m, _below(_reactKey)),
            ),
            const SizedBox(width: 4),
            _HoverButton(
              key: _menuKey,
              tooltip: 'More',
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: () => a.onMenu?.call(m, _below(_menuKey)),
            ),
            if (mine) const SizedBox(width: 6),
          ],
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: widget.highlighted
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mine) tools,
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: column,
              ),
            ),
            if (!mine) tools,
          ],
        ),
      ),
    );
  }

  static String _reactionSummary(List<String> r) {
    final unique = <String>{...r}.take(3).join();
    return r.length > 1 ? '$unique ${r.length}' : unique;
  }
}

class _HoverButton extends StatelessWidget {
  const _HoverButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: const Color(0x335B1CD3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 19, color: AppColors.body),
          ),
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.text,
    required this.dark,
    this.label,
    this.onTap,
  });

  final String text;
  final String? label;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: dark ? Colors.white : AppColors.accent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : AppColors.accentDark,
                  ),
                ),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _docIcon(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (n.endsWith('.zip') || n.endsWith('.rar')) {
    return Icons.folder_zip_outlined;
  }
  return Icons.description_outlined;
}

String _docSubtitle(DemoMessage m) {
  final size = m.raw['media_size_bytes'];
  final parts = <String>[];
  final dot = m.text.lastIndexOf('.');
  if (dot > 0 && dot < m.text.length - 1) {
    parts.add(m.text.substring(dot + 1).toUpperCase());
  }
  if (size is int && size > 0) parts.add(formatBytes(size));
  return parts.isEmpty ? 'Click to open' : parts.join(' · ');
}

/// 1.2 MB style sizes.
String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _duration(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class _Images extends StatelessWidget {
  const _Images({
    required this.message,
    required this.compact,
    required this.fg,
    this.onOpen,
  });

  final DemoMessage message;
  final bool compact;
  final Color fg;
  final ValueChanged<String>? onOpen;

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
      onTap: onOpen == null ? null : () => onOpen!(url),
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
                style: TextStyle(fontSize: 15, color: fg),
              ),
            ),
        ],
      ),
    );
  }
}

class _Video extends StatelessWidget {
  const _Video({
    required this.message,
    required this.compact,
    required this.fg,
    this.onOpen,
  });

  final DemoMessage message;
  final bool compact;
  final Color fg;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final thumb = message.thumbUrl;
    final video = GestureDetector(
      onTap: onOpen,
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
    if (message.text.isEmpty) return video;
    return SizedBox(
      width: compact ? 240 : 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          video,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              message.text,
              style: TextStyle(fontSize: 15, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice note player using the browser's audio element.
class _Voice extends StatefulWidget {
  const _Voice({required this.message, required this.onColor});

  final DemoMessage message;
  final bool onColor;

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
    final fg = widget.onColor ? Colors.white : AppColors.accent;
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
    required this.onColor,
    this.subtitle,
    this.onTap,
    this.iconColor,
  });

  final Color? iconColor;
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Sits on a dark/coloured bubble (white text).
  final bool onColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mine = onColor;
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
            child: Icon(
              icon,
              color: iconColor ?? (mine ? Colors.white : AppColors.accent),
            ),
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
                      color: mine
                          ? Colors.white.withValues(alpha: 0.78)
                          : AppColors.meta,
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

/// Call log rows are stored like "video:answered" or "voice:declined".
class _CallInfo {
  _CallInfo(this.title, this.status, this.icon, this.missed);

  final String title;
  final String status;
  final IconData icon;
  final bool missed;

  static _CallInfo parse(String raw, bool mine) {
    final parts = raw.toLowerCase().split(':');
    if (parts.first.trim() == 'bimp') {
      return _CallInfo(
        'Bimp',
        mine ? 'Bimp sent' : 'Bimped',
        Icons.notifications_active_outlined,
        false,
      );
    }
    final video = parts.first.contains('video');
    final state = parts.length > 1 ? parts[1].trim() : '';
    final title = video ? 'Video call' : 'Voice call';
    final (String status, bool missed) = switch (state) {
      'answered' || 'completed' || 'ended' => ('Answered', false),
      'declined' || 'rejected' => (mine ? 'Declined' : 'Declined', !mine),
      'missed' ||
      'no_answer' ||
      'unanswered' => (mine ? 'No answer' : 'Missed', !mine),
      'cancelled' || 'canceled' => (mine ? 'Cancelled' : 'Missed', !mine),
      'busy' => ('Busy', false),
      _ => (state.isEmpty ? (mine ? 'Outgoing' : 'Incoming') : state, false),
    };
    final IconData icon = missed
        ? (video
              ? Icons.missed_video_call_outlined
              : Icons.phone_missed_outlined)
        : video
        ? Icons.videocam_outlined
        : (mine ? Icons.call_made : Icons.call_received);
    return _CallInfo(title, status, icon, missed);
  }
}
