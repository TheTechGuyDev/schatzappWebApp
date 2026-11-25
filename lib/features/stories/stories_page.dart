import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/web_auth.dart';
import '../../data/demo_data.dart';
import '../../data/live/chat_repo.dart';
import '../../data/live/stories_repo.dart';
import '../../platform/camera_dialog.dart';
import '../../platform/web_files.dart';
import '../chats/chat_dialogs.dart';
import '../chats/chats_page.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/nav_icons.dart';
import 'feed_media.dart';
import 'story_viewer.dart';

/// Stories tab (Stories UI image): Simplified, For You and Story Privacy.
/// Content mirrors the mobile app (users_story, view_your_stories,
/// create_a_story, story_settings_page). Placeholder data for now.
class StoriesPage extends StatefulWidget {
  const StoriesPage({super.key});

  static const routePath = '/stories';

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

enum _Tab { simplified, forYou, privacy }

class _StoriesPageState extends State<StoriesPage> {
  _Tab _tab = _Tab.simplified;
  String _q = '';
  final List<StoryItem> _myItems = [];
  late List<DemoPost> _feed = _live ? const [] : _shuffleFeed();

  bool get _live => WebAuth.instance.isLive;
  StoriesRepo get _repo => StoriesRepo.instance;

  // Live data
  List<DemoStory> _friends = const [];
  DemoStory? _mine;
  bool _loading = true;
  bool _feedLoading = false;

  List<DemoStory> get _stories => _live ? _friends : demoStories;

  /// Story playing in the right-hand panel (Simplified, desktop).
  List<DemoStory>? _playList;
  int _playIndex = 0;
  bool _playMine = false;
  int _playKey = 0;

  String? get _activeName => _playList == null
      ? null
      : (_playMine ? 'My Stories' : _playList![_playIndex].name);

  @override
  void initState() {
    super.initState();
    if (_live) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_repo.friends(), _repo.mine()]);
      if (!mounted) return;
      setState(() {
        _friends = r[0] as List<DemoStory>;
        _mine = r[1] as DemoStory;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load stories. Check your connection.');
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _feedLoading = true);
    try {
      final f = await _repo.forYou();
      if (mounted) setState(() => _feed = f);
    } catch (_) {
      _toast('Could not load For You. Check your connection.');
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  void _toast(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  StoryHooks get _hooks => !_live
      ? const StoryHooks()
      : StoryHooks(
          onViewed: (s, item) => _repo.markViewed(item.id),
          onReply: (s, item, text) => _repo.reply(s.userId!, item, text),
          onReact: (item, type) => _repo.toggleReaction(item.id, type),
          reactions: (item) async => (await _repo.reactions(item.id)).mine,
          onViewers: _showViewers,
          onDelete: (item) async {
            await _repo.delete(item.id);
            _stop();
            await _load();
          },
        );

  Future<void> _showViewers(StoryItem item) async {
    final list = await _repo
        .viewers(item.id)
        .catchError((Object _) => <StoryViewer>[]);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => DialogShell(
        title: 'Viewed by ${list.length}',
        width: 400,
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, 30),
                child: Text(
                  'No one has viewed this story yet.',
                  style: TextStyle(color: AppColors.meta),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                children: [
                  for (final v in list)
                    _ViewerRow(
                      viewer: v,
                      onMessage: () {
                        // Close this list and the story player (phone size).
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).popUntil((r) => r is! PopupRoute);
                        _messageViewer(v);
                      },
                    ),
                ],
              ),
      ),
    );
  }

  /// Opens my chat with someone who viewed my story.
  void _messageViewer(StoryViewer v) {
    if (v.userId.isEmpty) return;
    _stop();
    ChatsPage.openWith = DemoContact(v.name, '', null, v.userId, v.avatarUrl);
    context.go(ChatsPage.routePath);
  }

