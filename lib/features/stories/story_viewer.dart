import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../data/demo_data.dart';
import '../../data/live/stories_repo.dart';
import '../../widgets/avatar.dart';
import '../../widgets/sunset_painter.dart';

/// Full-screen story viewer (used by For You and on small screens).
Future<void> showStoryViewer(
  BuildContext context, {
  required List<DemoStory> stories,
  int startIndex = 0,
  bool isMine = false,
  StoryHooks hooks = const StoryHooks(),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, _) => Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: StoryPlayer(
              stories: stories,
              startIndex: startIndex,
              isMine: isMine,
              hooks: hooks,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

/// What the player can do with live stories (all optional in preview).
class StoryHooks {
  const StoryHooks({
    this.onViewed,
    this.onReply,
    this.onReact,
    this.reactions,
    this.onViewers,
    this.onDelete,
  });

  final void Function(DemoStory s, StoryItem item)? onViewed;
  final Future<void> Function(DemoStory s, StoryItem item, String text)?
  onReply;
  final Future<void> Function(StoryItem item, String type)? onReact;

  /// My reactions on a story (favorite, peace, laugh, sad, angry).
  final Future<Set<String>> Function(StoryItem item)? reactions;
  final void Function(StoryItem item)? onViewers;
  final Future<void> Function(StoryItem item)? onDelete;
}

/// Story player (mobile users_story page): progress bars, auto-advance to
/// the next item and then the next person, previous/next arrows, pause,
/// reply box and 😂 ❤️ 🤙 reactions. Used inline in the Simplified panel
/// and inside the full-screen viewer.
class StoryPlayer extends StatefulWidget {
  const StoryPlayer({
    super.key,
    required this.stories,
    required this.startIndex,
    required this.onClose,
    this.isMine = false,
    this.onPersonChanged,
    this.showArrows = true,
    this.hooks = const StoryHooks(),
  });

  final StoryHooks hooks;
  final List<DemoStory> stories;
  final int startIndex;
  final bool isMine;
  final VoidCallback onClose;

  /// Called when the player moves to another person's story.
  final ValueChanged<int>? onPersonChanged;
  final bool showArrows;

  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer>
    with SingleTickerProviderStateMixin {
  late int _person = widget.startIndex;
  int _item = 0;
  bool _paused = false;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _next();
        });

  DemoStory get _story => widget.stories[_person];

  /// My reactions on the current story.
  Set<String> _mine = {};

  StoryItem get _current => _story.items[_item];

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() => _setPaused(_replyFocus.hasFocus));
    _progress.forward();
    _onShown();
  }

  /// Marks the story viewed and loads my reactions on it.
  void _onShown() {
    final item = _current;
    final h = widget.hooks;
    _progress.duration = const Duration(seconds: 6);
    if (!widget.isMine) h.onViewed?.call(_story, item);
    _mine = {};
    h.reactions
        ?.call(item)
        .then((m) {
          if (mounted && identical(_current, item)) setState(() => _mine = m);
        })
        .catchError((Object _) {});
  }

  /// Videos play for their own length (up to 60 seconds).
  void _setVideoLength(Duration d) {
    final len = d > const Duration(seconds: 60)
        ? const Duration(seconds: 60)
        : (d < const Duration(seconds: 3) ? const Duration(seconds: 3) : d);
    final v = _progress.value;
    _progress.duration = len;
    if (!_paused) _progress.forward(from: v);
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _setPaused(bool p) {
    if (!mounted) return;
    setState(() => _paused = p);
    p ? _progress.stop() : _progress.forward();
  }

  void _restart() {
    _onShown();
    _progress
      ..reset()
      ..forward();
    if (_paused) _progress.stop();
  }

  void _goPerson(int p, {bool last = false}) {
    setState(() {
      _person = p;
      _item = last ? widget.stories[p].items.length - 1 : 0;
    });
    widget.onPersonChanged?.call(p);
    _restart();
  }

  void _next() {
    if (_item < _story.items.length - 1) {
      setState(() => _item++);
      _restart();
    } else if (_person < widget.stories.length - 1) {
      _goPerson(_person + 1);
    } else {
      widget.onClose();
    }
  }

  void _prev() {
    if (_item > 0) {
      setState(() => _item--);
      _restart();
    } else if (_person > 0) {
      _goPerson(_person - 1, last: true);
    } else {
      _restart();
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    _reply.clear();
    _replyFocus.unfocus();
    final h = widget.hooks.onReply;
    if (h == null) {
      _toast('Reply sent to ${_story.name}');
      return;
    }
    try {
      await h(_story, _current, text);
      _toast('Reply sent to ${_story.name}');
    } catch (_) {
      _toast('Could not send your reply. Try again.');
    }
  }

  /// When each reaction was added in this session (preview lock check).
  final Map<String, DateTime> _addedAt = {};

  Future<void> _react(String type) async {
    final h = widget.hooks.onReact;
    final was = _mine.contains(type);
    if (!was && _mine.length >= StoriesRepo.maxReactionsPerUser) {
      _toast(ReactionLimitException.message);
      return;
    }
    final key = '${_current.id}|$type';
    if (was && h == null) {
      final at = _addedAt[key];
      if (at == null ||
          DateTime.now().difference(at) > StoriesRepo.reactionLockAfter) {
        _toast(ReactionLockedException.message);
        return;
      }
    }
    if (!was) _addedAt[key] = DateTime.now();
    setState(() => was ? _mine.remove(type) : _mine.add(type));
    if (h == null) return;
    try {
      await h(_current, type);
    } catch (e) {
      if (e is ReactionLockedException || e is ReactionLimitException) {
        _toast('$e');
      }
      if (mounted) {
        setState(() => was ? _mine.add(type) : _mine.remove(type));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _story.items[_item];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _StoryContent(
            key: ValueKey('${_person}_$_item'),
            item: item,
            paused: _paused,
            onVideoLength: _setVideoLength,
          ),

          // Tap zones: left = previous, right = next, hold = pause.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _prev,
                  onLongPressStart: (_) => _setPaused(true),
                  onLongPressEnd: (_) => _setPaused(false),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  onLongPressStart: (_) => _setPaused(true),
                  onLongPressEnd: (_) => _setPaused(false),
                ),
              ),
            ],
          ),

          // Arrows
          if (widget.showArrows) ...[
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_left,
                  tooltip: 'Previous',
                  onTap: _prev,
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Next',
                  onTap: _next,
                ),
              ),
            ),
          ],

          // Progress + header
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x55000000), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _story.items.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, _) => LinearProgressIndicator(
                                value: i < _item
                                    ? 1
                                    : (i == _item ? _progress.value : 0),
                                minHeight: 3.5,
                                borderRadius: BorderRadius.circular(2),
                                backgroundColor: Colors.white38,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Avatar(
                          name: _story.name,
                          color: _story.color,
                          photoUrl: _story.avatarUrl,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isMine ? 'My Stories' : _story.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.createdAt != null
                                  ? _ago(item.createdAt!)
                                  : _story.time,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onOpened: () => _setPaused(true),
                        onCanceled: () => _setPaused(false),
                        onSelected: (v) async {
                          if (v == 'Delete') {
                            final del = widget.hooks.onDelete;
                            if (del != null) {
                              try {
                                await del(_current);
                                _toast('Story deleted');
                                widget.onClose();
                              } catch (_) {
                                _toast('Could not delete. Try again.');
                              }
                            }
                            return;
                          }
                          _setPaused(false);
                          _toast('$v is available on the mobile app.');
                        },
                        itemBuilder: (_) => widget.isMine
                            ? const [
                                PopupMenuItem(
                                  value: 'Delete',
                                  child: Text('Delete story'),
                                ),
                              ]
                            : const [
                                PopupMenuItem(
                                  value: 'Get notification',
                                  child: Text('Get notification'),
                                ),
                                PopupMenuItem(
                                  value: 'Repost',
                                  child: Text('Repost'),
                                ),
                              ],
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_paused)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Paused',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Reply bar (or Viewers on my own story)
          if (!widget.isMine)
            Positioned(
              left: 10,
              right: 10,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: !item.commentsEnabled
                        ? const Text(
                            'Replies are turned off',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          )
                        : SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _reply,
                              focusNode: _replyFocus,
                              onSubmitted: (_) => _sendReply(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts...',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.12),
                                contentPadding: const EdgeInsets.only(left: 16),
                                suffixIcon: IconButton(
                                  tooltip: 'Send',
                                  onPressed: _sendReply,
                                  icon: const Icon(
                                    Icons.send_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Colors.white70,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  for (final MapEntry(key: type, value: e)
                      in StoriesRepo.reactionEmoji.entries)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _react(type),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _mine.contains(type)
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 19)),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    final v = widget.hooks.onViewers;
                    if (v == null) {
                      _toast('Viewers show once you are signed in.');
                      return;
                    }
                    _setPaused(true);
                    v(_current);
                  },
                  icon: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    item.id.isEmpty ? 'Viewers' : 'Viewers (${item.viewCount})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return 'Yesterday';
}

/// Phone's 10 text-story fonts, by text_font_index.
TextStyle storyFont(int index, {double size = 30, Color? color}) {
  final c = color ?? const Color(0xFF2D2D2D);
  return switch (index) {
    1 => GoogleFonts.openSans(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.bold,
    ),
    2 => GoogleFonts.lato(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.bold,
    ),
    3 => GoogleFonts.montserrat(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.bold,
    ),
    4 => GoogleFonts.poppins(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.w300,
    ),
    5 => GoogleFonts.dancingScript(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.bold,
    ),
    6 => GoogleFonts.greatVibes(fontSize: size, color: c),
    7 => GoogleFonts.pacifico(fontSize: size, color: c),
    8 => GoogleFonts.sacramento(fontSize: size, color: c),
    9 => GoogleFonts.satisfy(fontSize: size, color: c),
    _ => GoogleFonts.roboto(
      fontSize: size,
      color: c,
      fontWeight: FontWeight.bold,
    ),
  };
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({
    super.key,
    required this.item,
    required this.paused,
    required this.onVideoLength,
  });

  final StoryItem item;
  final bool paused;
  final ValueChanged<Duration> onVideoLength;

  @override
  Widget build(BuildContext context) {
    if (item.kind == StoryKind.text) {
      final g = item.gradient;
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                g ??
                [
                  item.background,
                  Color.lerp(item.background, Colors.white, 0.45)!,
                ],
          ),
        ),
        child: Text(
          item.text,
          textAlign: TextAlign.center,
          style: g != null
              ? storyFont(item.fontIndex, size: 30)
              : const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
        ),
      );
    }
    final url = item.mediaUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url.isEmpty)
          CustomPaint(painter: SunsetPainter())
        else if (item.isVideo)
          _StoryVideo(url: url, paused: paused, onLength: onVideoLength)
        else ...[
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Image.network(url, fit: BoxFit.cover),
          ),
          Container(color: Colors.black26),
          Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, p) => p == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        ],
        if (item.caption.isNotEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 90,
            child: Text(
              item.caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryVideo extends StatefulWidget {
  const _StoryVideo({
    required this.url,
    required this.paused,
    required this.onLength,
  });

  final String url;
  final bool paused;
  final ValueChanged<Duration> onLength;

  @override
  State<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<_StoryVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          widget.onLength(_c.value.duration);
          if (!widget.paused) _c.play();
        })
        .catchError((Object _) {});
  }

  @override
  void didUpdateWidget(covariant _StoryVideo old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    widget.paused ? _c.pause() : _c.play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: _ready
          ? AspectRatio(
              aspectRatio: _c.value.aspectRatio,
              child: VideoPlayer(_c),
            )
          : const CircularProgressIndicator(color: Colors.white),
    );
  }
}
