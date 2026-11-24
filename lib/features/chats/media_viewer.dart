import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../data/demo_data.dart';
import '../../platform/web_files.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import 'message_bubble.dart' show formatBytes;

/// One photo or video in a chat, for the viewer and its strip.
class MediaItem {
  const MediaItem({
    required this.message,
    required this.url,
    required this.isVideo,
    required this.sender,
    this.senderPhoto,
    this.thumb,
  });

  final DemoMessage message;
  final String url;
  final bool isVideo;
  final String sender;
  final String? senderPhoto;
  final String? thumb;
}

/// Actions the viewers hand back to the conversation.
class ViewerActions {
  const ViewerActions({
    required this.onReply,
    required this.onStar,
    required this.onReact,
    required this.onForward,
  });

  final void Function(DemoMessage m) onReply;
  final Future<void> Function(DemoMessage m) onStar;
  final void Function(DemoMessage m, Offset at) onReact;
  final void Function(DemoMessage m) onForward;
}

/// "Today at 10:30 AM" style label.
String viewerTime(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t =
      '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  if (diff == 0) return 'Today at $t';
  if (diff == 1) return 'Yesterday at $t';
  return '${d.day}/${d.month}/${d.year} at $t';
}

// ---------------------------------------------------------------------------
// Photos and videos
// ---------------------------------------------------------------------------