  void _play(List<DemoStory> list, int index, {bool mine = false}) {
    if (screenSizeOf(context) != ScreenSize.desktop) {
      showStoryViewer(
        context,
        stories: list,
        startIndex: index,
        isMine: mine,
        hooks: _hooks,
      ).then((_) {
        if (_live) _load();
      });
      return;
    }
    setState(() {
      _playList = list;
      _playIndex = index;
      _playMine = mine;
      _playKey++;
    });
  }

  void _stop() {
    setState(() => _playList = null);
    if (_live) _load();
  }

  /// For You: posts shuffled each time the tab opens.
  List<DemoPost> _shuffleFeed() => List.of(demoPosts)..shuffle();

  DemoStory get _myStory => _live && _mine != null
      ? _mine!
      : DemoStory(name: demoCurrentUserName, time: 'Just now', items: _myItems);

  List<StoryItem> get _myStoryItems =>
      _live ? (_mine?.items ?? const []) : _myItems;

  Future<void> _addStory() async {
    final item = await showDialog<Object>(
      context: context,
      builder: (_) => _AddStoryDialog(live: _live),
    );
    if (item == null || !mounted) return;
    if (_live) {
      await _load();
      _toast('Story posted');
      return;
    }
    if (item is StoryItem) setState(() => _myItems.add(item));
    _toast('Story posted');
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final menu = _StoriesMenu(
      selected: _tab,
      onSelect: (t) {
        setState(() {
          _tab = t;
          _playList = null;
          if (t == _Tab.forYou && !_live) _feed = _shuffleFeed();
        });
        if (t == _Tab.forYou && _live) _loadFeed();
      },
    );
    final Widget body = switch (_tab) {
      _Tab.simplified => _Simplified(
        query: _q,
        stories: _stories,
        loading: _live && _loading,
        myItems: _myStoryItems,
        myName: _live
            ? '${ChatRepo.instance.me?['full_name'] ?? 'Me'}'
            : demoCurrentUserName,
        myPhoto: _live
            ? (ChatRepo.instance.me?['avatar_url'] as String?)
            : null,
        myTime: _live ? (_mine?.time ?? '') : 'Just now',
        onSearch: (v) => setState(() => _q = v.trim().toLowerCase()),
        activeName: _activeName,
        onOpen: (s) => _play(_stories, _stories.indexOf(s)),
        onMyStory: () => _myStoryItems.isEmpty
            ? _addStory()
            : _play([_myStory], 0, mine: true),
        onAddStory: _addStory,
      ),
      _Tab.forYou => _ForYou(feed: _feed, loading: _feedLoading, live: _live),
      _Tab.privacy => _StoryPrivacy(live: _live),
    };

    if (size == ScreenSize.phone) {
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(height: 60, child: menu.horizontal()),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: size == ScreenSize.desktop ? 300 : 250,
            child: ShellPanel(child: menu),
          ),
          const SizedBox(width: 12),
          Expanded(child: ShellPanel(child: body)),
          if (_playList != null && _tab == _Tab.simplified) ...[
            const SizedBox(width: 12),
            LayoutBuilder(
              builder: (context, c) {
                // Phone-like 9:16 card that fits the panel height.
                final w = (c.maxHeight * 9 / 16).clamp(300.0, 400.0);
                return Container(
                  width: w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandDeep.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: StoryPlayer(
                    key: ValueKey('player-$_playKey'),
                    stories: _playList!,
                    startIndex: _playIndex,
                    isMine: _playMine,
                    hooks: _hooks,
                    onClose: _stop,
                    onPersonChanged: (i) => setState(() => _playIndex = i),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

const _menuItems = [
  (_Tab.simplified, Icons.motion_photos_on_outlined, 'Simplified'),
  (_Tab.forYou, Icons.play_circle_outline, 'For You'),
  (_Tab.privacy, Icons.lock_outline_rounded, 'Story Privacy'),
];

class _StoriesMenu extends StatelessWidget {
  const _StoriesMenu({required this.selected, required this.onSelect});

  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  Widget horizontal() => ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    children: [
      for (final m in _menuItems)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(m.$3),
            selected: selected == m.$1,
            onSelected: (_) => onSelect(m.$1),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 70, 12, 12),
      children: [
        for (final m in _menuItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: selected == m.$1
                  ? const Color(0xFFF1E6FE)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(m.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      m.$1 == _Tab.simplified
                          ? NavIcon(
                              NavIconKind.stories,
                              color: selected == m.$1
                                  ? AppColors.accent
                                  : AppColors.heading,
                              size: 26,
                            )
                          : Icon(
                              m.$2,
                              color: selected == m.$1
                                  ? AppColors.accent
                                  : AppColors.heading,
                              size: 26,
                            ),
                      const SizedBox(width: 14),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: selected == m.$1
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected == m.$1
                              ? AppColors.accent
                              : AppColors.heading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Simplified
// ---------------------------------------------------------------------------

class _Simplified extends StatelessWidget {
  const _Simplified({
    required this.query,
    required this.stories,
    required this.myName,
    required this.myTime,
    this.myPhoto,
    this.loading = false,
    required this.myItems,
    required this.activeName,
    required this.onSearch,
    required this.onOpen,
    required this.onMyStory,
    required this.onAddStory,
  });

  final String query;
  final List<DemoStory> stories;
  final String myName;
  final String? myPhoto;
  final String myTime;
  final bool loading;
  final List<StoryItem> myItems;
  final String? activeName;
  final ValueChanged<DemoStory> onOpen;
  final ValueChanged<String> onSearch;
  final VoidCallback onMyStory;
  final VoidCallback onAddStory;

  @override
  Widget build(BuildContext context) {
    final list = stories
        .where((s) => query.isEmpty || s.name.toLowerCase().contains(query))
        .toList();
    final recent = list.where((s) => !s.viewed).toList();
    final viewed = list.where((s) => s.viewed).toList();

    void open(DemoStory s) => onOpen(s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      children: [
        const Text(
          'Stories',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'Search friends',
            hintStyle: const TextStyle(color: AppColors.meta),
            prefixIcon: const Icon(Icons.search, color: AppColors.heading),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFD5D1DE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // My Stories
        _StoryRow(
          name: 'My Stories',
          subtitle: myItems.isEmpty
              ? 'Tap to add a story'
              : '${myItems.length} ${myItems.length == 1 ? 'story' : 'stories'}${myTime.isEmpty ? '' : ' · $myTime'}',
          ring: myItems.isNotEmpty,
          active: activeName == 'My Stories',
          avatar: Avatar(name: myName, photoUrl: myPhoto, size: 72),
          badge: true,
          onTap: onMyStory,
          onBadge: onAddStory,
        ),
        const Divider(height: 28, color: AppColors.border),
        if (recent.isNotEmpty) ...[
          const _SectionLabel('Recent stories'),
          for (final s in recent)
            _StoryRow(
              name: s.name,
              subtitle: s.time,
              ring: true,
              active: activeName == s.name,
              avatar: Avatar(
                name: s.name,
                color: s.color,
                photoUrl: s.avatarUrl,
                size: 72,
              ),
              chevron: true,
              onTap: () => open(s),
            ),
        ],
        if (viewed.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SectionLabel('Viewed stories'),
          for (final s in viewed)
            _StoryRow(
              name: s.name,
              subtitle: s.time,
              ring: false,
              active: activeName == s.name,
              avatar: Avatar(
                name: s.name,
                color: s.color,
                photoUrl: s.avatarUrl,
                size: 72,
              ),
              chevron: true,
              onTap: () => open(s),
            ),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'No stories to show right now',
                style: TextStyle(color: AppColors.meta),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.body,
        ),
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.name,
    required this.subtitle,
    required this.ring,
    required this.avatar,
    required this.onTap,
    this.badge = false,
    this.chevron = false,
    this.active = false,
    this.onBadge,
  });

  final bool active;

  final String name;
  final String subtitle;
  final bool ring;
  final Widget avatar;
  final VoidCallback onTap;
  final bool badge;
  final bool chevron;
  final VoidCallback? onBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFF1E6FE) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ring
                              ? AppColors.accent
                              : const Color(0xFFD5D1DE),
                          width: 2.5,
                        ),
                      ),
                      child: avatar,
                    ),
                    if (badge)
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onBadge,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accentDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.meta,
                      ),
                    ),
                  ],
                ),
              ),
              if (chevron)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.heading,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// For You
// ---------------------------------------------------------------------------

class _ForYou extends StatefulWidget {
  const _ForYou({required this.feed, this.loading = false, this.live = false});

  final List<DemoPost> feed;
  final bool loading;
  final bool live;

  @override
  State<_ForYou> createState() => _ForYouState();
}

class _ForYouState extends State<_ForYou> {
  String _q = '';
  final Set<int> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < widget.feed.length; i++)
        if (!_hidden.contains(i) &&
            (_q.isEmpty ||
                widget.feed[i].author.name.toLowerCase().contains(_q)))
          i,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Stories',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search friends',
              hintStyle: const TextStyle(color: AppColors.meta),
              prefixIcon: const Icon(Icons.search, color: AppColors.heading),
              filled: true,
              fillColor: const Color(0xFFF8F6FC),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFD5D1DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No Stories to show right now',
                style: TextStyle(color: AppColors.meta),
              ),
            ),
          ),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FeedPost(
              key: ValueKey(
                widget.live
                    ? 'post-${widget.feed[i].statusIds.join()}'
                    : 'post-${demoPosts.indexOf(widget.feed[i])}',
              ),
              post: widget.feed[i],
              seed: i,
              live: widget.live,
              onHide: () => setState(() => _hidden.add(i)),
            ),
          ),
      ],
    );
  }
}

