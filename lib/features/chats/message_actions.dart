import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import 'chat_dialogs.dart';
import 'composer.dart' show EmojiGrid;

/// Reactions offered first, like the phone.
const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

enum MsgAction {
  reply,
  copy,
  forward,
  pin,
  unpin,
  star,
  unstar,
  edit,
  save,
  delete,
}

/// What the user picked from the message menu.
typedef MenuPick = ({MsgAction? action, String? reaction, bool morePicker});

RelativeRect _at(BuildContext context, Offset p) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return RelativeRect.fromRect(
    Rect.fromLTWH(p.dx, p.dy, 1, 1),
    Offset.zero & overlay.size,
  );
}

final _menuShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16),
  side: const BorderSide(color: AppColors.border),
);

/// The message menu: a reaction row, then the actions this message allows.
Future<MenuPick?> showMessageMenu(
  BuildContext context, {
  required Offset at,
  required DemoMessage message,
  required bool canEdit,
}) async {
  final m = message;
  final hasText = m.text.trim().isNotEmpty && m.kind != MessageKind.call;
  final canSave =
      m.isMedia ||
      m.kind == MessageKind.document ||
      m.kind == MessageKind.voice;
  final forwardable = m.kind != MessageKind.call && m.kind != MessageKind.gift;
  final v = await showMenu<Object>(
    context: context,
    position: _at(context, at),
    color: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 10,
    shadowColor: const Color(0x405B1CD3),
    shape: _menuShape,
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
    items: [
      _ReactRow(selected: m.myReaction),
      const PopupMenuDivider(height: 6),
      _item(MsgAction.reply, Icons.reply_rounded, 'Reply'),
      if (hasText) _item(MsgAction.copy, Icons.copy_rounded, 'Copy'),
      if (forwardable)
        _item(MsgAction.forward, Icons.shortcut_rounded, 'Forward'),
      m.isPinned
          ? _item(MsgAction.unpin, Icons.push_pin_outlined, 'Unpin')
          : _item(MsgAction.pin, Icons.push_pin_outlined, 'Pin'),
      m.isStarred
          ? _item(
              MsgAction.unstar,
              Icons.label_important_sharp,
              'Unmark as important',
            )
          : _item(
              MsgAction.star,
              Icons.label_important_outline_sharp,
              'Mark as important',
            ),
      if (canEdit) _item(MsgAction.edit, Icons.edit_outlined, 'Edit'),
      if (canSave) _item(MsgAction.save, Icons.download_rounded, 'Download'),
      const PopupMenuDivider(height: 6),
      _item(
        MsgAction.delete,
        Icons.delete_outline_rounded,
        'Delete',
        danger: true,
      ),
    ],
  );
  if (v is MsgAction) return (action: v, reaction: null, morePicker: false);
  if (v is String) {
    return v == '+'
        ? (action: null, reaction: null, morePicker: true)
        : (action: null, reaction: v, morePicker: false);
  }
  return null;
}

PopupMenuItem<Object> _item(
  MsgAction a,
  IconData icon,
  String label, {
  bool danger = false,
}) {
  final color = danger ? AppColors.missed : AppColors.heading;
  return PopupMenuItem<Object>(
    value: a,
    height: 42,
    child: Row(
      children: [
        Icon(icon, size: 20, color: danger ? AppColors.missed : AppColors.body),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 14.5, color: color)),
      ],
    ),
  );
}

class _ReactRow extends PopupMenuEntry<Object> {
  const _ReactRow({this.selected});

  final String? selected;

  @override
  double get height => 52;

  @override
  bool represents(Object? value) => false;

  @override
  State<_ReactRow> createState() => _ReactRowState();
}

class _ReactRowState extends State<_ReactRow> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final e in quickReactions)
            _EmojiDot(
              emoji: e,
              selected: widget.selected == e,
              onTap: () => Navigator.of(context).pop(e),
            ),
          Tooltip(
            message: 'More reactions',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop('+'),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.lavenderSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 20, color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiDot extends StatelessWidget {
  const _EmojiDot({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.accentSoft : Colors.transparent,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 21)),
      ),
    );
  }
}

/// Quick reactions only (hover react button).
Future<String?> showReactionPicker(
  BuildContext context, {
  required Offset at,
  String? selected,
  bool full = false,
}) async {
  final v = await showMenu<Object>(
    context: context,
    position: _at(context, at),
    color: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 10,
    shadowColor: const Color(0x405B1CD3),
    shape: _menuShape,
    constraints: BoxConstraints(maxWidth: full ? 360 : 320),
    items: [full ? const _FullEmojiEntry() : _ReactRow(selected: selected)],
  );
  if (v == '+') {
    if (!context.mounted) return null;
    return showReactionPicker(context, at: at, full: true);
  }
  return v is String ? v : null;
}

