import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/resizable_width.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/sunset_painter.dart';
import '../calls/call_screen.dart';
import 'chat_dialogs.dart';
import 'contact_info_panel.dart';

/// Chats tab (UI image 2). Uses placeholder data until the backend phase.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  static const routePath = '/chats';

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  ChatFilter _filter = ChatFilter.all;
  String _query = '';
  String? _selectedId = 'kesta';
  final List<DemoChat> _chats = List.of(demoChats);
  final List<DemoChat> _privateChats = List.of(demoPrivateChats);
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

  void _open(DemoChat c) => setState(() {
    _selectedId = c.id;
    _readIds.add(c.id);
  });

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _send(String text) {
    final id = _selectedId;
    if (id == null || text.trim().isEmpty) return;
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
        builder: (_) => const PasswordGateDialog(),
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
    setState(() {
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
    );
    final chat = _selected;
    final conversation = chat == null
        ? const _EmptyConversation()
        : _ConversationPane(
            key: ValueKey(chat.id),
            chat: chat,
            theme: _themeOf(chat),
            messages: _messages[chat.id] ?? const [],
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
  });

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
            child: chats.isEmpty
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
    this.onBack,
  });

  final DemoChat chat;
  final ChatThemeDef? theme;
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
          onBack: widget.onBack,
          onOpenInfo: widget.onOpenInfo,
          onCall: widget.onCall,
          onChatTheme: widget.onChatTheme,
          onCloseChat: widget.onCloseChat,
        ),
        Expanded(
          child: _WallpaperBackground(
            theme: widget.theme,
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 28,
                14,
                compact ? 12 : 28,
                14,
              ),
              children: [
                const Center(child: _DateChip('Today')),
                const SizedBox(height: 10),
                if (widget.messages.isEmpty)
                  const _EmptyThreadHint()
                else
                  for (final m in widget.messages)
                    _MessageBubble(
                      message: m,
                      compact: compact,
                      theme: widget.theme,
                    ),
              ],
            ),
          ),
        ),
        _Composer(onSend: widget.onSend),
      ],
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.chat,
    required this.onOpenInfo,
    required this.onCall,
    required this.onChatTheme,
    required this.onCloseChat,
    this.onBack,
  });

  final DemoChat chat;
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
                            if (chat.isOnline)
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
  const _WallpaperBackground({required this.child, this.theme});

  final Widget child;
  final ChatThemeDef? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return CustomPaint(
      painter: t == null ? _WallpaperPainter() : _ThemePainter(t),
      child: child,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.compact,
    this.theme,
  });

  final DemoMessage message;
  final bool compact;
  final ChatThemeDef? theme;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final maxW = MediaQuery.sizeOf(context).width * (compact ? 0.78 : 0.42);

    if (message.kind == MessageKind.image) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _bubbleShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: compact ? 240 : 276,
                  height: compact ? 150 : 164,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: SunsetPainter()),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 8,
                        child: Text(
                          message.time,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
            ),
            if (!mine) ...[
              const SizedBox(width: 14),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9E5F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.reply,
                  textDirection: TextDirection.rtl,
                  size: 20,
                  color: AppColors.body,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final textColor = mine ? Colors.white : AppColors.heading;
    final metaColor = mine
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.meta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: BoxDecoration(
              color: mine ? theme?.sender : (theme?.receiver ?? Colors.white),
              gradient: mine && theme == null
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
              boxShadow: mine ? null : _bubbleShadow,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(
                  message.text,
                  style: TextStyle(fontSize: 16, color: textColor, height: 1.3),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(fontSize: 12, color: metaColor),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 16,
                          color: metaColor,
                        ),
                      ],
                    ],
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

final _bubbleShadow = [
  BoxShadow(
    color: const Color(0xFF5B1CD3).withValues(alpha: 0.06),
    blurRadius: 10,
    offset: const Offset(0, 3),
  ),
];

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void soon(String what) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
    return Container(
      color: const Color(0xFFF7F3FD),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Container(
        height: 58,
        padding: const EdgeInsets.only(left: 6, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
          boxShadow: _bubbleShadow,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Emoji',
              onPressed: () => soon('Emoji picker'),
              icon: const Icon(Icons.sentiment_satisfied_alt_outlined),
              color: AppColors.body,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.meta, fontSize: 16),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Attach',
              onPressed: () => soon('Attachments'),
              icon: const Icon(Icons.attach_file),
              color: AppColors.body,
            ),
            IconButton(
              tooltip: 'Camera',
              onPressed: () => soon('Camera'),
              icon: const Icon(Icons.photo_camera_outlined),
              color: AppColors.body,
            ),
            IconButton(
              tooltip: 'Voice note',
              onPressed: () => soon('Voice notes'),
              icon: const Icon(Icons.mic_none_outlined),
              color: AppColors.body,
            ),
            const SizedBox(width: 4),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: _submit,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFAE5CF2), Color(0xFF8A3BE6)],
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