/// One For You post (mobile For You card): header, story, reactions, Share.
class _FeedPost extends StatefulWidget {
  const _FeedPost({
    super.key,
    required this.post,
    required this.seed,
    required this.onHide,
    this.live = false,
  });

  final DemoPost post;
  final int seed;
  final VoidCallback onHide;
  final bool live;

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost> {
  // Reactions: ❤️ ✌️ 😂 😢 😠, at most 2 per user.
  static const _types = StoriesRepo.reactionTypes;
  late final List<int> _counts = widget.live
      ? List.filled(_types.length, 0)
      : [
          (widget.seed * 3 + 1) % 5,
          (widget.seed * 2) % 3,
          widget.seed % 2,
          (widget.seed + 1) % 2,
          0,
        ];
  final Set<int> _mineSet = {};

  String? get _statusId =>
      widget.post.statusIds.isEmpty ? null : widget.post.statusIds.first;

  @override
  void initState() {
    super.initState();
    final id = _statusId;
    if (widget.live && id != null) {
      StoriesRepo.instance
          .reactions(id)
          .then((r) {
            if (!mounted) return;
            setState(() {
              for (var i = 0; i < _types.length; i++) {
                _counts[i] = r.counts[_types[i]] ?? 0;
                if (r.mine.contains(_types[i])) _mineSet.add(i);
              }
            });
          })
          .catchError((Object _) {});
      // Seeing a post counts as viewing that story, like the phone.
      for (final s in widget.post.statusIds) {
        StoriesRepo.instance.markViewed(s);
      }
    }
  }

  /// When each reaction was added in this session (preview lock check).
  final Map<int, DateTime> _addedAt = {};

  Future<void> _react(int r) async {
    final was = _mineSet.contains(r);
    if (!was && _mineSet.length >= StoriesRepo.maxReactionsPerUser) {
      _toast(ReactionLimitException.message);
      return;
    }
    if (was && !widget.live) {
      final at = _addedAt[r];
      if (at == null ||
          DateTime.now().difference(at) > StoriesRepo.reactionLockAfter) {
        _toast(ReactionLockedException.message);
        return;
      }
    }
    if (!was) _addedAt[r] = DateTime.now();
    setState(() {
      was ? _mineSet.remove(r) : _mineSet.add(r);
      _counts[r] += was ? -1 : 1;
    });
    final id = _statusId;
    if (!widget.live || id == null) return;
    try {
      await StoriesRepo.instance.toggleReaction(id, _types[r]);
    } catch (e) {
      if (!mounted) return;
      if (e is ReactionLockedException || e is ReactionLimitException) {
        _toast('$e');
      }
      setState(() {
        was ? _mineSet.add(r) : _mineSet.remove(r);
        _counts[r] += was ? 1 : -1;
      });
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final s = post.author;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: Avatar(
                    name: s.name,
                    color: s.color,
                    photoUrl: s.avatarUrl,
                    size: 54,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.time,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.meta,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert, color: AppColors.body),
                  onSelected: (v) {
                    if (v == 'Hide') {
                      widget.onHide();
                      _toast('Story hidden');
                    } else {
                      _toast('$v is available on the mobile app.');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'Get notification',
                      child: Text('Get notification'),
                    ),
                    PopupMenuItem(value: 'Repost', child: Text('Repost')),
                    PopupMenuItem(value: 'Save', child: Text('Save')),
                    PopupMenuItem(value: 'Hide', child: Text('Hide')),
                  ],
                ),
              ],
            ),
          ),

          // Post content: stays in the list (no click to open).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: post.text != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 300,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors:
                              post.gradient ??
                              [
                                post.background,
                                Color.lerp(
                                  post.background,
                                  Colors.white,
                                  0.45,
                                )!,
                              ],
                        ),
                      ),
                      child: Text(
                        post.text!,
                        textAlign: TextAlign.center,
                        style: post.gradient != null
                            ? storyFont(post.fontIndex, size: 30)
                            : const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                    ),
                  )
                : PostMediaCarousel(
                    postId: widget.live
                        ? 'post-${post.statusIds.join()}'
                        : 'post-${demoPosts.indexOf(post)}',
                    media: post.media,
                  ),
          ),

          // Reactions + Share
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _types.length; i++)
                          _ReactionButton(
                            icon: i == 0
                                ? Icon(
                                    _mineSet.contains(0)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: const Color(0xFFE91E4D),
                                    size: 24,
                                  )
                                : Text(
                                    StoriesRepo.reactionEmoji[_types[i]]!,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                            count: _counts[i],
                            active: _mineSet.contains(i),
                            activeColor: i == 0
                                ? const Color(0xFFE91E4D)
                                : AppColors.accent,
                            onTap: () => _react(i),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFF1EEF6),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _toast(
                      'Sharing stories is available on the mobile app.',
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            textDirection: TextDirection.rtl,
                            color: AppColors.body,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.body,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.accent,
  });

  final Widget icon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: active ? activeColor : AppColors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story Privacy (mobile StorySettingsPage)
