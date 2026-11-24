import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../data/demo_data.dart';
import '../../data/live/chat_info.dart';
import '../../data/live/chat_repo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import 'chat_dialogs.dart';
import 'message_bubble.dart' show formatBytes;

/// Right-hand Contact / Group info panel, opened from the conversation
/// header. Live mode reads the same tables as the phone.
class ContactInfoPanel extends StatefulWidget {
  const ContactInfoPanel({
    super.key,
    required this.chat,
    required this.onClose,
    required this.onMessage,
    required this.onCall,
    required this.onChatTheme,
    required this.onAddMember,
    this.live = false,
    this.messages = const [],
    this.onOpenMedia,
    this.onOpenDocument,
    this.onChatRemoved,
    this.onLockChanged,
  });

  final DemoChat chat;
  final VoidCallback onClose;
  final ValueChanged<bool> onCall;
  final VoidCallback onChatTheme;

  /// Opens the add-members picker (ids already in the group are excluded).
  final void Function(Set<String> existing) onAddMember;

  /// Closes the panel and returns to the conversation.
  final VoidCallback onMessage;

  final bool live;

  /// Messages of this chat (for media, links, files and starred).
  final List<DemoMessage> messages;
  final void Function(DemoMessage m, String url)? onOpenMedia;
  final void Function(DemoMessage m)? onOpenDocument;

  /// The chat was deleted or the group was left.
  final VoidCallback? onChatRemoved;

  /// Lock Chat was switched (true = moved to Private Chats).
  final ValueChanged<bool>? onLockChanged;

  @override
  State<ContactInfoPanel> createState() => _ContactInfoPanelState();
}

enum _More { mute, block, exitGroup, clear, delete }

final _urlRe = RegExp(r'(https?://[^\s]+|www\.[^\s]+)', caseSensitive: false);