Future<void> showMediaViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int start,
  required ViewerActions actions,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) =>
        _MediaViewer(items: items, start: start, actions: actions),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer({
    required this.items,
    required this.start,
    required this.actions,
  });

  final List<MediaItem> items;
  final int start;
  final ViewerActions actions;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late int _i = widget.start.clamp(0, widget.items.length - 1);
  final _zoom = TransformationController();
  final _strip = ScrollController();
  final _reactKey = GlobalKey();
  final Map<String, bool> _starred = {};

  MediaItem get _item => widget.items[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStrip());
  }

  @override
  void dispose() {
    _zoom.dispose();
    _strip.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.items.length) return;
    setState(() {
      _i = i;
      _zoom.value = Matrix4.identity();
    });
    _scrollStrip();
  }

  void _scrollStrip() {
    if (!_strip.hasClients) return;
    const w = 72.0;
    final target = (_i * w) - (_strip.position.viewportDimension / 2) + w / 2;
    _strip.animateTo(
      target.clamp(0, _strip.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _zoomBy(double f) {
    final s = (_zoom.value.getMaxScaleOnAxis() * f).clamp(1.0, 5.0);
    setState(() => _zoom.value = Matrix4.diagonal3Values(s, s, 1));
  }

  bool get _isStarred => _starred[_item.message.id] ?? _item.message.isStarred;

  Future<void> _download() async {
    final it = _item;
    try {
      await downloadUrl(
        it.url,
        fileNameFromUrl(
          it.url,
          fallback: it.isVideo ? 'video.mp4' : 'photo.jpg',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download. Try again.')),
        );
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(_i - 1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(_i + 1);
    } else if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Offset _below(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(0, box.size.height + 4));
  }

  @override
  Widget build(BuildContext context) {
    final it = _item;
    final m = it.message;
    final a = widget.actions;
    final live = m.id.isNotEmpty && m.raw.isNotEmpty;
    void close() => Navigator.of(context).pop();

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: AppColors.pageBg,
        child: Column(
          children: [
            // Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Avatar(name: it.sender, photoUrl: it.senderPhoto, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.sender,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading,
                          ),
                        ),
                        Text(
                          viewerTime(m.createdAt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.meta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!it.isVideo) ...[
                    _Tool(
                      icon: Icons.zoom_out_rounded,
                      tip: 'Zoom out',
                      onTap: () => _zoomBy(1 / 1.5),
                    ),
                    _Tool(
                      icon: Icons.zoom_in_rounded,
                      tip: 'Zoom in',
                      onTap: () => _zoomBy(1.5),
                    ),
                  ],
                  if (live) ...[
                    _Tool(
                      icon: Icons.reply_rounded,
                      tip: 'Reply',
                      onTap: () {
                        close();
                        a.onReply(m);
                      },
                    ),
                    _Tool(
                      icon: _isStarred
                          ? Icons.label_important_sharp
                          : Icons.label_important_outline_sharp,
                      tip: _isStarred
                          ? 'Unmark as important'
                          : 'Mark as important',
                      active: _isStarred,
                      onTap: () async {
                        final was = _isStarred;
                        setState(() => _starred[m.id] = !was);
                        try {
                          await a.onStar(m);
                        } catch (_) {
                          if (mounted) setState(() => _starred[m.id] = was);
                        }
                      },
                    ),
                    _Tool(
                      key: _reactKey,
                      icon: Icons.add_reaction_outlined,
                      tip: 'React',
                      onTap: () => a.onReact(m, _below(_reactKey)),
                    ),
                    _Tool(
                      icon: Icons.shortcut_rounded,
                      tip: 'Forward',
                      onTap: () => a.onForward(m),
                    ),
                  ],
                  _Tool(
                    icon: Icons.download_rounded,
                    tip: 'Download',
                    onTap: _download,
                  ),
                  const SizedBox(width: 6),
                  _Tool(icon: Icons.close_rounded, tip: 'Close', onTap: close),
                ],
              ),
            ),
            // Media
            Expanded(
              child: Row(
                children: [
                  _Arrow(
                    icon: Icons.chevron_left_rounded,
                    enabled: _i > 0,
                    onTap: () => _go(_i - 1),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Expanded(
                            child: it.isVideo
                                ? _VideoPlayer(
                                    key: ValueKey(it.url),
                                    url: it.url,
                                  )
                                : ClipRect(
                                    child: InteractiveViewer(
                                      transformationController: _zoom,
                                      minScale: 1,
                                      maxScale: 5,
                                      child: Center(
                                        child: Image.network(
                                          it.url,
                                          key: ValueKey(it.url),
                                          fit: BoxFit.contain,
                                          loadingBuilder: (_, child, p) =>
                                              p == null
                                              ? child
                                              : const CircularProgressIndicator(
                                                  color: AppColors.accent,
                                                ),
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                            size: 64,
                                            color: AppColors.meta,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          if (m.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                m.text.trim(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.heading,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _Arrow(
                    icon: Icons.chevron_right_rounded,
                    enabled: _i < widget.items.length - 1,
                    onTap: () => _go(_i + 1),
                  ),
                ],
              ),
            ),
            // Strip of everything shared in this chat
            Container(
              height: 88,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ListView.builder(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final x = widget.items[i];
                    final on = i == _i;
                    final src = x.isVideo ? x.thumb : x.url;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => _go(i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              width: 2.5,
                              color: on ? AppColors.accent : Colors.transparent,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Opacity(
                              opacity: on ? 1 : 0.65,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (src != null && src.isNotEmpty)
                                    Image.network(
                                      src,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: AppColors.accentSoft,
                                      ),
                                    )
                                  else
                                    Container(color: const Color(0xFF2A1450)),
                                  if (x.isVideo)
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    super.key,
    required this.icon,
    required this.tip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 23,
        color: active ? AppColors.accent : AppColors.body,
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.3,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: const Color(0x335B1CD3),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 28, color: AppColors.heading),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPlayer extends StatelessWidget {
  const _VideoPlayer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView.fromTagName(
        tagName: 'video',
        onElementCreated: (e) {
          final v = e as web.HTMLVideoElement;
          v
            ..src = url
            ..controls = true
            ..autoplay = true
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain'
            ..style.backgroundColor = '#120A22';
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

Future<void> showDocumentViewer(
  BuildContext context, {
  required DemoMessage message,
  required String sender,
  String? senderPhoto,
  required ViewerActions actions,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => _DocViewer(
      message: message,
      sender: sender,
      senderPhoto: senderPhoto,
      actions: actions,
    ),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

enum _DocKind { pdf, image, text, other }

class _DocViewer extends StatefulWidget {
  const _DocViewer({
    required this.message,
    required this.sender,
    required this.actions,
    this.senderPhoto,
  });

  final DemoMessage message;
  final String sender;
  final String? senderPhoto;
  final ViewerActions actions;

  @override
  State<_DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<_DocViewer> {
  String? _objectUrl;
  String? _error;
  late bool _starred = widget.message.isStarred;
  final _reactKey = GlobalKey();

  String get _url => widget.message.mediaUrl ?? '';
  String get _name => widget.message.text.trim().isNotEmpty
      ? widget.message.text.trim()
      : fileNameFromUrl(_url, fallback: 'Document');

  _DocKind get _kind {
    final n = '${_name.toLowerCase()} ${_url.toLowerCase()}';
    bool has(List<String> exts) =>
        exts.any((e) => n.contains('.$e ') || n.endsWith('.$e'));
    if (has(['pdf'])) return _DocKind.pdf;
    if (has(['png', 'jpg', 'jpeg', 'gif', 'webp'])) return _DocKind.image;
    if (has(['txt', 'csv', 'json', 'md'])) return _DocKind.text;
    return _DocKind.other;
  }

  @override
  void initState() {
    super.initState();
    final k = _kind;
    if (k == _DocKind.pdf || k == _DocKind.text) {
      objectUrlFor(
            _url,
            k == _DocKind.pdf ? 'application/pdf' : 'text/plain; charset=utf-8',
          )
          .then((u) {
            if (mounted) setState(() => _objectUrl = u);
          })
          .catchError((Object _) {
            if (mounted) setState(() => _error = 'Could not load this file.');
          });
    }
  }

  @override
  void dispose() {
    final u = _objectUrl;
    if (u != null) web.URL.revokeObjectURL(u);
    super.dispose();
  }

  Future<void> _download() async {
    try {
      await downloadUrl(_url, _name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final a = widget.actions;
    final live = m.id.isNotEmpty && m.raw.isNotEmpty;
    void close() => Navigator.of(context).pop();

    Widget body;
    switch (_kind) {
      case _DocKind.image:
        body = InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.network(_url, fit: BoxFit.contain)),
        );
      case _DocKind.pdf || _DocKind.text:
        body = _error != null
            ? _Unavailable(
                name: _name,
                note: _error!,
                size: m.raw['media_size_bytes'],
                onDownload: _download,
              )
            : _objectUrl == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: HtmlElementView.fromTagName(
                  key: ValueKey(_objectUrl),
                  tagName: 'iframe',
                  onElementCreated: (e) {
                    (e as web.HTMLIFrameElement)
                      ..src = _objectUrl!
                      ..style.border = 'none'
                      ..style.width = '100%'
                      ..style.height = '100%';
                  },
                ),
              );
      case _DocKind.other:
        body = _Unavailable(
          name: _name,
          note: "This file type can't be previewed in the browser.",
          size: m.raw['media_size_bytes'],
          onDownload: _download,
        );
    }

    return Material(
      color: AppColors.pageBg,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Avatar(
                      name: widget.sender,
                      photoUrl: widget.senderPhoto,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.sender} · $_name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heading,
                            ),
                          ),
                          Text(
                            viewerTime(m.createdAt),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.meta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (live) ...[
                      _Tool(
                        icon: Icons.reply_rounded,
                        tip: 'Reply',
                        onTap: () {
                          close();
                          a.onReply(m);
                        },
                      ),
                      _Tool(
                        icon: _starred
                            ? Icons.label_important_sharp
                            : Icons.label_important_outline_sharp,
                        tip: _starred
                            ? 'Unmark as important'
                            : 'Mark as important',
                        active: _starred,
                        onTap: () async {
                          final was = _starred;
                          setState(() => _starred = !was);
                          try {
                            await a.onStar(m);
                          } catch (_) {
                            if (mounted) setState(() => _starred = was);
                          }
                        },
                      ),
                      _Tool(
                        key: _reactKey,
                        icon: Icons.add_reaction_outlined,
                        tip: 'React',
                        onTap: () {
                          final box =
                              _reactKey.currentContext?.findRenderObject()
                                  as RenderBox?;
                          a.onReact(
                            m,
                            box == null
                                ? Offset.zero
                                : box.localToGlobal(
                                    Offset(0, box.size.height + 4),
                                  ),
                          );
                        },
                      ),
                      _Tool(
                        icon: Icons.shortcut_rounded,
                        tip: 'Forward',
                        onTap: () => a.onForward(m),
                      ),
                    ],
                    _Tool(
                      icon: Icons.download_rounded,
                      tip: 'Download',
                      onTap: _download,
                    ),
                    const SizedBox(width: 6),
                    _Tool(
                      icon: Icons.close_rounded,
                      tip: 'Close',
                      onTap: close,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 20, 60, 20),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.name,
    required this.note,
    required this.onDownload,
    this.size,
  });

  final String name;
  final String note;
  final Object? size;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toUpperCase() : 'FILE';
    return Center(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                ext.length > 4 ? ext.substring(0, 4) : ext,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
            if (size is int)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  formatBytes(size! as int),
                  style: const TextStyle(color: AppColors.meta),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.body),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDownload,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text(
                  'Download',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