// ---------------------------------------------------------------------------

class _StoryPrivacy extends StatefulWidget {
  const _StoryPrivacy({this.live = false});

  final bool live;

  @override
  State<_StoryPrivacy> createState() => _StoryPrivacyState();
}

class _StoryPrivacyState extends State<_StoryPrivacy> {
  int _hours = 24;
  bool _random = false;
  String _who = 'everyone';
  bool _download = true;
  bool _replies = true;
  bool _location = false;
  bool _loading = false;
  Set<String> _custom = {};

  StoriesRepo get _repo => StoriesRepo.instance;

  @override
  void initState() {
    super.initState();
    if (widget.live) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.settings();
      final c = await _repo.customViewers();
      if (!mounted) return;
      setState(() {
        _hours = s.durationHours;
        _random = s.sortOrder == 'random';
        _who = s.viewVisibility == 'phone_number' ? 'phone' : s.viewVisibility;
        _download = s.allowDownload;
        _replies = s.allowReplies;
        _location = s.showLocation;
        _custom = c;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Saves right away, like the phone.
  Future<void> _save() async {
    if (!widget.live) return;
    try {
      await _repo.saveSettings(
        StorySettings(
          durationHours: _hours,
          sortOrder: _random ? 'random' : 'time',
          viewVisibility: _who == 'phone' ? 'phone_number' : _who,
          allowDownload: _download,
          allowReplies: _replies,
          showLocation: _location,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    _save();
  }

  Future<void> _pickCustom() async {
    if (!widget.live) {
      setState(() => _who = 'custom');
      return;
    }
    final contacts = await ChatRepo.instance.contacts();
    if (!mounted) return;
    final picked = await showDialog<List<DemoContact>>(
      context: context,
      builder: (_) => ContactPickerDialog(
        title: 'Who can see my stories',
        multiSelect: true,
        actionLabel: 'Save',
        load: () async => contacts,
      ),
    );
    if (picked == null || !mounted) return;
    final ids = {for (final c in picked) ?c.userId};
    try {
      await _repo.setCustomViewers(ids);
      _custom = ids;
      _set(() => _who = 'custom');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      children: [
        const Text(
          'Story Settings',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Control how your stories are shared and who can see them.',
          style: TextStyle(fontSize: 15, color: AppColors.meta),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Stories Lasting Hours',
          subtitle: 'Choose how long your story will be visible.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final h in const [24, 12, 36, 52])
                ChoiceChip(
                  label: Text('$h Hours'),
                  selected: _hours == h,
                  selectedColor: AppColors.accentSoft,
                  onSelected: (_) => _set(() => _hours = h),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Stories Appearance',
          subtitle: 'Choose how your stories are displayed.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Default by Time'),
                selected: !_random,
                selectedColor: AppColors.accentSoft,
                onSelected: (_) => _set(() => _random = false),
              ),
              ChoiceChip(
                label: const Text('Default Randomly'),
                selected: _random,
                selectedColor: AppColors.accentSoft,
                onSelected: (_) => _set(() => _random = true),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Who Can View Your Stories',
          subtitle: 'Control who can see your stories.',
          child: Column(
            children: [
              _radio(
                'everyone',
                'Everyone',
                'All your followers and connections.',
                recommended: true,
              ),
              _radio('phone', 'Phone Number', 'People with my number.'),
              _radio(
                'custom',
                'Custom',
                _who == 'custom' && _custom.isNotEmpty
                    ? '${_custom.length} people chosen. Tap to change.'
                    : 'Choose specific people',
              ),
            ],
          ),
        ),
        _Section(
          title: 'Additional Options',
          child: Column(
            children: [
              _switch(
                'Allow Download',
                'Let others save your stories.',
                _download,
                (v) => _set(() => _download = v),
              ),
              _switch(
                'Allow Replies',
                'Let others reply to your stories.',
                _replies,
                (v) => _set(() => _replies = v),
              ),
              _switch(
                'Show Location',
                'Add location to your stories.',
                _location,
                (v) => _set(() => _location = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radio(
    String value,
    String title,
    String subtitle, {
    bool recommended = false,
  }) {
    final on = _who == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (value == 'custom') {
          _pickCustom();
        } else {
          _set(() => _who = value);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: on ? AppColors.accent : AppColors.meta,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.meta,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.meta),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13.5, color: AppColors.meta),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add to your story (mobile view_your_stories + create_a_story)
// ---------------------------------------------------------------------------

/// The phone's text-story backgrounds (two-colour gradients).
const _storyGradients = [
  [Color(0xFFA1C4FD), Color(0xFFC2E9FB)],
  [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
  [Color(0xFFFDCBF1), Color(0xFFE6DEE9)],
  [Color(0xFFD4FC79), Color(0xFF96E6A1)],
  [Color(0xFFFFECD2), Color(0xFFFCB69F)],
  [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
  [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
  [Color(0xFFFFDEE9), Color(0xFFB5FFFC)],
  [Color(0xFFF6D365), Color(0xFFFDA085)],
  [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
];

class _AddStoryDialog extends StatefulWidget {
  const _AddStoryDialog({this.live = false});

  final bool live;

  @override
  State<_AddStoryDialog> createState() => _AddStoryDialogState();
}

enum _Step { options, text, media }

class _AddStoryDialogState extends State<_AddStoryDialog> {
  _Step _step = _Step.options;
  int _bg = 0;
  int _font = 0;
  final _text = TextEditingController();
  final _caption = TextEditingController();
  bool _comments = true;
  bool _busy = false;
  PickedFile? _file;

  @override
  void dispose() {
    _text.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _pickMedia() async {
    if (!widget.live) {
      _toast('Sign in with your phone to post photos and videos.');
      return;
    }
    final files = await pickFiles(accept: 'image/*,video/*');
    if (files.isEmpty) return;
    final f = files.first;
    if (f.isVideo && f.bytes.length > 64 * 1024 * 1024) {
      _toast('Videos must be under 64 MB.');
      return;
    }
    setState(() {
      _file = f;
      _step = _Step.media;
    });
  }

  Future<void> _camera() async {
    if (!widget.live) {
      _toast('Sign in with your phone to post photos.');
      return;
    }
    final bytes = await takeCameraPhoto(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _file = PickedFile(
        name: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
        mime: 'image/jpeg',
      );
      _step = _Step.media;
    });
  }

  Future<void> _post() async {
    if (_busy) return;
    if (!widget.live) {
      Navigator.of(context)
          .pop(StoryItem.text(_text.text.trim(), _storyGradients[_bg].first));
      return;
    }
    setState(() => _busy = true);
    try {
      if (_step == _Step.text) {
        await StoriesRepo.instance.postText(
          _text.text.trim(),
          _storyGradients[_bg],
          fontIndex: _font,
          comments: _comments,
        );
      } else if (_file != null) {
        await StoriesRepo.instance.postMedia(
          _file!,
          caption: _caption.text.trim(),
          comments: _comments,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not post your story. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: switch (_step) {
            _Step.options => _options(),
            _Step.text => _composer(),
            _Step.media => _mediaComposer(),
          },
        ),
      ),
    );
  }

  Widget _header(String title, {VoidCallback? onBack}) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack ?? () => Navigator.of(context).pop(),
          icon: Icon(onBack != null ? Icons.arrow_back : Icons.close),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
          ),
        ),
      ],
    );
  }

  Widget _options() {
    Widget tile(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.lavenderSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6DAFA)),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.accent, size: 30),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Add to your story'),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Text(
            'Share a moment with your friends',
            style: TextStyle(color: AppColors.meta),
          ),
        ),
        Row(
          children: [
            tile(Icons.photo_library_outlined, 'Gallery', _pickMedia),
            tile(Icons.photo_camera_outlined, 'Camera', _camera),
            tile(
              Icons.text_fields_rounded,
              'Text',
              () => setState(() => _step = _Step.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentsRow() => _optionRow(
    Icons.chat_bubble_outline,
    'Comments',
    subtitle: 'Allow people to reply',
    trailing: Switch(
      value: _comments,
      activeThumbColor: AppColors.accent,
      onChanged: (v) => setState(() => _comments = v),
    ),
  );

  Widget _postButton(bool enabled) => SizedBox(
    height: 48,
    child: FilledButton(
      onPressed: enabled && !_busy ? _post : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    ),
  );

  Widget _composer() {
    final g = _storyGradients[_bg];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'Text story',
          onBack: () => setState(() => _step = _Step.options),
        ),
        const SizedBox(height: 6),
        Container(
          height: 240,
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: g,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLines: null,
            maxLength: 200,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: storyFont(_font, size: 26),
            decoration: const InputDecoration(
              hintText: 'Type a status',
              hintStyle: TextStyle(color: Color(0x992D2D2D)),
              border: InputBorder.none,
              counterStyle: TextStyle(color: Color(0x992D2D2D)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _storyGradients.length; i++)
              GestureDetector(
                onTap: () => setState(() => _bg = i),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _storyGradients[i]),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == i ? AppColors.heading : Colors.white,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 10; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Aa', style: storyFont(i, size: 15)),
                    selected: _font == i,
                    selectedColor: AppColors.accentSoft,
                    onSelected: (_) => setState(() => _font = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _commentsRow(),
        const SizedBox(height: 10),
        _postButton(_text.text.trim().isNotEmpty),
      ],
    );
  }

  Widget _mediaComposer() {
    final f = _file;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          f?.isVideo == true ? 'Video story' : 'Photo story',
          onBack: () => setState(() {
            _file = null;
            _step = _Step.options;
          }),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 300,
            color: const Color(0xFF1E1530),
            alignment: Alignment.center,
            child: f == null
                ? const SizedBox.shrink()
                : f.isImage
                ? Image.memory(f.bytes, fit: BoxFit.contain)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f.name,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Add a caption',
            filled: true,
            fillColor: AppColors.lavenderSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        _commentsRow(),
        const SizedBox(height: 10),
        _postButton(f != null),
      ],
    );
  }

  Widget _optionRow(
    IconData icon,
    String title, {
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.meta,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// A row in "Viewed by": their reactions, then "..." (Accept / Decline) when
/// they sent me a request I haven't answered, or a message icon.
class _ViewerRow extends StatefulWidget {
  const _ViewerRow({required this.viewer, required this.onMessage});

  final StoryViewer viewer;
  final VoidCallback onMessage;

  @override
  State<_ViewerRow> createState() => _ViewerRowState();
}

class _ViewerRowState extends State<_ViewerRow> {
  late String? _requestId = widget.viewer.requestId;
  bool _declined = false;
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    final id = _requestId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await StoriesRepo.instance.respondRequest(id, accept);
      _toast(
        accept
            ? "Accepted. You can now see each other's stories and message."
            : 'Declined',
      );
      _requestId = null;
      _declined = !accept;
    } catch (_) {
      _toast('Could not complete that. Try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _toast(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Widget _emoji(String type) {
    if (type == 'favorite') {
      return const Icon(Icons.favorite, color: Color(0xFFE0245E), size: 22);
    }
    return Text(
      StoriesRepo.reactionEmoji[type] ?? '',
      style: const TextStyle(fontSize: 19, height: 1.1),
    );
  }

  Widget _action() {
    if (_busy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (_declined) return const SizedBox(width: 40, height: 40);
    if (_requestId != null) {
      return SizedBox(
        width: 40,
        height: 40,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'Message request',
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          icon: const Icon(Icons.more_horiz, color: Colors.black87, size: 26),
          onSelected: (v) => _respond(v == 'accept'),
          itemBuilder: (_) => const [
            PopupMenuItem<String>(value: 'accept', child: Text('Accept')),
            PopupMenuItem<String>(value: 'decline', child: Text('Decline')),
          ],
        ),
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: 'Message',
        onPressed: widget.onMessage,
        icon: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: Color(0xFF111B21),
          size: 25,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.viewer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Avatar(name: v.name, photoUrl: v.avatarUrl, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  StoriesRepo.timeAgo(v.at),
                  style: const TextStyle(color: AppColors.meta, fontSize: 13),
                ),
              ],
            ),
          ),
          for (final t in v.reactions)
            Padding(padding: const EdgeInsets.only(right: 6), child: _emoji(t)),
          if (v.reactions.isNotEmpty) const SizedBox(width: 6),
          _action(),
        ],
      ),
    );
  }
}
