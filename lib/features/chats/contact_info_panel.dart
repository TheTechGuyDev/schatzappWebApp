import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/sunset_painter.dart';

/// Right-hand "Contact info" / "Group info" panel, opened by tapping the
/// avatar or name in the conversation header (WhatsApp Web style).
/// Items mirror the mobile app's user_profile page. Placeholder data for now.
class ContactInfoPanel extends StatefulWidget {
  const ContactInfoPanel({
    super.key,
    required this.chat,
    required this.onClose,
  });

  final DemoChat chat;
  final VoidCallback onClose;

  @override
  State<ContactInfoPanel> createState() => _ContactInfoPanelState();
}

class _ContactInfoPanelState extends State<ContactInfoPanel> {
  bool _muted = false;
  bool _locked = false;
  bool _saveMedia = true;

  void _soon(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));

  @override
  Widget build(BuildContext context) {
    final c = widget.chat;
    final group = c.isGroup;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: AppColors.heading),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group ? 'Group info' : 'Contact info',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                if (group)
                  IconButton(
                    tooltip: 'Edit group',
                    onPressed: () => _soon('Edit group'),
                    icon: const Icon(Icons.edit_outlined, size: 22),
                    color: AppColors.body,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Identity
                const SizedBox(height: 26),
                Center(
                  child: Avatar(
                    name: c.name,
                    color: c.avatarColor,
                    isGroup: group,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    c.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  group
                      ? 'Group · ${c.members.length + 1} members'
                      : (c.phone.isEmpty ? '' : c.phone),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.meta),
                ),
                if (!group && c.isOnline) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Online',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.online),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      icon: Icons.call_outlined,
                      label: 'Voice',
                      onTap: () => _soon('Voice calling'),
                    ),
                    const SizedBox(width: 18),
                    _RoundAction(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      onTap: () => _soon('Video calling'),
                    ),
                    const SizedBox(width: 18),
                    _RoundAction(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () => _soon('Search in chat'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionDivider(),

                // About / description
                if (c.about.isNotEmpty || group) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group ? 'Description' : 'About',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.meta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c.about.isEmpty ? 'Add group description' : c.about,
                          style: TextStyle(
                            fontSize: 16,
                            color: c.about.isEmpty
                                ? AppColors.accent
                                : AppColors.heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SectionDivider(),
                ],

                // Media
                _Tile(
                  icon: Icons.perm_media_outlined,
                  title: 'Media, links and files',
                  trailingText: '${c.mediaCount}',
                  onTap: () => _soon('Media, links and files'),
                ),
                if (c.mediaCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _MediaThumb(index: i)),
                        ],
                      ],
                    ),
                  ),
                const _SectionDivider(),

                // Settings
                _Tile(
                  icon: Icons.star_border_rounded,
                  title: 'Important messages',
                  subtitle: 'View important chats',
                  onTap: () => _soon('Important messages'),
                ),
                _Tile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Mute notifications',
                  trailing: Switch(
                    value: _muted,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _muted = v),
                  ),
                  onTap: () => setState(() => _muted = !_muted),
                ),
                _Tile(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Save to gallery',
                  subtitle: 'Automatically save media',
                  trailing: Switch(
                    value: _saveMedia,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _saveMedia = v),
                  ),
                  onTap: () => setState(() => _saveMedia = !_saveMedia),
                ),
                _Tile(
                  icon: Icons.palette_outlined,
                  title: 'Chat theme',
                  subtitle: 'Pick your preference',
                  onTap: () => _soon('Chat theme'),
                ),
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Lock chat',
                  subtitle: _locked
                      ? 'Unlock and unhide this chat.'
                      : 'Lock and hide this chat behind your app password.',
                  trailing: Switch(
                    value: _locked,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _locked = v),
                  ),
                  onTap: () => setState(() => _locked = !_locked),
                ),
                const _SectionDivider(),

                // Groups in common / members
                if (group) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                    child: Text(
                      '${c.members.length + 1} members',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.meta,
                      ),
                    ),
                  ),
                  _Tile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    title: 'Add member',
                    titleColor: AppColors.accent,
                    onTap: () => _soon('Add member'),
                  ),
                  const _MemberTile(
                    name: 'You',
                    subtitle: demoCurrentUserName,
                    isAdmin: true,
                  ),
                  for (final m in c.members) _MemberTile(name: m),
                  const _SectionDivider(),
                ] else ...[
                  _Tile(
                    icon: Icons.groups_outlined,
                    title: 'Groups in common',
                    trailingText: '1',
                    onTap: () => _soon('Groups in common'),
                  ),
                  _Tile(
                    icon: Icons.people_outline,
                    title: 'Mutual contacts',
                    onTap: () => _soon('Mutual contacts'),
                  ),
                  const _SectionDivider(),
                ],

                // Danger zone
                _Tile(
                  icon: Icons.remove_circle_outline,
                  title: 'Clear chat',
                  subtitle: 'Delete all messages in this chat',
                  danger: true,
                  onTap: () => _soon('Clear chat'),
                ),
                if (group)
                  _Tile(
                    icon: Icons.logout,
                    title: 'Exit group',
                    danger: true,
                    onTap: () => _soon('Exit group'),
                  )
                else
                  _Tile(
                    icon: Icons.block,
                    title: 'Block ${c.name}',
                    danger: true,
                    onTap: () => _soon('Block'),
                  ),
                _Tile(
                  icon: Icons.thumb_down_alt_outlined,
                  title: group ? 'Report group' : 'Report ${c.name}',
                  danger: true,
                  onTap: () => _soon('Report'),
                ),
                _Tile(
                  icon: Icons.delete_outline,
                  title: 'Delete chat',
                  danger: true,
                  onTap: () => _soon('Delete chat'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: const Color(0xFFF6F3FB));
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3ECFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6DAFA)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.danger = false,
    this.titleColor,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingText;
  final bool danger;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.missed : (titleColor ?? AppColors.heading);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        child: Row(
          children: [
            leading ??
                Icon(
                  icon,
                  size: 24,
                  color: danger ? AppColors.missed : AppColors.body,
                ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.meta,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(fontSize: 15, color: AppColors.meta),
              ),
            if (trailingText != null && trailing == null)
              const Icon(Icons.chevron_right, color: AppColors.meta),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.name, this.subtitle, this.isAdmin = false});

  final String name;
  final String? subtitle;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      child: Row(
        children: [
          Avatar(
            name: name,
            size: 44,
            color: name == 'You' ? null : const Color(0xFF8A6A55),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.heading,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 13, color: AppColors.meta),
                  ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Group admin',
                style: TextStyle(fontSize: 12, color: AppColors.accentDark),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [Color(0xFF9B5DE5), Color(0xFF5B1CD3)],
      [Color(0xFF39D2C0), Color(0xFF1F8A99)],
    ];
    return SizedBox(
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: index == 0
            ? CustomPaint(painter: SunsetPainter())
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradients[(index - 1) % gradients.length],
                  ),
                ),
                child: Icon(
                  index == 1 ? Icons.description_outlined : Icons.link,
                  color: Colors.white,
                  size: 30,
                ),
              ),
      ),
    );
  }
}