class _FullEmojiEntry extends PopupMenuEntry<Object> {
  const _FullEmojiEntry();

  @override
  double get height => 300;

  @override
  bool represents(Object? value) => false;

  @override
  State<_FullEmojiEntry> createState() => _FullEmojiEntryState();
}

class _FullEmojiEntryState extends State<_FullEmojiEntry> {
  @override
  Widget build(BuildContext context) {
    return EmojiGrid(onPick: (e) => Navigator.of(context).pop(e));
  }
}

// ---------------------------------------------------------------------------
// Delete
// ---------------------------------------------------------------------------

enum DeleteChoice { forMe, forEveryone }

Future<DeleteChoice?> showDeleteDialog(
  BuildContext context, {
  required bool own,
  String? blockReason,
}) {
  return showDialog<DeleteChoice>(
    context: context,
    builder: (ctx) => DialogShell(
      title: 'Delete message?',
      width: 400,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (own && blockReason == null) ...[
              _DialogButton(
                label: 'Delete for everyone',
                color: AppColors.missed,
                onTap: () => Navigator.of(ctx).pop(DeleteChoice.forEveryone),
              ),
              const SizedBox(height: 10),
            ],
            if (own && blockReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  blockReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.meta),
                ),
              ),
            _DialogButton(
              label: 'Delete for me',
              color: AppColors.accent,
              onTap: () => Navigator.of(ctx).pop(DeleteChoice.forMe),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.body, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit
// ---------------------------------------------------------------------------

Future<String?> showEditDialog(BuildContext context, String current) {
  final c = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => DialogShell(
      title: 'Edit message',
      width: 460,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.lavenderSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DialogButton(
              label: 'Save',
              color: AppColors.accent,
              onTap: () => Navigator.of(ctx).pop(c.text.trim()),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Forward
// ---------------------------------------------------------------------------

typedef ForwardTargets = ({List<String> conversationIds, List<String> userIds});

/// Pick up to 5 chats or contacts to forward to.
class ForwardDialog extends StatefulWidget {
  const ForwardDialog({
    super.key,
    required this.chats,
    required this.loadContacts,
  });

  final List<DemoChat> chats;
  final Future<List<DemoContact>> Function() loadContacts;

  @override
  State<ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<ForwardDialog> {
  static const _max = 5;
  String _q = '';
  final Set<String> _convs = {};
  final Set<String> _users = {};
  List<DemoContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    widget
        .loadContacts()
        .then((c) {
          if (mounted) setState(() => _contacts = c);
        })
        .catchError((Object _) {});
  }

  int get _count => _convs.length + _users.length;

  void _toggle(Set<String> set, String id) {
    setState(() {
      if (set.contains(id)) {
        set.remove(id);
      } else if (_count < _max) {
        set.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can forward to up to 5 chats.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool match(String s) => _q.isEmpty || s.toLowerCase().contains(_q);
    final chats = widget.chats.where((c) => match(c.name)).toList();
    // People who already have a chat show once, as that chat.
    final withChat = widget.chats
        .map((c) => c.otherUserId)
        .whereType<String>()
        .toSet();
    final contacts = _contacts
        .where((c) => c.userId != null && !withChat.contains(c.userId))
        .where((c) => match(c.name))
        .toList();

    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.meta,
        ),
      ),
    );

    Widget tile({
      required String name,
      required bool picked,
      required VoidCallback onTap,
      String? photo,
      bool group = false,
    }) => CheckboxListTile(
      value: picked,
      onChanged: (_) => onTap(),
      activeColor: AppColors.accent,
      controlAffinity: ListTileControlAffinity.trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      secondary: Avatar(name: name, photoUrl: photo, isGroup: group, size: 42),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.heading,
        ),
      ),
    );

    return DialogShell(
      title: 'Forward message',
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: SearchField(
              hint: 'Search chats or contacts',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                if (chats.isNotEmpty) header('Recent chats'),
                for (final c in chats)
                  tile(
                    name: c.name,
                    photo: c.avatarUrl,
                    group: c.isGroup,
                    picked: _convs.contains(c.id),
                    onTap: () => _toggle(_convs, c.id),
                  ),
                if (contacts.isNotEmpty) header('Other contacts'),
                for (final c in contacts)
                  tile(
                    name: c.name,
                    photo: c.avatarUrl,
                    picked: _users.contains(c.userId),
                    onTap: () => _toggle(_users, c.userId!),
                  ),
                if (chats.isEmpty && contacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: Text(
                        'No chats found',
                        style: TextStyle(color: AppColors.meta),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _count == 0
                    ? null
                    : () => Navigator.of(context).pop<ForwardTargets>((
                        conversationIds: _convs.toList(),
                        userIds: _users.toList(),
                      )),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _count == 0 ? 'Forward' : 'Forward ($_count)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
