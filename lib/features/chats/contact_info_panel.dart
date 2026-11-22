import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

/// Right-hand profile panel, opened by tapping the avatar or name in the
/// conversation header. Layout follows the supplied Contact Info design.
/// Placeholder data for now.
class ContactInfoPanel extends StatefulWidget {
  const ContactInfoPanel({
    super.key,
    required this.chat,
    required this.onClose,
    required this.onMessage,
  });

  final DemoChat chat;
  final VoidCallback onClose;

  /// Closes the panel and returns to the conversation.
  final VoidCallback onMessage;

  @override
  State<ContactInfoPanel> createState() => _ContactInfoPanelState();
}

enum _MoreAction { mute, lock, saveMedia, block, exitGroup, report, delete }

class _ContactInfoPanelState extends State<ContactInfoPanel> {
  bool _muted = false;
  bool _locked = false;
  bool _saveMedia = true;

  void _soon(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));

  void _onMore(_MoreAction a) {
    switch (a) {
      case _MoreAction.mute:
        setState(() => _muted = !_muted);
      case _MoreAction.lock:
        setState(() => _locked = !_locked);
      case _MoreAction.saveMedia:
        setState(() => _saveMedia = !_saveMedia);
      case _MoreAction.block:
        _soon('Block');
      case _MoreAction.exitGroup:
        _soon('Exit group');
      case _MoreAction.report:
        _soon('Report');
      case _MoreAction.delete:
        _soon('Delete chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chat;
    final group = c.isGroup;
    final mediaSummary =
        '${c.mediaCount} Media, ${c.links.length} Links, 0 Files';

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            children: [
              // Identity
              Center(
                child: Avatar(
                  name: c.name,
                  color: c.avatarColor,
                  isGroup: group,
                  size: 104,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _soon(group ? 'Edit group' : 'Edit contact name'),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.heading,
                      ),
                    ),
                  ),
                ],
              ),
              if (!group && c.username.isNotEmpty) _CenterLine(c.username),
              _CenterLine(
                group ? 'Group · ${c.members.length + 1} members' : c.phone,
              ),
              if (!group && c.isOnline) ...[
                const SizedBox(height: 6),
                Center(
                  child: Container(
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
                  ),
                ),
              ],
              if (c.about.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  c.about,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.body,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  _ActionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onTap: widget.onMessage,
                  ),
                  _ActionCard(
                    icon: Icons.call,
                    label: 'Voice Call',
                    onTap: () => _soon('Voice calling'),
                  ),
                  _ActionCard(
                    icon: Icons.videocam,
                    label: 'Video Call',
                    onTap: () => _soon('Video calling'),
                  ),
                  Expanded(
                    child: PopupMenuButton<_MoreAction>(
                      tooltip: 'More',
                      position: PopupMenuPosition.under,
                      onSelected: _onMore,
                      itemBuilder: (_) => [
                        _check(_MoreAction.mute, 'Mute notifications', _muted),
                        _check(_MoreAction.lock, 'Lock chat', _locked),
                        _check(
                          _MoreAction.saveMedia,
                          'Save to gallery',
                          _saveMedia,
                        ),
                        const PopupMenuDivider(),
                        if (group)
                          _danger(_MoreAction.exitGroup, 'Exit group')
                        else
                          _danger(_MoreAction.block, 'Block ${c.name}'),
                        _danger(
                          _MoreAction.report,
                          group ? 'Report group' : 'Report ${c.name}',
                        ),
                        _danger(_MoreAction.delete, 'Delete chat'),
                      ],
                      child: const _ActionCardBody(
                        icon: Icons.more_horiz,
                        label: 'More',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Media and links
              _Row(
                icon: Icons.perm_media_outlined,
                title: 'Media, Links and Files',
                subtitle: mediaSummary,
                onTap: () => _soon('Media, links and files'),
              ),
              if (c.links.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    'Links',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                for (final l in c.links) _LinkRow(title: l.$1, url: l.$2),
                const Divider(height: 14, color: AppColors.border),
              ],

              // Members (groups) or groups in common (people)
              if (group) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                _MemberRow(
                  name: 'Add member',
                  isAction: true,
                  onTap: () => _soon('Add member'),
                ),
                const _MemberRow(name: 'You', isAdmin: true),
                for (final m in c.members) _MemberRow(name: m),
                const Divider(height: 14, color: AppColors.border),
              ] else
                _Row(
                  icon: Icons.groups_outlined,
                  title: 'Groups in Common',
                  subtitle: '${c.groupsInCommon} Groups',
                  onTap: () => _soon('Groups in common'),
                ),
              _Row(
                icon: Icons.bookmark_border_rounded,
                title: 'Important',
                subtitle: 'View important chats',
                onTap: () => _soon('Important messages'),
              ),
              _Row(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Chat',
                subtitle: 'Delete all messages in this chat',
                onTap: () => _soon('Clear chat'),
              ),
              _Row(
                icon: Icons.palette_outlined,
                title: 'Chat Theme',
                subtitle: 'Pick your preference',
                onTap: () => _soon('Chat theme'),
                last: group,
              ),
              if (!group)
                _Row(
                  icon: Icons.people_alt_outlined,
                  title: 'Mutual Contacts',
                  subtitle: '${c.mutualContacts} Friends',
                  onTap: () => _soon('Mutual contacts'),
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

  PopupMenuItem<_MoreAction> _check(_MoreAction a, String label, bool on) {
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

  PopupMenuItem<_MoreAction> _danger(_MoreAction a, String label) {
    return PopupMenuItem(
      value: a,
      child: Text(label, style: const TextStyle(color: AppColors.missed)),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
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
              child: Icon(icon, color: AppColors.accent, size: 26),
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
            const Icon(Icons.chevron_right, color: AppColors.body, size: 22),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
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
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    this.isAdmin = false,
    this.isAction = false,
    this.onTap,
  });

  final String name;
  final bool isAdmin;
  final bool isAction;
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
                color: name == 'You' ? null : const Color(0xFF8A6A55),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isAction ? AppColors.accent : AppColors.heading,
                ),
              ),
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
