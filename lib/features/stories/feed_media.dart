import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../data/demo_data.dart';

/// Shared mute state for every feed video (browsers only allow muted
/// autoplay, so videos start muted and the user can turn sound on).
final feedMuted = ValueNotifier<bool>(true);

/// Photos/videos of one For You post. Portrait media shows as a 9:16 frame
/// in the middle with a blurred copy filling the sides; landscape media fills
/// the width. Several items become a swipeable carousel (arrows + dots).
/// Videos autoplay (muted) while the post is on screen and pause when it
/// scrolls away.
class PostMediaCarousel extends StatefulWidget {
  const PostMediaCarousel({
    super.key,
    required this.postId,
    required this.media,
    this.height = 420,
  });

  final String postId;
  final List<FeedMedia> media;
  final double height;

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final _pages = PageController();
  int _page = 0;
  bool _visible = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final many = widget.media.length > 1;
    return VisibilityDetector(
      key: ValueKey('vis-${widget.postId}'),
      onVisibilityChanged: (info) {
        final v = info.visibleFraction > 0.6;
        if (v != _visible && mounted) setState(() => _visible = v);
      },
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: widget.media.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final m = widget.media[i];
                  return m.isVideo
                      ? _VideoPage(media: m, active: _visible && _page == i)
                      : _ImagePage(media: m);
                },
              ),
              if (many) ...[
                // Counter
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_page + 1}/${widget.media.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Arrows
                if (_page > 0)
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _RoundButton(
                        icon: Icons.chevron_left,
                        tooltip: 'Previous',
                        onTap: () => _go(_page - 1),
                      ),
                    ),
                  ),
                if (_page < widget.media.length - 1)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _RoundButton(
                        icon: Icons.chevron_right,
                        tooltip: 'Next',
                        onTap: () => _go(_page + 1),
                      ),
                    ),
                  ),
                // Dots
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.media.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _page ? 18 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page ? Colors.white : Colors.white60,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Blurred, darkened copy of an image filling the whole area.
class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
        Container(color: Colors.black.withValues(alpha: 0.28)),
      ],
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.media});

  final FeedMedia media;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _BlurredBackground(asset: media.thumb),
        Center(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                media.url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.media, required this.active});

  final FeedMedia media;

  /// True when this video is on screen and is the current carousel page.
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _c = VideoPlayerController.asset(
    widget.media.url,
  );
  bool _ready = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    feedMuted.addListener(_applyVolume);
    _c.initialize().then((_) async {
      if (!mounted) return;
      await _c.setLooping(true);
      _applyVolume();
      setState(() => _ready = true);
      _sync();
    });
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (widget.active) _userPaused = false;
      _sync();
    }
  }

  void _applyVolume() => _c.setVolume(feedMuted.value ? 0 : 1);

  void _sync() {
    if (!_ready) return;
    if (widget.active && !_userPaused) {
      _c.play();
    } else {
      _c.pause();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    feedMuted.removeListener(_applyVolume);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _ready && _c.value.isPlaying;
    return Stack(
      fit: StackFit.expand,
      children: [
        _BlurredBackground(asset: widget.media.thumb),
        Center(
          child: _ready
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: AspectRatio(
                      aspectRatio: _c.value.aspectRatio,
                      child: VideoPlayer(_c),
                    ),
                  ),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
        // Tap to pause / play.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _userPaused = playing;
              _sync();
            },
          ),
        ),
        if (_ready && !playing)
          const Center(
            child: IgnorePointer(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: ValueListenableBuilder<bool>(
            valueListenable: feedMuted,
            builder: (_, muted, _) => _RoundButton(
              icon: muted ? Icons.volume_off : Icons.volume_up,
              tooltip: muted ? 'Turn sound on' : 'Mute',
              onTap: () => feedMuted.value = !muted,
              small: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final d = small ? 34.0 : 38.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70),
          ),
          child: Icon(icon, color: Colors.white, size: small ? 18 : 24),
        ),
      ),
    );
  }
}
