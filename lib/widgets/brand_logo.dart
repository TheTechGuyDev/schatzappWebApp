import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The "S" mark followed by the two-tone "SchatzApp" wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.markSize = 44, this.fontSize = 30});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SMark(size: markSize),
        SizedBox(width: markSize * 0.22),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Schatz',
                style: style.copyWith(color: AppColors.heading),
              ),
              TextSpan(
                text: 'App',
                style: style.copyWith(color: AppColors.brandVivid),
              ),
            ],
          ),
        ),
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
