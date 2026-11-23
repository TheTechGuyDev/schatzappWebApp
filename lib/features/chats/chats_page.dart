import 'package:material_ui/material_ui.dart';

import '../../auth/web_auth.dart';
import '../../data/demo_data.dart';
import '../../data/live/chat_repo.dart';
import '../../data/live/conversation_feed.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/resizable_width.dart';
import '../../widgets/brand_logo.dart';
import '../calls/call_screen.dart';
import 'chat_dialogs.dart';
import 'composer.dart';
import 'contact_info_panel.dart';
import 'message_bubble.dart';

/// Chats tab (UI image 2). Live data from the same Supabase tables as the
/// phone, kept in sync with Realtime. Demo data only in the UI preview.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  static const routePath = '/chats';

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  ChatFilter _filter = ChatFilter.all;
  String _query = '';
  String? _selectedId = WebAuth.instance.isLive ? null : 'kesta';
  final List<DemoChat> _demoChats = List.of(demoChats);
  final List<DemoChat> _demoPrivate = List.of(demoPrivateChats);

  bool get _live => WebAuth.instance.isLive;
  ChatRepo get _repo => ChatRepo.instance;
  List<DemoChat> get _chats => _live ? _repo.chats : _demoChats;
  List<DemoChat> get _privateChats => _live ? _repo.lockedChats : _demoPrivate;

  /// Live messages of the open chat.
  ConversationFeed? _feed;
  final Map<String, String> _wallpapers = {};

  @override
  void initState() {
    super.initState();
    if (_live) {
      _repo.addListener(_onData);
      _repo.start();
    }
  }

  @override
  void dispose() {
    _repo.removeListener(_onData);
    _feed?.removeListener(_onData);
    _feed?.dispose();
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  void _openFeed(DemoChat c) {
    if (_feed?.conversationId == c.id) return;
    _feed?.removeListener(_onData);
    _feed?.dispose();
    _feed = ConversationFeed(c.id, isGroup: c.isGroup)..addListener(_onData);
    _repo.chatAppearance(c.id).then((a) {
      if (!mounted) return;
      setState(() {
        if (a.$1 != null && a.$1!.isNotEmpty) {
          _themes[c.id] = a.$1!;
        } else {
          _themes.remove(c.id);
        }
        if (a.$2 != null && a.$2!.isNotEmpty) {
          _wallpapers[c.id] = a.$2!;
        } else {
          _wallpapers.remove(c.id);
        }
      });
    });
  }

  final Map<String, List<DemoMessage>> _messages = {
    for (final e in demoMessages.entries) e.key: List.of(e.value),
  };
  final Set<String> _readIds = {};
  final Map<String, String> _themes = {};
  bool _infoOpen = false;
  final _listWidth = PanelWidth('chats_list_width', 350);

  /// Private Chats view is open (after the app password gate).
  bool _privateMode = false;
  bool _privateUnlocked = false;

  List<DemoChat> get _visibleChats {
    final q = _query.trim().toLowerCase();
    bool matches(DemoChat c) =>
        q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        c.preview.toLowerCase().contains(q);

    if (_privateMode) return _privateChats.where(matches).toList();

    // Locked chats are never in this list or in its search results.
    return _chats.where((c) {
      final passFilter = switch (_filter) {
        ChatFilter.all => !c.isArchived,
        ChatFilter.unread => !c.isArchived && _unread(c) > 0,
        ChatFilter.groups => !c.isArchived && c.isGroup,
        ChatFilter.archived => c.isArchived,
      };
      return passFilter && matches(c);
    }).toList();
  }

  int _unread(DemoChat c) => _readIds.contains(c.id) ? 0 : c.unread;

  DemoChat? get _selected {
    for (final c in [..._chats, ..._privateChats]) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  void _open(DemoChat c) {
    setState(() {
      _selectedId = c.id;
      _readIds.add(c.id);
    });
    if (_live) {
      _openFeed(c);
      _repo.markRead(c.id);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _send(String text) {
    final id = _selectedId;
    if (id == null || text.trim().isEmpty) return;
    if (_live) {
      _feed?.sendText(text).catchError((_) {
        _toast('Message not sent. Check your connection and try again.');
      });
      return;
    }
    final now = TimeOfDay.now();
    setState(() {
      (_messages[id] ??= []).add(
        DemoMessage(
          text: text.trim(),
          time: now.format(context),
          isMine: true,
          isRead: false,
        ),
      );
    });
  }

  Future<void> _openPrivate() async {
    if (!_privateUnlocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) =>
            PasswordGateDialog(verify: _live ? _repo.verifyAppPassword : null),
      );
      if (ok != true || !mounted) return;
      _privateUnlocked = true;
    }
    setState(() {
      _privateMode = true;
      _query = '';
    });
  }

  void _closePrivate() => setState(() {
    _privateMode = false;
    _query = '';
    // Leaving Private Chats hides any open private conversation.
    if (_privateChats.any((c) => c.id == _selectedId)) {
      _selectedId = null;
      _infoOpen = false;
    }
  });

  Future<void> _newUser() async {
    if (_live) {
      _toast(
        'Starting new chats on the web is coming next. Use the phone for now.',
      );
      return;
    }
    final picked = await showDialog<List<DemoContact>>(
      context: context,
      builder: (_) => ContactPickerDialog(
        title: _privateMode ? 'New private chat' : 'Friends',
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final contact = picked.first;
    final target = _privateMode ? _privateChats : _chats;
    final existing = target.where((c) => c.name == contact.name);
    if (existing.isNotEmpty) {
      _open(existing.first);
      return;
    }
    final chat = DemoChat(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      name: contact.name,
      preview: '',
      time: 'Now',
      avatarColor: contact.color,
      phone: contact.phone,
    );
    setState(() {
      target.insert(0, chat);
      _selectedId = chat.id;
    });
  }

  Future<void> _newGroup() async {
    if (_live) {
      _toast(
        'Creating groups on the web is coming next. Use the phone for now.',
      );
      return;
    }
    final g = await showDialog<NewGroup>(
      context: context,
      builder: (_) => CreateGroupDialog(privateGroup: _privateMode),
    );
    if (g == null || !mounted) return;
    final chat = DemoChat(
      id: 'grp-${DateTime.now().microsecondsSinceEpoch}',
      name: g.name,
      preview: 'You created this group',
      time: 'Now',
      isGroup: true,
      about: '',
      members: [for (final m in g.members) m.name],
    );
    setState(() {
      (_privateMode || g.isPrivate ? _privateChats : _chats).insert(0, chat);
      _selectedId = chat.id;
    });
    if (g.isPrivate && !_privateMode) {
      _toast('Private group created. Find it in Private Chats.');
    }
  }

  Future<void> _addMembers(DemoChat chat) async {
    final picked = await showDialog<List<DemoContact>>(
      context: context,
      builder: (_) => ContactPickerDialog(
        title: 'Add Members To Group',
        multiSelect: true,
        exclude: chat.members.toSet(),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _toast('${picked.length} member(s) added.');
  }

  Future<void> _pickTheme(DemoChat chat) async {
    final key = await showDialog<String>(
      context: context,
      builder: (_) => ChatThemeDialog(selected: _themes[chat.id]),
    );
    if (key == null || !mounted) return;
    if (_live) {
      try {
        await _repo.setChatTheme(chat.id, key.isEmpty ? null : key);
      } catch (_) {
        _toast('Could not change the theme. Try again.');
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _wallpapers.remove(chat.id);
      if (key.isEmpty) {
        _themes.remove(chat.id);
      } else {
        _themes[chat.id] = key;
      }
    });
    _toast('Background changed');
  }

  void _call(DemoChat chat, bool video) {
    showCallScreen(
      context,
      name: chat.name,
      color: chat.avatarColor,
      isGroup: chat.isGroup,
      video: video,
    );
  }

  String? _typingText(DemoChat chat) {
    final names = _feed?.typing.values.toList() ?? const [];
    if (names.isEmpty) return null;
    if (!chat.isGroup) return 'typing...';
    return names.length == 1
        ? '${names.first} is typing...'
        : '${names.length} people are typing...';
  }

  ChatThemeDef? _themeOf(DemoChat chat) {
    final key = _themes[chat.id];
    for (final t in chatThemes) {
      if (t.key == key) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final list = _ChatListPanel(
      chats: _visibleChats,
      filter: _filter,
      selectedId: size == ScreenSize.phone ? null : _selectedId,
      unreadOf: _unread,
      privateMode: _privateMode,
      privateCount: _privateChats.length,
      query: _query,
      onFilter: (f) => setState(() => _filter = f),
      onSearch: (q) => setState(() => _query = q),
      onOpen: _open,
      onOpenPrivate: _openPrivate,
      onClosePrivate: _closePrivate,
      onNewUser: _newUser,
      onNewGroup: _newGroup,
      loading: _live && _repo.loading,
      error: _live ? _repo.error : null,
      onRetry: _repo.refresh,
    );
    final chat = _selected;
    final conversation = chat == null
        ? const _EmptyConversation()
        : _ConversationPane(
            key: ValueKey(chat.id),
            chat: chat,
            theme: _themeOf(chat),
            wallpaperUrl: _wallpapers[chat.id],
            typingText: _live ? _typingText(chat) : null,
            onTyping: _live ? () => _feed?.setTyping(true) : null,
            feed: _live ? _feed : null,
            loading: _live && !(_feed?.loaded ?? false),
            messages: _live
                ? (_feed?.messages ?? const [])
                : (_messages[chat.id] ?? const []),
            onSend: _send,
            onOpenInfo: () => setState(() => _infoOpen = true),
            onCall: (video) => _call(chat, video),
            onChatTheme: () => _pickTheme(chat),
            onCloseChat: () => setState(() {
              _selectedId = null;
              _infoOpen = false;
            }),
            onBack: size == ScreenSize.phone
                ? () => setState(() => _selectedId = null)
                : null,
          );
    final info = (chat != null && _infoOpen)
        ? ContactInfoPanel(
            key: ValueKey('info-${chat.id}'),
            chat: chat,
            onClose: () => setState(() => _infoOpen = false),
            onMessage: () => setState(() => _infoOpen = false),
            onCall: (video) => _call(chat, video),
            onChatTheme: () => _pickTheme(chat),
            onAddMember: () => _addMembers(chat),
          )
        : null;

    if (size == ScreenSize.phone) {
      return info ?? (chat == null ? list : conversation);
    }

    const gap = 12.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          // Chat list width is dragged by the user; the conversation keeps
          // at least 420px.
          final maxList = (c.maxWidth - gap - 420).clamp(280.0, 720.0);
          final listWidth = _listWidth.value.clamp(280.0, maxList);
          // Three cards when there is room; otherwise the info panel takes
          // the conversation's place until it is closed.
          final remaining = c.maxWidth - listWidth - gap;
          final infoWidth = remaining >= 900 ? 360.0 : 330.0;
          final threeColumns = remaining >= infoWidth + gap + 380;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: listWidth,
                child: ShellPanel(child: list),
              ),
              ResizeHandle(
                width: gap,
                onDrag: (dx) => setState(
                  () => _listWidth.set((listWidth + dx).clamp(280.0, maxList)),
                ),
                onDoubleTap: () =>
                    setState(() => _listWidth.set(_listWidth.initial)),
              ),
              if (info == null)
                Expanded(child: ShellPanel(child: conversation))
              else if (threeColumns) ...[
                Expanded(child: ShellPanel(child: conversation)),
                const SizedBox(width: gap),
                SizedBox(
                  width: infoWidth,
                  child: ShellPanel(child: info),
                ),
              ] else
                Expanded(child: ShellPanel(child: info)),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat list
// ---------------------------------------------------------------------------

class _ChatListPanel extends StatelessWidget {
  const _ChatListPanel({
    required this.chats,
    required this.filter,
    required this.selectedId,
    required this.unreadOf,
    required this.privateMode,
    required this.privateCount,
    required this.query,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onOpenPrivate,
    required this.onClosePrivate,
    required this.onNewUser,
    required this.onNewGroup,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  final List<DemoChat> chats;
  final ChatFilter filter;
  final String? selectedId;
  final int Function(DemoChat) unreadOf;
  final bool privateMode;
  final int privateCount;
  final String query;
  final ValueChanged<ChatFilter> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<DemoChat> onOpen;
  final VoidCallback onOpenPrivate;
  final VoidCallback onClosePrivate;
  final VoidCallback onNewUser;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    // The Private Chats row only shows in the normal "All" list with no
    // search text, so locked chat names never surface in search.
    final showPrivateRow =
        !privateMode && filter == ChatFilter.all && query.trim().isEmpty;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(privateMode ? 8 : 20, 18, 16, 0),
            child: Row(
              children: [
                if (privateMode)
                  IconButton(
                    tooltip: 'Back to chats',
                    onPressed: onClosePrivate,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.heading,
                    ),
                  ),
                Expanded(
                  child: Text(
                    privateMode ? 'Private Chats' : 'Chats',
                    style: TextStyle(
                      fontSize: privateMode ? 24 : 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                _NewChatButton(
                  privateMode: privateMode,
                  onNewUser: onNewUser,
                  onNewGroup: onNewGroup,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SearchField(
              key: ValueKey('search-$privateMode'),
              hint: privateMode
                  ? 'Search private chats'
                  : 'Search messages or people',
              onChanged: onSearch,
            ),
          ),
          if (!privateMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
              child: FilterChips<ChatFilter>(
                values: ChatFilter.values,
                labels: const ['All', 'Unread', 'Groups', 'Archived'],
                selected: filter,
                onSelected: onFilter,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: AppColors.meta),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Locked chats are hidden from your main list.',
                      style: TextStyle(fontSize: 13, color: AppColors.meta),
                    ),
                  ),
                ],
              ),
            ),
          if (showPrivateRow)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
              child: _PrivateChatsRow(
                count: privateCount,
                onTap: onOpenPrivate,
              ),
            ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : error != null && chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.meta),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : chats.isEmpty
                ? Center(
                    child: Text(
                      privateMode
                          ? 'No private chats yet'
                          : 'No chats here yet',
                      style: const TextStyle(color: AppColors.meta),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: chats.length,
                    itemBuilder: (_, i) => _ChatTile(
                      chat: chats[i],
                      unread: unreadOf(chats[i]),
                      selected: chats[i].id == selectedId,
                      onTap: () => onOpen(chats[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrivateChatsRow extends StatelessWidget {
  const _PrivateChatsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Chats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Protected by your app password',
                      style: TextStyle(fontSize: 13.5, color: AppColors.meta),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.meta),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({
    required this.privateMode,
    required this.onNewUser,
    required this.onNewGroup,
  });

  final bool privateMode;
  final VoidCallback onNewUser;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'New chat',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) => v == 0 ? onNewUser() : onNewGroup(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            leading: const Icon(
              Icons.person_add_alt_1_outlined,
              color: AppColors.accent,
            ),
            title: const Text('New user'),
            subtitle: Text(
              privateMode
                  ? 'Start a private chat with a contact'
                  : 'Start a chat with a contact',
            ),
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: const Icon(
              Icons.group_add_outlined,
              color: AppColors.accent,
            ),
            title: const Text('Create group'),
            subtitle: Text(
              privateMode
                  ? 'A private group with the same rules'
                  : 'Chat with several people at once',
            ),
          ),
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.teal],
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA855F7), Color(0xFF7A3BE0)],
            ),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final DemoChat chat;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFF1E6FE) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Avatar(
                  name: chat.name,
                  color: chat.avatarColor,
                  photoUrl: chat.avatarUrl,
                  isGroup: chat.isGroup,
                  isOnline: chat.isOnline,
                  size: 54,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
                        ),
                      ),
                      if (chat.preview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (chat.previewIsPhoto) ...[
                              const Icon(
                                Icons.photo_outlined,
                                size: 16,
                                color: AppColors.meta,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                chat.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.meta,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.time,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: hasUnread ? AppColors.accent : AppColors.meta,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasUnread)
                      CountBadge(unread, size: 22)
                    else if (chat.marker == ChatMarker.activeStatus)
                      const Icon(
                        Icons.radio_button_checked,
                        size: 20,
                        color: AppColors.accent,
                      )
                    else if (chat.marker == ChatMarker.seenStatus)
                      const Icon(
                        Icons.radio_button_checked,
                        size: 20,
                        color: AppColors.meta,
                      )
                    else
                      const SizedBox(height: 20),
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

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return const _WallpaperBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMark(size: 64),
            SizedBox(height: 18),
            Text(
              'SchatzApp Web',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a chat to start messaging.',
              style: TextStyle(fontSize: 15, color: AppColors.meta),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationPane extends StatefulWidget {
  const _ConversationPane({
    super.key,
    required this.chat,
    required this.messages,
    required this.onSend,
    required this.onOpenInfo,
    required this.onCall,
    required this.onChatTheme,
    required this.onCloseChat,
    this.theme,
    this.wallpaperUrl,
    this.typingText,
    this.onTyping,
    this.loading = false,
    this.onBack,
    this.feed,
  });

  final ConversationFeed? feed;

  final DemoChat chat;
  final ChatThemeDef? theme;
  final String? wallpaperUrl;
  final String? typingText;
  final VoidCallback? onTyping;
  final bool loading;
  final List<DemoMessage> messages;
  final ValueChanged<String> onSend;
  final VoidCallback onOpenInfo;
  final ValueChanged<bool> onCall;
  final VoidCallback onChatTheme;
  final VoidCallback onCloseChat;
  final VoidCallback? onBack;

  @override
  State<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends State<_ConversationPane> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _ConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final compact = widget.onBack != null;
    return Column(
      children: [
        _ConversationHeader(
          chat: chat,
          typingText: widget.typingText,
          onBack: widget.onBack,
          onOpenInfo: widget.onOpenInfo,
          onCall: widget.onCall,
          onChatTheme: widget.onChatTheme,
          onCloseChat: widget.onCloseChat,
        ),
        Expanded(
          child: _WallpaperBackground(
            theme: widget.theme,
            wallpaperUrl: widget.wallpaperUrl,
            child: widget.loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 28,
                      14,
                      compact ? 12 : 28,
                      14,
                    ),
                    children: [
                      if (widget.messages.isEmpty)
                        const _EmptyThreadHint()
                      else
                        for (var i = 0; i < widget.messages.length; i++) ...[
                          if (i == 0 ||
                              !_sameDay(
                                widget.messages[i - 1].createdAt,
                                widget.messages[i].createdAt,
                              ))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: _DateChip(
                                  _dayLabel(widget.messages[i].createdAt),
                                ),
                              ),
                            ),
                          MessageBubble(
                            message: widget.messages[i],
                            compact: compact,
                            theme: widget.theme,
                          ),
                        ],
                    ],
                  ),
          ),
        ),
        ChatComposer(
          onSend: widget.onSend,
          onTyping: widget.onTyping,
          feed: widget.feed,
        ),
      ],
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.chat,
    this.typingText,
    required this.onOpenInfo,
    required this.onCall,
    required this.onChatTheme,
    required this.onCloseChat,
    this.onBack,
  });

  final DemoChat chat;
  final String? typingText;
  final VoidCallback onOpenInfo;
  final ValueChanged<bool> onCall;
  final VoidCallback onChatTheme;
  final VoidCallback onCloseChat;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    void soon(String what) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
    return Container(
      height: 74,
      padding: EdgeInsets.only(left: onBack != null ? 4 : 24, right: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.heading),
            ),
          Expanded(
            child: Tooltip(
              message: chat.isGroup ? 'Group info' : 'Contact info',
              waitDuration: const Duration(milliseconds: 600),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenInfo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Avatar(
                        name: chat.name,
                        color: chat.avatarColor,
                        photoUrl: chat.avatarUrl,
                        isGroup: chat.isGroup,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.heading,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (typingText != null)
                              Text(
                                typingText!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.accent,
                                ),
                              )
                            else if (chat.isOnline)
                              const Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: AppColors.online,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.body,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                chat.isGroup
                                    ? 'Click here for group info'
                                    : 'Last seen recently',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.meta,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => onCall(true),
            icon: const Icon(Icons.videocam_outlined, size: 27),
            color: AppColors.body,
          ),
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => onCall(false),
            icon: const Icon(Icons.call_outlined, size: 25),
            color: AppColors.body,
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => soon('Search in chat'),
            icon: const Icon(Icons.search, size: 26),
            color: AppColors.body,
          ),
          PopupMenuButton<int>(
            tooltip: 'More',
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_horiz, size: 26, color: AppColors.body),
            onSelected: (v) {
              switch (v) {
                case 0:
                  onOpenInfo();
                case 1:
                  onChatTheme();
                case 2:
                  soon('Clear chat');
                case 3:
                  onCloseChat();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Text(chat.isGroup ? 'Group info' : 'Contact info'),
              ),
              const PopupMenuItem(value: 1, child: Text('Chat theme')),
              const PopupMenuItem(value: 2, child: Text('Clear chat')),
              const PopupMenuItem(value: 3, child: Text('Close chat')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WallpaperBackground extends StatelessWidget {
  const _WallpaperBackground({
    required this.child,
    this.theme,
    this.wallpaperUrl,
  });

  final Widget child;
  final ChatThemeDef? theme;

  /// Custom photo the user picked on the phone (overrides the theme image).
  final String? wallpaperUrl;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final url = wallpaperUrl ?? t?.wallpaper;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: t == null ? _WallpaperPainter() : _ThemePainter(t),
          ),
        ),
        if (url != null && url.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Theme background: tinted base with a soft doodle pattern. The real
/// wallpaper images load from storage in the backend phase.
class _ThemePainter extends CustomPainter {
  _ThemePainter(this.theme);

  final ChatThemeDef theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);
    final stroke = Paint()
      ..color = theme.sender.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const step = 90.0;
    var row = 0;
    for (var y = 20.0; y < size.height; y += step, row++) {
      for (var x = (row.isEven ? 20.0 : 65.0); x < size.width; x += step) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 30, 22),
          const Radius.circular(8),
        );
        canvas.drawRRect(r, stroke);
        canvas.drawCircle(Offset(x + 48, y + 40), 6, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThemePainter old) => old.theme != theme;
}

class _EmptyThreadHint extends StatelessWidget {
  const _EmptyThreadHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No messages yet. Say hello!',
          style: TextStyle(color: AppColors.meta),
        ),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF3EEFD), Color(0xFFF8F5FE), Color(0xFFF1EAFC)],
        ).createShader(rect),
    );
    final w = size.width;
    final h = size.height;
    final p1 = Path()
      ..moveTo(w * 0.55, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.35)
      ..quadraticBezierTo(w * 0.8, h * 0.18, w * 0.55, 0);
    canvas.drawPath(
      p1,
      Paint()..color = const Color(0xFFE9DEFC).withValues(alpha: 0.6),
    );
    final p2 = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.25, h * 0.75, w * 0.1, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      p2,
      Paint()..color = const Color(0xFFEADFFC).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DateChip extends StatelessWidget {
  const _DateChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E1F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.body),
      ),
    );
  }
}

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return true; // demo messages have no date
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dayLabel(DateTime? d) {
  if (d == null) return 'Today';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
