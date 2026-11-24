import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/web_auth.dart';
import '../../data/demo_data.dart';
import '../../data/live/call_service.dart';
import '../../data/live/chat_repo.dart';
import '../../data/live/conversation_feed.dart';
import '../../platform/web_files.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/resizable_width.dart';
import '../../widgets/brand_logo.dart';
import '../calls/call_screen.dart';
import 'chat_dialogs.dart';
import 'composer.dart';
import 'contact_info_panel.dart';
import 'media_viewer.dart';
import 'message_actions.dart';
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
    // Right-click opens the message menu (text fields get Flutter's own
    // Cut / Copy / Paste menu instead of the browser's).
    BrowserContextMenu.disableContextMenu();
    if (_live) {
      _repo.addListener(_onData);
      _repo.start();
      _loadLastChat();
    }
  }

  @override
  void dispose() {
    BrowserContextMenu.enableContextMenu();
    _repo.removeListener(_onData);
    _feed?.removeListener(_onData);
    _feed?.dispose();
    super.dispose();
  }

  void _onData() {
    if (!mounted) return;
    setState(() {});
    if (_restoreId != null) _tryRestore();
  }

  void _openFeed(DemoChat c) {
    if (_feed?.conversationId == c.id) return;
    _feed?.removeListener(_onData);
    _feed?.dispose();
    _feed = ConversationFeed(c.id, isGroup: c.isGroup)
      ..otherName = c.isGroup ? null : c.name
      ..addListener(_onData);
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
    final p = _pendingChats[_selectedId];
    if (p != null) {
      return DemoChat(
        id: _selectedId!,
        name: p.name,
        preview: '',
        time: '',
        avatarUrl: p.avatarUrl,
        otherUserId: p.userId,
        phone: p.phone,
      );
    }
    return null;
  }

  static const _lastChatKey = 'web_last_open_chat';

  /// Chat to reopen after a page refresh.
  String? _restoreId;

  Future<void> _loadLastChat() async {
    final p = await SharedPreferences.getInstance();
    _restoreId = p.getString(_lastChatKey);
    _tryRestore();
  }

  void _tryRestore() {
    final id = _restoreId;
    if (id == null || _selectedId != null || _repo.loading) return;
    // Locked chats are never reopened without the password gate.
    final c = _repo.chats.where((x) => x.id == id).firstOrNull;
    _restoreId = null;
    if (c != null) _open(c);
  }

  void _rememberChat(String? id) {
    SharedPreferences.getInstance().then((p) {
      id == null ? p.remove(_lastChatKey) : p.setString(_lastChatKey, id);
    });
  }

  void _open(DemoChat c) {
    if (_live && !c.isLocked) _rememberChat(c.id);
    setState(() {
      if (_selectedId != c.id) _replyTo = null;
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
      final reply = _replyTo;
      setState(() => _replyTo = null);
      _feed?.sendText(text, replyTo: reply).catchError((_) {
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

  // -------------------------------------------------------------------------
  // Message actions
  // -------------------------------------------------------------------------

  /// Message being replied to in the open chat.
  DemoMessage? _replyTo;

  String _senderOf(DemoMessage m, DemoChat chat) =>
      m.isMine ? 'You' : (m.senderName ?? chat.name);

  String? _photoOf(DemoMessage m, DemoChat chat) => m.isMine
      ? (ChatRepo.instance.me?['avatar_url'] as String?)
      : (chat.isGroup ? null : chat.avatarUrl);

  Future<void> _guard(Future<void> Function() job, String failure) async {
    try {
      await job();
    } catch (_) {
      if (mounted) _toast(failure);
    }
  }

  void _reply(DemoMessage m) => setState(() => _replyTo = m);

  Future<void> _react(DemoMessage m, String emoji) async {
    final feed = _feed;
    if (feed == null) return;
    await _guard(() => feed.react(m, emoji), 'Could not react. Try again.');
  }

  Future<void> _quickReact(DemoMessage m, Offset at) async {
    final e = await showReactionPicker(context, at: at, selected: m.myReaction);
    if (e != null) await _react(m, e);
  }

  Future<void> _star(DemoMessage m) async {
    final feed = _feed;
    if (feed == null) return;
    await feed.toggleStar(m);
  }

  Future<void> _forward(List<DemoMessage> ms) async {
    final t = await showDialog<ForwardTargets>(
      context: context,
      builder: (_) =>
          ForwardDialog(chats: _repo.chats, loadContacts: _repo.contacts),
    );
    if (t == null || !mounted) return;
    await _guard(() async {
      await ConversationFeed.forward(
        ms,
        conversationIds: t.conversationIds,
        userIds: t.userIds,
      );
      final n = t.conversationIds.length + t.userIds.length;
      _toast(n == 1 ? 'Message forwarded' : 'Message forwarded to $n chats');
    }, 'Could not forward. Try again.');
  }

  Future<void> _onMenu(DemoMessage m, Offset at) async {
    final feed = _feed;
    if (feed == null) return;
    final pick = await showMessageMenu(
      context,
      at: at,
      message: m,
      canEdit: feed.canEdit(m),
    );
    if (pick == null || !mounted) return;
    if (pick.reaction != null) return _react(m, pick.reaction!);
    if (pick.morePicker) {
      final e = await showReactionPicker(context, at: at, full: true);
      if (e != null) await _react(m, e);
      return;
    }
    switch (pick.action!) {
      case MsgAction.reply:
        _reply(m);
      case MsgAction.copy:
        await Clipboard.setData(ClipboardData(text: m.text));
        _toast('Copied');
      case MsgAction.forward:
        await _forward([m]);
      case MsgAction.pin || MsgAction.unpin:
        await _guard(() async {
          final err = await feed.setPinned(m, pick.action == MsgAction.pin);
          if (err != null) _toast(err);
        }, 'Could not update the pin. Try again.');
      case MsgAction.star || MsgAction.unstar:
        await _guard(() => _star(m), 'Could not update. Try again.');
      case MsgAction.edit:
        final text = await showEditDialog(context, m.text);
        if (text == null || text.isEmpty) return;
        if (!feed.canEdit(m)) {
          _toast('This message can no longer be edited.');
          return;
        }
        await _guard(() => feed.edit(m, text), 'Could not edit. Try again.');
      case MsgAction.save:
        final url = m.kind == MessageKind.image && m.mediaUrls.isNotEmpty
            ? m.mediaUrls.first
            : (m.mediaUrl ?? '');
        await _guard(
          () => downloadUrl(
            url,
            m.kind == MessageKind.document && m.text.isNotEmpty
                ? m.text
                : fileNameFromUrl(url),
          ),
          'Could not download. Try again.',
        );
      case MsgAction.delete:
        final reason = m.isMine ? feed.deleteBlockReason(m) : null;
        final choice = await showDeleteDialog(
          context,
          own: m.isMine,
          blockReason: reason,
        );
        if (choice == null) return;
        if (_replyTo?.id == m.id) setState(() => _replyTo = null);
        if (choice == DeleteChoice.forEveryone) {
          await _guard(
            () => feed.deleteForEveryone(m),
            'This message can no longer be deleted for everyone.',
          );
        } else {
          await _guard(
            () => feed.deleteForMe(m),
            'Could not delete. Try again.',
          );
        }
    }
  }

  Future<void> _clearChat(DemoChat chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Clear this chat?',
        width: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'This deletes all messages in this chat for you only. '
                '${chat.isGroup ? 'Other members' : 'The other person'} will '
                'still see them.',
                style: const TextStyle(fontSize: 14.5, color: AppColors.body),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.missed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Clear chat'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _guard(() async {
      await _repo.clearChat(chat.id);
      _toast('Chat cleared');
    }, 'Could not clear the chat. Try again.');
  }

  ViewerActions _viewerActions(DemoChat chat) => ViewerActions(
    onReply: _reply,
    onStar: _star,
    onReact: _quickReact,
    onForward: (m) => _forward([m]),
  );

  void _openMedia(
    DemoChat chat,
    List<DemoMessage> all,
    DemoMessage m,
    String url,
  ) {
    final items = <MediaItem>[];
    var start = 0;
    for (final x in all) {
      if (x.kind == MessageKind.image) {
        final urls = x.mediaUrls.isNotEmpty
            ? x.mediaUrls
            : [if ((x.mediaUrl ?? '').isNotEmpty) x.mediaUrl!];
        for (final u in urls) {
          if (x.id == m.id && u == url) start = items.length;
          items.add(
            MediaItem(
              message: x,
              url: u,
              isVideo: false,
              sender: _senderOf(x, chat),
              senderPhoto: _photoOf(x, chat),
            ),
          );
        }
      } else if (x.kind == MessageKind.video && (x.mediaUrl ?? '').isNotEmpty) {
        if (x.id == m.id) start = items.length;
        items.add(
          MediaItem(
            message: x,
            url: x.mediaUrl!,
            isVideo: true,
            thumb: x.thumbUrl,
            sender: _senderOf(x, chat),
            senderPhoto: _photoOf(x, chat),
          ),
        );
      }
    }
    if (items.isEmpty) return;
    showMediaViewer(
      context,
      items: items,
      start: start,
      actions: _viewerActions(chat),
    );
  }

  void _openDoc(DemoChat chat, DemoMessage m) {
    if ((m.mediaUrl ?? '').isEmpty) return;
    showDocumentViewer(
      context,
      message: m,
      sender: _senderOf(m, chat),
      senderPhoto: _photoOf(m, chat),
      actions: _viewerActions(chat),
    );
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

  /// Lock Chat in the info panel: a locked chat moves to Private Chats (the
  /// password was just checked), an unlocked one goes back to the list.
  Future<void> _lockChanged(DemoChat chat, bool locked) async {
    if (_live) {
      await _repo.refresh();
    } else {
      _demoChats.removeWhere((c) => c.id == chat.id);
      _demoPrivate.removeWhere((c) => c.id == chat.id);
      (locked ? _demoPrivate : _demoChats).insert(0, chat);
    }
    if (!mounted) return;
    setState(() {
      if (locked) _privateUnlocked = true;
      _privateMode = locked;
      _query = '';
      _selectedId = chat.id;
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
        title: _privateMode ? 'New private chat' : 'New chat',
        load: _live ? _repo.contacts : null,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final contact = picked.first;
    if (_live) {
      final uid = contact.userId;
      if (uid == null) return;
      await _guard(() async {
        final id = await _repo.directConversationWith(uid);
        await _repo.refresh();
        if (!mounted) return;
        final all = [..._repo.chats, ..._repo.lockedChats];
        final c = all.where((x) => x.id == id).firstOrNull;
        if (c != null && c.isLocked && !_privateMode) {
          _toast('This chat is in Private Chats.');
          return;
        }
        _open(
          c ??
              DemoChat(
                id: id,
                name: contact.name,
                preview: '',
                time: '',
                avatarUrl: contact.avatarUrl,
                otherUserId: uid,
                phone: contact.phone,
              ),
        );
        if (c == null) _pendingChats[id] = contact;
      }, 'Could not start the chat. Try again.');
      return;
    }
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
      builder: (_) => CreateGroupDialog(
        privateGroup: _privateMode,
        load: _live ? _repo.contacts : null,
      ),
    );
    if (g == null || !mounted) return;
    if (_live) {
      await _guard(() async {
        String? photo;
        if (g.photo != null) photo = await _repo.uploadGroupAvatar(g.photo!);
        final id = await _repo.createGroup(
          name: g.name,
          memberIds: [for (final m in g.members) ?m.userId],
          isPrivate: g.isPrivate,
          avatarUrl: photo,
        );
        if (!mounted) return;
        final all = [..._repo.chats, ..._repo.lockedChats];
        final c = all.where((x) => x.id == id).firstOrNull;
        if (c != null && (!c.isLocked || _privateMode)) {
          _open(c);
        } else if (c != null) {
          _toast('Private group created. Find it in Private Chats.');
        } else {
          _toast('Group created.');
        }
      }, 'Could not create the group. Try again.');
      return;
    }
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

  Future<void> _addMembers(
    DemoChat chat, {
    Set<String> exclude = const {},
  }) async {
    final picked = await showDialog<List<DemoContact>>(
      context: context,
      builder: (_) => ContactPickerDialog(
        title: 'Add Members To Group',
        multiSelect: true,
        exclude: _live ? exclude : chat.members.toSet(),
        load: _live ? _repo.contacts : null,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    if (_live) {
      await _guard(() async {
        await _repo.addMembers(chat.id, [for (final c in picked) ?c.userId]);
        _infoVersion++;
        if (mounted) setState(() {});
        _toast('${picked.length} member(s) added.');
      }, 'Could not add members. They may already be in the group.');
      return;
    }
    _toast('${picked.length} member(s) added.');
  }

  /// Bumped to make the info panel reload after changes.
  int _infoVersion = 0;

  /// Chats just created that the list has not loaded yet.
  final Map<String, DemoContact> _pendingChats = {};

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
    if (_live) {
      CallService.instance.call(chat, video: video).then((err) {
        if (err != null && mounted) _toast(err);
      });
      return;
    }
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
            replyTo: _replyTo,
            replyName: _replyTo == null ? null : _senderOf(_replyTo!, chat),
            onCancelReply: () => setState(() => _replyTo = null),
            onClearChat: _live ? () => _clearChat(chat) : null,
            actions: _live
                ? BubbleActions(
                    onMenu: _onMenu,
                    onQuickReact: _quickReact,
                    onOpenMedia: (m, url) =>
                        _openMedia(chat, _feed?.messages ?? const [], m, url),
                    onOpenDocument: (m) => _openDoc(chat, m),
                  )
                : const BubbleActions(),
            onOpenInfo: () => setState(() => _infoOpen = true),
            onCall: (video) => _call(chat, video),
            onChatTheme: () => _pickTheme(chat),
            onCloseChat: () {
              _rememberChat(null);
              setState(() {
                _selectedId = null;
                _infoOpen = false;
              });
            },
            onBack: size == ScreenSize.phone
                ? () => setState(() => _selectedId = null)
                : null,
          );
    final info = (chat != null && _infoOpen)
        ? ContactInfoPanel(
            key: ValueKey('info-${chat.id}-$_infoVersion'),
            chat: chat,
            live: _live,
            messages: _live ? (_feed?.messages ?? const []) : const [],
            onClose: () => setState(() => _infoOpen = false),
            onMessage: () => setState(() => _infoOpen = false),
            onCall: (video) => _call(chat, video),
            onChatTheme: () => _pickTheme(chat),
            onAddMember: (existing) => _addMembers(chat, exclude: existing),
            onOpenMedia: (m, url) =>
                _openMedia(chat, _feed?.messages ?? const [], m, url),
            onOpenDocument: (m) => _openDoc(chat, m),
            onLockChanged: (locked) => _lockChanged(chat, locked),
            onChatRemoved: () {
              _rememberChat(null);
              setState(() {
                _infoOpen = false;
                _selectedId = null;
                _replyTo = null;
              });
            },
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
    this.replyTo,
    this.replyName,
    this.onCancelReply,
    this.actions = const BubbleActions(),
    this.onClearChat,
  });

  final VoidCallback? onClearChat;
  final ConversationFeed? feed;
  final DemoMessage? replyTo;
  final String? replyName;
  final VoidCallback? onCancelReply;
  final BubbleActions actions;

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
  final Map<String, GlobalKey> _keys = {};
  String? _highlight;
  int _pinIndex = 0;
  String? _lastId;

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _lastId = widget.messages.lastOrNull?.id;
    _toBottom(jump: true);
  }

  @override
  void didUpdateWidget(covariant _ConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only follow new messages (not reactions, stars or edits).
    final last = widget.messages.lastOrNull?.id;
    final firstLoad = oldWidget.loading && !widget.loading;
    if (last != _lastId || firstLoad) {
      _lastId = last;
      _toBottom(jump: firstLoad);
    }
  }

  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      // The list is anchored at the bottom (reverse), so 0 is the newest.
      if (jump) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Scrolls to a message and tints it briefly (replies, pinned bar).
  void _jumpTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('That message is no longer available.')),
        );
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _highlight = id);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _highlight == id) setState(() => _highlight = null);
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
    final pinned = widget.messages.where((m) => m.isPinned).toList();
    if (_pinIndex >= pinned.length) _pinIndex = 0;
    final a = widget.actions;
    final actions = BubbleActions(
      onMenu: a.onMenu,
      onQuickReact: a.onQuickReact,
      onOpenMedia: a.onOpenMedia,
      onOpenDocument: a.onOpenDocument,
      onReplyTap: _jumpTo,
    );
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
          onClearChat: widget.onClearChat,
        ),
        if (pinned.isNotEmpty)
          _PinnedBar(
            message: pinned[pinned.length - 1 - _pinIndex],
            index: _pinIndex,
            count: pinned.length,
            onTap: () {
              final m = pinned[pinned.length - 1 - _pinIndex];
              _jumpTo(m.id);
              setState(() => _pinIndex = (_pinIndex + 1) % pinned.length);
            },
          ),
        Expanded(
          child: _WallpaperBackground(
            theme: widget.theme,
            wallpaperUrl: widget.wallpaperUrl,
            child: widget.loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : SingleChildScrollView(
                    controller: _scroll,
                    // Opens at the newest message and stays there while
                    // photos load above it.
                    reverse: true,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 8 : 22,
                      14,
                      compact ? 8 : 22,
                      14,
                    ),
                    child: Column(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: _DateChip(
                                    _dayLabel(widget.messages[i].createdAt),
                                  ),
                                ),
                              ),
                            MessageBubble(
                              key: widget.messages[i].id.isEmpty
                                  ? null
                                  : _keyFor(widget.messages[i].id),
                              message: widget.messages[i],
                              compact: compact,
                              theme: widget.theme,
                              actions: actions,
                              highlighted: _highlight == widget.messages[i].id,
                            ),
                          ],
                      ],
                    ),
                  ),
          ),
        ),
        ChatComposer(
          onSend: widget.onSend,
          onTyping: widget.onTyping,
          feed: widget.feed,
          replyTo: widget.replyTo,
          replyName: widget.replyName,
          onCancelReply: widget.onCancelReply,
        ),
      ],
    );
  }
}

/// Pinned messages bar under the header (cycles through pins on tap).
class _PinnedBar extends StatelessWidget {
  const _PinnedBar({
    required this.message,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final DemoMessage message;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (count > 1)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      Container(
                        width: 3,
                        height: 30 / count - 2,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppColors.accent
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 10),
              const Icon(Icons.push_pin, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  replyPreview(message).isEmpty
                      ? 'Pinned message'
                      : replyPreview(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.heading,
                  ),
                ),
              ),
              if (count > 1)
                Text(
                  '${index + 1} of $count',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.meta),
                ),
            ],
          ),
        ),
      ),
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
    this.onClearChat,
  });

  final VoidCallback? onClearChat;
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
                  onClearChat == null ? soon('Clear chat') : onClearChat!();
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
