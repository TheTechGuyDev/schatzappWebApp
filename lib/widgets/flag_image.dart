import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Country flag from flagcdn.com (same source as the mobile app), with a
/// text fallback if the image cannot load.
class FlagImage extends StatelessWidget {
  const FlagImage({
    super.key,
    required this.code,
    this.width = 26,
    this.height = 18,
  });

  /// ISO 3166 alpha-2, lower case.
  final String code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        'https://flagcdn.com/w80/$code.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          color: AppColors.accentSoft,
          child: Text(
            code.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
