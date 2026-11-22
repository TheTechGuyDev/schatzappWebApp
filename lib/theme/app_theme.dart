import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Brand colors. The first five come from the mobile app theme.
class AppColors {
  static const primary = Color(0xFF935CCC);
  static const secondary = Color(0xFF39D2C0);
  static const tertiary = Color(0xFFEFEBF2);
  static const text = Color(0xFF111B21);
  static const textSecondary = Color(0xFF667781);

  // Web UI accents matched to the supplied designs.
  static const brandDeep = Color(0xFF5B1CD3);
  static const brandVivid = Color(0xFF7B2FE0);
  static const panelTop = Color(0xFF7A22DC);
  static const panelBottom = Color(0xFF5A16C2);
  static const heading = Color(0xFF15122B);
  static const body = Color(0xFF3C3A4E);
  static const lavender = Color(0xFFEDE3FD);
  static const lavenderSoft = Color(0xFFF6F1FE);
  static const divider = Color(0xFFE7E3F0);
  static const pageBg = Color(0xFFF7F4FD);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandDeep,
        primary: AppColors.brandDeep,
        secondary: AppColors.secondary,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.pageBg,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.heading,
      ),
    );
  }
}
