import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// Left-menu icons, copied exactly from the mobile app's home tab bar
/// (chat/home_page/home_page_widget.dart):
/// - Chats:   FontAwesome comment (regular, 0xf075)
/// - Calls:   Icons.call_outlined
/// - Wallets: FontAwesome wallet (solid, 0xf555)
/// - Stories: FontAwesome hornbill (brands, 0xf592)
/// - Profile: Icons.person_3_outlined
enum NavIconKind { chats, calls, wallets, stories, profile }

class NavIcon extends StatelessWidget {
  const NavIcon(
    this.kind, {
    super.key,
    required this.color,
    this.size = 26,
    this.active = false,
  });

  final NavIconKind kind;
  final Color color;
  final double size;

  /// Kept for callers; the mobile icons do not change when selected
  /// (only the colour does).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (kind) {
      NavIconKind.chats => FaIcon(
        FontAwesomeIcons.comment,
        color: color,
        size: size * 0.86,
      ),
      NavIconKind.calls => Icon(Icons.call_outlined, color: color, size: size),
      NavIconKind.wallets => FaIcon(
        FontAwesomeIcons.wallet,
        color: color,
        size: size * 0.8,
      ),
      NavIconKind.stories => FaIcon(
        FontAwesomeIcons.hornbill,
        color: color,
        size: size * 0.86,
      ),
      NavIconKind.profile => Icon(
        Icons.person_3_outlined,
        color: color,
        size: size,
      ),
    };
    return SizedBox.square(
      dimension: size,
      child: Center(child: icon),
    );
  }
}