class _ContactInfoPanelState extends State<ContactInfoPanel> {
  ChatInfo? _info;
  bool _loading = false;
  bool _demoMuted = false;
  late bool _locked = widget.chat.isLocked;
  bool _lockBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.live) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (!widget.chat.isGroup) {
        _repo.isMyPrivateLock(widget.chat.id).then((v) {
          if (mounted && !_lockBusy) setState(() => _locked = v);
        });
      }
      final i = await ChatInfo.load(widget.chat);
      if (mounted) setState(() => _info = i);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  ChatRepo get _repo => ChatRepo.instance;

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: title,
        width: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                body,
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
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    return ok == true;
  }

  Future<void> _onMore(_More a) async {
    final c = widget.chat;
    if (!widget.live) {
      if (a == _More.mute) {
        setState(() => _demoMuted = !_demoMuted);
      } else {
        _toast('Sign in with your phone to use this.');
      }
      return;
    }
    final i = _info;
    try {
      switch (a) {
        case _More.mute:
          final to = !(i?.muted ?? c.isMuted);
          await _repo.setMuted(c.id, to);
          setState(() => i?.muted = to);
          _toast(to ? 'Notifications muted' : 'Notifications unmuted');
        case _More.block:
          final other = c.otherUserId;
          if (other == null || i == null) return;
          if (i.blockStatus == 'i_blocked') {
            await _repo.unblock(other);
            setState(() => i.blockStatus = 'none');
            _toast('${i.name} unblocked');
          } else {
            final ok = await _confirm(
              'Block ${i.name}?',
              'Blocked contacts can no longer call you or send you messages.',
              'Block',
            );
            if (!ok) return;
            await _repo.block(other);
            setState(() => i.blockStatus = 'i_blocked');
            _toast('${i.name} blocked');
          }
        case _More.exitGroup:
          final ok = await _confirm(
            'Exit "${i?.name ?? c.name}"?',
            'You will stop receiving messages from this group.',
            'Exit group',
          );
          if (!ok) return;
          await _repo.leaveGroup(c.id);
          _toast('You left the group');
          widget.onChatRemoved?.call();
        case _More.clear:
          final ok = await _confirm(
            'Clear this chat?',
            'This deletes all messages in this chat for you only. '
                '${c.isGroup ? 'Other members' : 'The other person'} will '
                'still see them.',
            'Clear chat',
          );
          if (!ok) return;
          await _repo.clearChat(c.id);
          _toast('Chat cleared');
        case _More.delete:
          final ok = await _confirm(
            'Delete this chat?',
            'The chat and its messages are removed from your list on all '
                'your devices.',
            'Delete chat',
          );
          if (!ok) return;
          await _repo.deleteChat(c.id);
          _toast('Chat deleted');
          widget.onChatRemoved?.call();
      }
    } catch (_) {
      _toast('Something went wrong. Try again.');
    }
  }

  /// Lock Chat switch: the app password is asked first (like the phone),
  /// then set_private_lock moves the chat in or out of Private Chats.
  Future<void> _toggleLock(bool to) async {
    if (_lockBusy) return;
    setState(() => _lockBusy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => PasswordGateDialog(
          verify: widget.live ? _repo.verifyAppPassword : null,
        ),
      );
      if (ok != true || !mounted) return;
      if (widget.live) await _repo.setPrivateLock(widget.chat.id, to);
      if (!mounted) return;
      setState(() => _locked = to);
      _toast(
        to
            ? 'Chat locked. It is now in Private Chats.'
            : 'Chat unlocked. It is back in your chats.',
      );
      widget.onLockChanged?.call(to);
    } catch (_) {
      _toast(to ? 'Could not lock this chat' : 'Could not unlock this chat');
    } finally {
      if (mounted) setState(() => _lockBusy = false);
    }
  }

  void _openGroupsInCommon(List<InfoGroup> groups) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Groups in Common',
        width: 440,
        child: groups.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 34),
                child: Text(
                  'No groups in common',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.meta),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final g in groups)
                    _MemberRow(
                      name: g.name,
                      photoUrl: g.avatarUrl,
                      isGroup: true,
                      trailing: '${g.memberCount} members',
                    ),
                ],
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------

  List<(DemoMessage, String)> get _media => [
    for (final m in widget.messages)
      if (m.kind == MessageKind.image)
        for (final u
            in (m.mediaUrls.isNotEmpty
                ? m.mediaUrls
                : [if ((m.mediaUrl ?? '').isNotEmpty) m.mediaUrl!]))
          (m, u)
      else if (m.kind == MessageKind.video && (m.mediaUrl ?? '').isNotEmpty)
        (m, m.mediaUrl!),
  ].reversed.toList();

  List<DemoMessage> get _docs => widget.messages
      .where((m) => m.kind == MessageKind.document)
      .toList()
      .reversed
      .toList();

  List<(DemoMessage, String)> get _links => [
    for (final m in widget.messages)
      if (m.kind == MessageKind.text)
        for (final x in _urlRe.allMatches(m.text)) (m, x.group(0)!),
  ].reversed.toList();

  void _openMediaLinks() {
    showDialog<void>(
      context: context,
      builder: (_) => _MediaLinksDialog(
        media: _media,
        docs: _docs,
        links: _links,
        onOpenMedia: (m, u) {
          Navigator.of(context).pop();
          widget.onOpenMedia?.call(m, u);
        },
        onOpenDocument: (m) {
          Navigator.of(context).pop();
          widget.onOpenDocument?.call(m);
        },
      ),
    );
  }

  void _openImportant() {
    final starred = widget.messages.where((m) => m.isStarred).toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Important',
        width: 460,
        child: starred.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 34),
                child: Text(
                  'Mark messages as important from the message menu to find them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.meta),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: starred.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final m = starred[starred.length - 1 - i];
                  final sender = m.isMine
                      ? 'You'
                      : (m.senderName ?? widget.chat.name);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    leading: const Icon(
                      Icons.label_important_sharp,
                      color: AppColors.accent,
                    ),
                    title: Text(
                      _messageSummary(m),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.heading),
                    ),
                    subtitle: Text(
                      '$sender · ${m.time}',
                      style: const TextStyle(
                        color: AppColors.meta,
                        fontSize: 12.5,
                      ),
                    ),
                    onTap: () {
                      if (m.isMedia) {
                        Navigator.of(ctx).pop();
                        widget.onOpenMedia?.call(
                          m,
                          m.mediaUrls.isNotEmpty
                              ? m.mediaUrls.first
                              : (m.mediaUrl ?? ''),
                        );
                      } else if (m.kind == MessageKind.document) {
                        Navigator.of(ctx).pop();
                        widget.onOpenDocument?.call(m);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chat;
    final group = c.isGroup;
    final i = _info;
    final live = widget.live;

    final name = i?.name ?? c.name;
    final photo = i?.avatarUrl ?? c.avatarUrl;
    final phone = i?.phone ?? c.phone;
    final username = i?.username ?? c.username;
    final about = live
        ? (group ? (i?.description ?? '') : (i?.about ?? ''))
        : c.about;
    final online = i?.isOnline ?? c.isOnline;
    final muted = live ? (i?.muted ?? c.isMuted) : _demoMuted;
    final members = i?.members ?? const <InfoMember>[];
    final memberCount = live ? members.length : c.members.length + 1;
    final blocked = i?.blockStatus == 'i_blocked';
    final privateGroup = i?.isPrivateGroup ?? false;

    final media = live ? _media : const <(DemoMessage, String)>[];
    final docs = live ? _docs : const <DemoMessage>[];
    final links = live ? _links : const <(DemoMessage, String)>[];
    final shownLinks = live
        ? [for (final (_, u) in links) (_linkTitle(u), u)]
        : c.links;
    final mediaSummary = live
        ? '${media.length} Media, ${links.length} Links, ${docs.length} Files'
        : '${c.mediaCount} Media, ${c.links.length} Links, 0 Files';

    String subtitle;
    if (group) {
      subtitle = 'Group · $memberCount members';
    } else {
      subtitle = phone;
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            children: [
              Center(
                child: Avatar(
                  name: name,
                  color: c.avatarColor,
                  photoUrl: photo,
                  isGroup: group,
                  size: 104,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
              ),
              if (!group && username.isNotEmpty)
                _CenterLine(username.startsWith('@') ? username : '@$username'),
              if (subtitle.isNotEmpty) _CenterLine(subtitle),
              if (privateGroup) const _CenterLine('Private group'),
              if (!group) ...[
                const SizedBox(height: 6),
                Center(
                  child: online
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F7DD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF14A23A),
                            ),
                          ),
                        )
                      : (i?.lastSeen != null
                            ? Text(
                                'Last seen ${_lastSeen(i!.lastSeen!)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.meta,
                                ),
                              )
                            : const SizedBox.shrink()),
                ),
              ],
              if (about.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  about,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.body,
                  ),
                ),
              ],
              if (group && i?.createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Created${i!.createdByName == null || i.createdByName!.isEmpty ? '' : ' by ${i.createdByName}'}'
                  ' on ${i.createdAt!.day}/${i.createdAt!.month}/${i.createdAt!.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.meta),
                ),
              ],
              if (_loading && i == null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
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
                ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  _ActionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onTap: widget.onMessage,
                  ),
                  if (!privateGroup && !blocked) ...[
                    _ActionCard(
                      icon: Icons.call,
                      label: 'Voice Call',
                      onTap: () => widget.onCall(false),
                    ),
                    _ActionCard(
                      icon: Icons.videocam,
                      label: 'Video Call',
                      onTap: () => widget.onCall(true),
                    ),
                  ],
                  Expanded(
                    child: PopupMenuButton<_More>(
                      tooltip: 'More',
                      position: PopupMenuPosition.under,
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: _onMore,
                      itemBuilder: (_) => [
                        _check(_More.mute, 'Mute notifications', muted),
                        const PopupMenuDivider(),
                        _plain(_More.clear, 'Clear chat'),
                        if (group)
                          _danger(_More.exitGroup, 'Exit group')
                        else
                          blocked
                              ? _plain(_More.block, 'Unblock $name')
                              : _danger(_More.block, 'Block $name'),
                        _danger(_More.delete, 'Delete chat'),
                      ],
                      child: const _ActionCardBody(
                        icon: Icons.more_horiz,
                        label: 'More',
                      ),
                    ),
                  ),
                ],
              ),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'You blocked $name. Unblock to call or message.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.missed,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Lock Chat (one-to-one chats, same as the phone)
              if (!group)
                _Row(
                  icon: Icons.private_connectivity_outlined,
                  title: 'Lock Chat',
                  subtitle: _locked
                      ? 'Unlock and unhide this chat on this device.'
                      : 'Lock and hide this chat on this device.',
                  onTap: () => _toggleLock(!_locked),
                  trailing: Switch(
                    value: _locked,
                    onChanged: _lockBusy ? null : _toggleLock,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFD5D9DE),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ),

              // Media, links and files
              _Row(
                icon: Icons.perm_media_outlined,
                title: 'Media, Links and Files',
                subtitle: mediaSummary,
                onTap: live
                    ? _openMediaLinks
                    : () => _toast(
                        'Sign in with your phone to see shared media.',
                      ),
                last: media.isNotEmpty || shownLinks.isNotEmpty,
              ),
              if (media.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                  child: Row(
                    children: [
                      for (final (m, u) in media.take(4))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _Thumb(
                              message: m,
                              url: u,
                              onTap: () => widget.onOpenMedia?.call(m, u),
                            ),
                          ),
                        ),
                      for (var k = media.length; k < 4; k++)
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              if (shownLinks.isNotEmpty) ...[
                const _SectionTitle('Links'),
                for (final l in shownLinks.take(3))
                  _LinkRow(title: l.$1, url: l.$2),
                if (shownLinks.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _openMediaLinks,
                      child: Text(
                        'See all ${shownLinks.length} links',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ),
              ],
              if (media.isNotEmpty || shownLinks.isNotEmpty)
                const Divider(height: 14, color: AppColors.border),

              // Members (groups) or groups in common (people)
              if (group) ...[
                _SectionTitle('Members ($memberCount)'),
                if (!live || (i?.iAmAdmin ?? false))
                  _MemberRow(
                    name: 'Add member',
                    isAction: true,
                    onTap: () =>
                        widget.onAddMember({for (final m in members) m.userId}),
                  ),
                if (live)
                  for (final m in members)
                    _MemberRow(
                      name: m.name,
                      photoUrl: m.avatarUrl,
                      isAdmin: m.isAdmin,
                    )
                else ...[
                  const _MemberRow(name: 'You', isAdmin: true),
                  for (final m in c.members) _MemberRow(name: m),
                ],
                const Divider(height: 14, color: AppColors.border),
              ] else
                _Row(
                  icon: Icons.group_outlined,
                  title: 'Groups in Common',
                  subtitle: live
                      ? '${i?.groupsInCommon.length ?? 0} Groups'
                      : '${c.groupsInCommon} Groups',
                  onTap: live
                      ? () => _openGroupsInCommon(
                          i?.groupsInCommon ?? const <InfoGroup>[],
                        )
                      : () => _toast(
                          'Sign in with your phone to see groups in common.',
                        ),
                ),
              _Row(
                icon: Icons.label_important_outline_sharp,
                title: 'Important',
                subtitle: 'View important chats',
                onTap: _openImportant,
              ),
              _Row(
                leading: const FaIcon(
                  FontAwesomeIcons.broom,
                  color: AppColors.accent,
                  size: 21,
                ),
                title: 'Clear Chat',
                subtitle: 'Delete all messages in this chat',
                onTap: () => _onMore(_More.clear),
              ),
              _Row(
                icon: Icons.palette_outlined,
                title: 'Chat Theme',
                subtitle: 'Pick your preference',
                onTap: widget.onChatTheme,
                last: true,
              ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: AppColors.body, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_More> _check(_More a, String label, bool on) {
    return PopupMenuItem(
      value: a,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Icon(
            on ? Icons.toggle_on : Icons.toggle_off_outlined,
            color: on ? AppColors.accent : AppColors.meta,
            size: 30,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_More> _plain(_More a, String label) =>
      PopupMenuItem(value: a, child: Text(label));

  PopupMenuItem<_More> _danger(_More a, String label) {
    return PopupMenuItem(
      value: a,
      child: Text(label, style: const TextStyle(color: AppColors.missed)),
    );
  }
}

/// Short label for a link: its host without "www.".
String _linkTitle(String url) {
  final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
  final h = (u?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
  return h.isEmpty ? url : h;
}

String _messageSummary(DemoMessage m) {
  final t = m.text.trim();
  return switch (m.kind) {
    MessageKind.image => t.isEmpty ? 'Photo' : 'Photo: $t',
    MessageKind.video => t.isEmpty ? 'Video' : 'Video: $t',
    MessageKind.voice => 'Voice message',
    MessageKind.document => t.isEmpty ? 'Document' : t,
    _ => t,
  };
}

String _lastSeen(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t =
      '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  if (diff == 0) return 'today at $t';
  if (diff == 1) return 'yesterday at $t';
  return '${d.day}/${d.month}/${d.year}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.heading,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.message, required this.url, required this.onTap});

  final DemoMessage message;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final video = message.kind == MessageKind.video;
    final src = video ? message.thumbUrl : url;
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (src != null && src.isNotEmpty)
                Image.network(
                  src,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppColors.accentSoft),
                )
              else
                Container(color: const Color(0xFF2A1450)),
              if (video)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaLinksDialog extends StatefulWidget {
  const _MediaLinksDialog({
    required this.media,
    required this.docs,
    required this.links,
    required this.onOpenMedia,
    required this.onOpenDocument,
  });

  final List<(DemoMessage, String)> media;
  final List<DemoMessage> docs;
  final List<(DemoMessage, String)> links;
  final void Function(DemoMessage m, String url) onOpenMedia;
  final void Function(DemoMessage m) onOpenDocument;

  @override
  State<_MediaLinksDialog> createState() => _MediaLinksDialogState();
}

class _MediaLinksDialogState extends State<_MediaLinksDialog> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Media (${widget.media.length})',
      'Files (${widget.docs.length})',
      'Links (${widget.links.length})',
    ];
    Widget empty(String t) => Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Text(t, style: const TextStyle(color: AppColors.meta)),
      ),
    );
    final Widget body = switch (_tab) {
      0 =>
        widget.media.isEmpty
            ? empty('No photos or videos yet')
            : GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                children: [
                  for (final (m, u) in widget.media)
                    _Thumb(
                      message: m,
                      url: u,
                      onTap: () => widget.onOpenMedia(m, u),
                    ),
                ],
              ),
      1 =>
        widget.docs.isEmpty
            ? empty('No files yet')
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final d in widget.docs)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppColors.accent,
                        ),
                      ),
                      title: Text(
                        d.text.isEmpty ? 'Document' : d.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.heading,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (d.raw['media_size_bytes'] is int)
                            formatBytes(d.raw['media_size_bytes'] as int),
                          d.time,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.meta),
                      ),
                      onTap: () => widget.onOpenDocument(d),
                    ),
                ],
              ),
      _ =>
        widget.links.isEmpty
            ? empty('No links yet')
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final (_, url) in widget.links)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => web.window.open(
                        url.startsWith('http') ? url : 'https://$url',
                        '_blank',
                        'noopener',
                      ),
                      child: _LinkRow(
                        title:
                            Uri.tryParse(
                              url.startsWith('http') ? url : 'https://$url',
                            )?.host ??
                            url,
                        url: url,
                      ),
                    ),
                ],
              ),
    };
    return DialogShell(
      title: 'Media, Links and Files',
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              children: [
                for (var k = 0; k < tabs.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tabs[k]),
                      selected: _tab == k,
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.lavenderSoft,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: _tab == k ? Colors.white : AppColors.body,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _tab = k),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(child: body),
        ],
      ),
    );
  }
}

class _CenterLine extends StatelessWidget {
  const _CenterLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, color: AppColors.body),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: _ActionCardBody(icon: icon, label: label),
      ),
    );
  }
}

class _ActionCardBody extends StatelessWidget {
  const _ActionCardBody({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.last = false,
  });

  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Center(
                child: leading ?? Icon(icon, color: AppColors.accent, size: 26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.body),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.body,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.url});

  final String title;
  final String url;

  void _open() {
    final u = url.startsWith('http') ? url : 'https://$url';
    web.window.open(u, '_blank', 'noopener');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.accent,
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
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    this.isAdmin = false,
    this.isAction = false,
    this.isGroup = false,
    this.photoUrl,
    this.trailing,
    this.onTap,
  });

  final String name;
  final bool isAdmin;
  final bool isAction;
  final bool isGroup;
  final String? photoUrl;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            if (isAction)
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.white,
                  size: 20,
                ),
              )
            else
              Avatar(
                name: name,
                size: 38,
                photoUrl: photoUrl,
                isGroup: isGroup,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isAction ? AppColors.accent : AppColors.heading,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(fontSize: 12, color: AppColors.meta),
              ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(fontSize: 12, color: AppColors.accentDark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
