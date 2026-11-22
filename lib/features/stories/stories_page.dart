import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
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
  late List<DemoPost> _feed = _shuffleFeed();

  /// Story playing in the right-hand panel (Simplified, desktop).
  List<DemoStory>? _playList;
  int _playIndex = 0;
  bool _playMine = false;
  int _playKey = 0;

  String? get _activeName => _playList == null
      ? null
      : (_playMine ? 'My Stories' : _playList![_playIndex].name);

  void _play(List<DemoStory> list, int index, {bool mine = false}) {
    if (screenSizeOf(context) != ScreenSize.desktop) {
      showStoryViewer(context, stories: list, startIndex: index, isMine: mine);
      return;
    }
    setState(() {
      _playList = list;
      _playIndex = index;
      _playMine = mine;
      _playKey++;
    });
  }

  void _stop() => setState(() => _playList = null);

  /// For You: posts shuffled each time the tab opens.
  List<DemoPost> _shuffleFeed() => List.of(demoPosts)..shuffle();

  DemoStory get _myStory =>
      DemoStory(name: demoCurrentUserName, time: 'Just now', items: _myItems);

  Future<void> _addStory() async {
    final item = await showDialog<StoryItem>(
      context: context,
      builder: (_) => const _AddStoryDialog(),
    );
    if (item == null || !mounted) return;
    setState(() => _myItems.add(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Story posted')));
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final menu = _StoriesMenu(
      selected: _tab,
      onSelect: (t) => setState(() {
        _tab = t;
        _playList = null;
        if (t == _Tab.forYou) _feed = _shuffleFeed();
      }),
    );
    final Widget body = switch (_tab) {
      _Tab.simplified => _Simplified(
        query: _q,
        myItems: _myItems,
        onSearch: (v) => setState(() => _q = v.trim().toLowerCase()),
        activeName: _activeName,
        onOpen: (s) => _play(demoStories, demoStories.indexOf(s)),
        onMyStory: () =>
            _myItems.isEmpty ? _addStory() : _play([_myStory], 0, mine: true),
        onAddStory: _addStory,
      ),
      _Tab.forYou => _ForYou(feed: _feed),
      _Tab.privacy => const _StoryPrivacy(),
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
    required this.myItems,
    required this.activeName,
    required this.onSearch,
    required this.onOpen,
    required this.onMyStory,
    required this.onAddStory,
  });

  final String query;
  final List<StoryItem> myItems;
  final String? activeName;
  final ValueChanged<DemoStory> onOpen;
  final ValueChanged<String> onSearch;
  final VoidCallback onMyStory;
  final VoidCallback onAddStory;

  @override
  Widget build(BuildContext context) {
    final list = demoStories
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
              : '${myItems.length} ${myItems.length == 1 ? 'story' : 'stories'} · Just now',
          ring: myItems.isNotEmpty,
          active: activeName == 'My Stories',
          avatar: const Avatar(name: demoCurrentUserName, size: 72),
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
              avatar: Avatar(name: s.name, color: s.color, size: 72),
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
              avatar: Avatar(name: s.name, color: s.color, size: 72),
              chevron: true,
              onTap: () => open(s),
            ),
        ],
        if (list.isEmpty)
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
  const _ForYou({required this.feed});

  final List<DemoPost> feed;

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
        if (items.isEmpty)
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
              key: ValueKey('post-${demoPosts.indexOf(widget.feed[i])}'),
              post: widget.feed[i],
              seed: i,
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
  });

  final DemoPost post;
  final int seed;
  final VoidCallback onHide;

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost> {
  // Reaction counts: heart, call-me hand, laughing (same set as mobile).
  late final List<int> _counts = [
    (widget.seed * 3 + 1) % 5,
    (widget.seed * 2) % 3,
    widget.seed % 2,
  ];
  int? _mine;

  void _react(int r) => setState(() {
    if (_mine == r) {
      _counts[r]--;
      _mine = null;
    } else {
      if (_mine != null) _counts[_mine!]--;
      _counts[r]++;
      _mine = r;
    }
  });

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
                  child: Avatar(name: s.name, color: s.color, size: 54),
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
                      _toast('$v is coming soon.');
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
                          colors: [
                            post.background,
                            Color.lerp(post.background, Colors.white, 0.45)!,
                          ],
                        ),
                      ),
                      child: Text(
                        post.text!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : PostMediaCarousel(
                    postId: 'post-${demoPosts.indexOf(post)}',
                    media: post.media,
                  ),
          ),

          // Reactions + Share
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                _ReactionButton(
                  icon: Icon(
                    _mine == 0 ? Icons.favorite : Icons.favorite_border,
                    color: const Color(0xFFE91E4D),
                    size: 28,
                  ),
                  count: _counts[0],
                  active: _mine == 0,
                  activeColor: const Color(0xFFE91E4D),
                  onTap: () => _react(0),
                ),
                _ReactionButton(
                  icon: const Text('🤙', style: TextStyle(fontSize: 24)),
                  count: _counts[1],
                  active: _mine == 1,
                  onTap: () => _react(1),
                ),
                _ReactionButton(
                  icon: const Text('😂', style: TextStyle(fontSize: 24)),
                  count: _counts[2],
                  active: _mine == 2,
                  onTap: () => _react(2),
                ),
                const Spacer(),
                Material(
                  color: const Color(0xFFF1EEF6),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _toast('Share is coming soon.'),
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
      padding: const EdgeInsets.only(right: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
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
  const _StoryPrivacy();

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

  @override
  Widget build(BuildContext context) {
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
                  onSelected: (_) => setState(() => _hours = h),
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
                onSelected: (_) => setState(() => _random = false),
              ),
              ChoiceChip(
                label: const Text('Default Randomly'),
                selected: _random,
                selectedColor: AppColors.accentSoft,
                onSelected: (_) => setState(() => _random = true),
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
              _radio('custom', 'Custom', 'Choose specific people'),
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
                (v) => setState(() => _download = v),
              ),
              _switch(
                'Allow Replies',
                'Let others reply to your stories.',
                _replies,
                (v) => setState(() => _replies = v),
              ),
              _switch(
                'Show Location',
                'Add location to your stories.',
                _location,
                (v) => setState(() => _location = v),
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
        setState(() => _who = value);
        if (value == 'custom') {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Choosing specific people is coming soon.'),
              ),
            );
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

class _AddStoryDialog extends StatefulWidget {
  const _AddStoryDialog();

  @override
  State<_AddStoryDialog> createState() => _AddStoryDialogState();
}

class _AddStoryDialogState extends State<_AddStoryDialog> {
  static const _colors = [
    Color(0xFF7A2BE8),
    Color(0xFF0E8BAB),
    Color(0xFFED50E4),
    Color(0xFF3B82F6),
    Color(0xFF1F2937),
    Color(0xFF16A34A),
  ];

  bool _writing = false;
  Color _bg = _colors.first;
  final _text = TextEditingController();
  int _hours = 24;
  bool _comments = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _soon(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: _writing ? _composer() : _options(),
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
            'Share a moment with your friend',
            style: TextStyle(color: AppColors.meta),
          ),
        ),
        Row(
          children: [
            tile(
              Icons.photo_library_outlined,
              'Gallery',
              () => _soon('Photo stories'),
            ),
            tile(
              Icons.photo_camera_outlined,
              'Camera',
              () => _soon('Camera stories'),
            ),
            tile(
              Icons.text_fields_rounded,
              'Text',
              () => setState(() => _writing = true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _composer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Text story', onBack: () => setState(() => _writing = false)),
        const SizedBox(height: 6),
        Container(
          height: 220,
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLines: null,
            maxLength: 200,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: 'Type a status',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              counterStyle: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() => _bg = c),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == c ? AppColors.heading : Colors.white,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _optionRow(
          Icons.public,
          'Privacy',
          trailing: const Text(
            'Everyone',
            style: TextStyle(color: AppColors.meta),
          ),
        ),
        _optionRow(
          Icons.timer_outlined,
          'Story Duration',
          trailing: DropdownButton<int>(
            value: _hours,
            underline: const SizedBox.shrink(),
            items: [
              for (final h in const [12, 24, 36, 52])
                DropdownMenuItem(value: h, child: Text('$h Hours')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 24),
          ),
        ),
        _optionRow(
          Icons.chat_bubble_outline,
          'Comments',
          subtitle: 'Allow people to comment',
          trailing: Switch(
            value: _comments,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => setState(() => _comments = v),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _text.text.trim().isEmpty
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(StoryItem.text(_text.text.trim(), _bg)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
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
