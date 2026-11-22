import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The "S" mark followed by the two-tone "SchatzApp" wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.markSize = 44,
    this.fontSize = 30,
    this.wordColor = AppColors.wordmark,
  });

  final double markSize;
  final double fontSize;
  final Color wordColor;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1,
      color: wordColor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SMark(size: markSize),
        SizedBox(width: markSize * 0.22),
        Text('SchatzApp', style: style),
      ],
    );
  }
}

class SMark extends StatelessWidget {
  const SMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/s_logo.png',
      height: size,
      filterQuality: FilterQuality.high,
    );
  }
}
