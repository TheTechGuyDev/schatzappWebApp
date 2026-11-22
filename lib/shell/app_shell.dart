import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/demo_data.dart';
import '../auth/web_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_logo.dart';
import '../widgets/nav_icons.dart';

/// Screen size classes used across the signed-in app.
enum ScreenSize { phone, tablet, desktop }

ScreenSize screenSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 720) return ScreenSize.phone;
  if (w < 1100) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

class _NavItem {
  const _NavItem(this.path, this.label, this.kind, [this.badge = 0]);

  final String path;
  final String label;
  final NavIconKind kind;
  final int badge;
}

const _navItems = [
  _NavItem('/chats', 'Chats', NavIconKind.chats, 1),
  _NavItem('/calls', 'Calls', NavIconKind.calls),
  _NavItem('/wallets', 'Wallets', NavIconKind.wallets),
  _NavItem('/stories', 'Stories', NavIconKind.stories),
  _NavItem('/profile', 'Profile', NavIconKind.profile, 1),
];

/// Signed-in layout: left nav rail on desktop (collapsible) and tablet
/// (collapsed), bottom navigation on phone widths.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;

  int get _index {
    final i = _navItems.indexWhere((n) => widget.location.startsWith(n.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);

    if (size == ScreenSize.phone) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: widget.child),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accentSoft,
          selectedIndex: _index,
          onDestinationSelected: (i) => context.go(_navItems[i].path),
          destinations: [
            for (final n in _navItems)
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: n.badge > 0,
                  label: Text('${n.badge}'),
                  backgroundColor: AppColors.accent,
                  child: NavIcon(n.kind, color: AppColors.body, size: 24),
                ),
                selectedIcon: Badge(
                  isLabelVisible: n.badge > 0,
                  label: Text('${n.badge}'),
                  backgroundColor: AppColors.accent,
                  child: NavIcon(
                    n.kind,
                    color: AppColors.accent,
                    size: 24,
                    active: true,
                  ),
                ),
                label: n.label,
              ),
          ],
        ),
      );
    }

    final collapsed = size == ScreenSize.tablet || _collapsed;
    return Scaffold(
      backgroundColor: AppColors.railBg,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: collapsed ? 84 : 244,
            child: _Rail(
              collapsed: collapsed,
              selected: _index,
              canToggle: size == ScreenSize.desktop,
              onToggle: () => setState(() => _collapsed = !_collapsed),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.collapsed,
    required this.selected,
    required this.canToggle,
    required this.onToggle,
  });

  final bool collapsed;
  final int selected;
  final bool canToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final hPad = collapsed ? 12.0 : 18.0;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: collapsed ? 84 : 244,
        maxWidth: collapsed ? 84 : 244,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 26),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (collapsed)
                    const SMark(size: 42)
                  else ...[
                    const SizedBox(width: 2),
                    const _GradientWordmark(),
                  ],
                ],
              ),
            ),
            if (canToggle)
              Align(
                alignment: collapsed ? Alignment.center : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: collapsed ? 0 : 6, top: 4),
                  child: IconButton(
                    tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    color: AppColors.meta,
                    onPressed: onToggle,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const Divider(height: 1, color: AppColors.border),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _navItems.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 3),
                child: _RailItem(
                  item: _navItems[i],
                  active: i == selected,
                  collapsed: collapsed,
                ),
              ),
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const Divider(height: 1, color: AppColors.border),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const Divider(height: 1, color: AppColors.border),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
              child: collapsed
                  ? const Center(
                      child: Avatar(
                        name: demoCurrentUserName,
                        size: 46,
                        isOnline: true,
                      ),
                    )
                  : const _UserTile(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientWordmark extends StatelessWidget {
  const _GradientWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SMark(size: 44),
        const SizedBox(width: 6),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFFA62BE4), Color(0xFF8A3BEB), Color(0xFF5F6CF0)],
          ).createShader(r),
          child: const Text(
            'SchatzApp',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.active,
    required this.collapsed,
  });

  final _NavItem item;
  final bool active;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.heading;
    final icon = NavIcon(
      item.kind,
      color: active ? AppColors.accent : AppColors.heading,
      active: active,
      size: 26,
    );
    final tile = Material(
      color: active ? AppColors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.path),
        child: SizedBox(
          height: 48,
          child: collapsed
              ? Center(
                  child: Badge(
                    isLabelVisible: item.badge > 0,
                    label: Text('${item.badge}'),
                    backgroundColor: AppColors.accent,
                    child: icon,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      icon,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                      if (item.badge > 0) CountBadge(item.badge, size: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: item.label, child: tile) : tile;
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Avatar(name: demoCurrentUserName, size: 46),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                demoCurrentUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading,
                ),
              ),
              SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: AppColors.online),
                  SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(fontSize: 14, color: AppColors.body),
                  ),
                ],
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(Icons.more_horiz, color: AppColors.body),
          onSelected: (v) {
            if (v == 'logout') WebAuth.instance.signOut();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'logout', child: Text('Log out')),
          ],
        ),
      ],
    );
  }
}

/// White rounded panel used for list / detail columns.
class ShellPanel extends StatelessWidget {
  const ShellPanel({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.radius = 22,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsets margin;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDeep.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
