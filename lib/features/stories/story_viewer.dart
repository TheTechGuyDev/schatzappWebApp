import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../widgets/avatar.dart';
import '../../widgets/sunset_painter.dart';

/// Full-screen story viewer (mobile users_story page): progress bars,
/// auto-advance, previous/next, reply box and 😂 ❤️ 🤙 reactions.
/// Opens at [startIndex] in [stories] and moves on to the next person's
/// story when one finishes.
Future<void> showStoryViewer(
  BuildContext context, {
  required List<DemoStory> stories,
  int startIndex = 0,
  bool isMine = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) =>
        _StoryViewer(stories: stories, startIndex: startIndex, isMine: isMine),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({
    required this.stories,
    required this.startIndex,
    required this.isMine,
  });

  final List<DemoStory> stories;
  final int startIndex;
  final bool isMine;

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer>
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

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() {
      // Pause while typing a reply.
      _setPaused(_replyFocus.hasFocus);
    });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _setPaused(bool p) {
    setState(() => _paused = p);
    p ? _progress.stop() : _progress.forward();
  }

  void _restart() {
    _progress
      ..reset()
      ..forward();
  }

  void _next() {
    if (_item < _story.items.length - 1) {
      setState(() => _item++);
      _restart();
    } else if (_person < widget.stories.length - 1) {
      setState(() {
        _person++;
        _item = 0;
      });
      _restart();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_item > 0) {
      setState(() => _item--);
    } else if (_person > 0) {
      setState(() {
        _person--;
        _item = widget.stories[_person].items.length - 1;
      });
    }
    _restart();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _sendReply([String? emoji]) {
    final text = emoji ?? _reply.text.trim();
    if (text.isEmpty) return;
    _reply.clear();
    _replyFocus.unfocus();
    _toast(
      emoji != null
          ? 'Reacted $emoji to ${_story.name}'
          : 'Reply sent to ${_story.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _story.items[_item];
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Content
                  _StoryContent(item: item),

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

                  // Top gradient, progress and header
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 6, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < _story.items.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _progress,
                                      builder: (_, _) =>
                                          LinearProgressIndicator(
                                            value: i < _item
                                                ? 1
                                                : (i == _item
                                                      ? _progress.value
                                                      : 0),
                                            minHeight: 3,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            backgroundColor: Colors.white30,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  Colors.white,
                                                ),
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Avatar(
                                name: _story.name,
                                color: _story.color,
                                size: 38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.isMine
                                          ? 'My Stories'
                                          : _story.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _story.time,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: _paused ? 'Play' : 'Pause',
                                onPressed: () => _setPaused(!_paused),
                                icon: Icon(
                                  _paused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reply bar (not on my own story)
                  if (!widget.isMine)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 14,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: TextField(
                                controller: _reply,
                                focusNode: _replyFocus,
                                onSubmitted: (_) => _sendReply(),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Share your thoughts...',
                                  hintStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black38,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: Colors.white54,
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
                          for (final e in const ['😂', '❤️', '🤙'])
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _sendReply(e),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 24),
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
                          onPressed: () =>
                              _toast('Story viewers are coming soon.'),
                          icon: const Icon(
                            Icons.remove_red_eye_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Viewers',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({required this.item});

  final StoryItem item;

  @override
  Widget build(BuildContext context) {
    if (item.kind == StoryKind.text) {
      return Container(
        color: item.background,
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          item.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: SunsetPainter()),
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
