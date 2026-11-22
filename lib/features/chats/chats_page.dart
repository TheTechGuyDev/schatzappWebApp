import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/sunset_painter.dart';
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
  final Map<String, List<DemoMessage>> _messages = {
    for (final e in demoMessages.entries) e.key: List.of(e.value),
  };
  final Set<String> _readIds = {};
  bool _infoOpen = false;

  List<DemoChat> get _visibleChats {
    final q = _query.trim().toLowerCase();
    return demoChats.where((c) {
      final passFilter = switch (_filter) {
        ChatFilter.all => !c.isArchived,
        ChatFilter.unread => !c.isArchived && _unread(c) > 0,
        ChatFilter.groups => !c.isArchived && c.isGroup,
        ChatFilter.archived => c.isArchived,
      };
      if (!passFilter) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.preview.toLowerCase().contains(q);
    }).toList();
  }

  int _unread(DemoChat c) => _readIds.contains(c.id) ? 0 : c.unread;

  DemoChat? get _selected {
    for (final c in demoChats) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  void _open(DemoChat c) => setState(() {
    _selectedId = c.id;
    _readIds.add(c.id);
  });

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

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final list = _ChatListPanel(
      chats: _visibleChats,
      filter: _filter,
      selectedId: size == ScreenSize.phone ? null : _selectedId,
      unreadOf: _unread,
      onFilter: (f) => setState(() => _filter = f),
      onSearch: (q) => setState(() => _query = q),
      onOpen: _open,
    );
    final chat = _selected;
    final conversation = chat == null
        ? const _EmptyConversation()
        : _ConversationPane(
            key: ValueKey(chat.id),
            chat: chat,
            messages: _messages[chat.id] ?? const [],
            onSend: _send,
            onOpenInfo: () => setState(() => _infoOpen = true),
            onBack: size == ScreenSize.phone
                ? () => setState(() => _selectedId = null)
                : null,
          );
    final info = (chat != null && _infoOpen)
        ? ContactInfoPanel(
            key: ValueKey('info-${chat.id}'),
            chat: chat,
            onClose: () => setState(() => _infoOpen = false),
          )
        : null;

    if (size == ScreenSize.phone) {
      return info ?? (chat == null ? list : conversation);
    }

    final listWidth = size == ScreenSize.desktop ? 360.0 : 320.0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          // Three columns when there is room; otherwise the info panel
          // takes the conversation's place until it is closed.
          final remaining = c.maxWidth - listWidth;
          final infoWidth = remaining >= 900 ? 380.0 : 340.0;
          final threeColumns = remaining >= infoWidth + 380;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: _listContainer(list)),
              if (info == null)
                Expanded(child: conversation)
              else if (threeColumns) ...[
                Expanded(child: conversation),
                Container(
                  width: infoWidth,
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: info,
                ),
              ] else
                Expanded(child: info),
            ],
          );
        },
      ),
    );
  }

  Widget _listContainer(Widget list) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
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
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
  });

  final List<DemoChat> chats;
  final ChatFilter filter;
  final String? selectedId;
  final int Function(DemoChat) unreadOf;
  final ValueChanged<ChatFilter> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<DemoChat> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                _NewChatButton(
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('New chat is coming soon.')),
                    ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SearchField(
              hint: 'Search messages or people',
              onChanged: onSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: FilterChips<ChatFilter>(
              values: ChatFilter.values,
              labels: const ['All', 'Unread', 'Groups', 'Archived'],
              selected: filter,
              onSelected: onFilter,
            ),
          ),
          Expanded(
            child: chats.isEmpty
                ? const Center(
                    child: Text(
                      'No chats here yet',
                      style: TextStyle(color: AppColors.meta),
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

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New chat',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
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
    this.onBack,
  });

  final DemoChat chat;
  final List<DemoMessage> messages;
  final ValueChanged<String> onSend;
  final VoidCallback onOpenInfo;
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
        ),
        Expanded(
          child: _WallpaperBackground(
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
                for (final m in widget.messages)
                  _MessageBubble(message: m, compact: compact),
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
    this.onBack,
  });

  final DemoChat chat;
  final VoidCallback onOpenInfo;
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
            onPressed: () => soon('Video calling'),
            icon: const Icon(Icons.videocam_outlined, size: 27),
            color: AppColors.body,
          ),
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => soon('Voice calling'),
            icon: const Icon(Icons.call_outlined, size: 25),
            color: AppColors.body,
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => soon('Search in chat'),
            icon: const Icon(Icons.search, size: 26),
            color: AppColors.body,
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => soon('Chat options'),
            icon: const Icon(Icons.more_horiz, size: 26),
            color: AppColors.body,
          ),
        ],
      ),
    );
  }
}

class _WallpaperBackground extends StatelessWidget {
  const _WallpaperBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WallpaperPainter(), child: child);
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
  const _MessageBubble({required this.message, required this.compact});

  final DemoMessage message;
  final bool compact;

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
              color: mine ? null : Colors.white,
              gradient: mine
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
