import 'package:material_ui/material_ui.dart';

import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';

/// Placeholder for tabs whose UI designs have not been sent yet
/// (Wallets, Stories, Profile).
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final phone = screenSizeOf(context) == ScreenSize.phone;
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 46, color: AppColors.accent),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.meta),
            ),
          ],
        ),
      ),
    );
    if (phone) return Container(color: Colors.white, child: body);
    return ShellPanel(
      margin: const EdgeInsets.fromLTRB(4, 16, 16, 16),
      child: body,
    );
  }
}
