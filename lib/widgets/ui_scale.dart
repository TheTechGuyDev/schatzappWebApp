import 'package:material_ui/material_ui.dart';

import '../platform/device_check.dart';

/// Scales the whole UI down on smaller laptop screens so the layout fits the
/// way it does on a large monitor (the same effect as browser zoom, but
/// automatic). Designs are laid out for about 1440 x 860; below that the UI
/// shrinks, never below 72%. Phones are never scaled.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child});

  final Widget child;

  static const designWidth = 1440.0;
  static const designHeight = 860.0;
  static const minScale = 0.72;

  static double scaleFor(Size size) {
    if (isPhoneDevice) return 1;
    final double s;
    if (size.width >= 1000) {
      s = (size.width / designWidth) < (size.height / designHeight)
          ? size.width / designWidth
          : size.height / designHeight;
    } else {
      // Tablet widths already use the compact layout; only fit the height.
      s = size.height / designHeight;
    }
    return s.clamp(minScale, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = scaleFor(mq.size);
    if (scale >= 1) return child;
    final logical = mq.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: logical.width,
        height: logical.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: logical,
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
