import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds a user-adjustable panel width (dragged with the mouse) and
/// remembers it in this browser.
class PanelWidth {
  PanelWidth(this.key, this.initial);

  final String key;
  final double initial;
  double? _value;
  static SharedPreferences? _prefs;

  double get value => _value ?? _prefs?.getDouble(key) ?? initial;

  static Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  void set(double v) {
    _value = v;
    _prefs?.setDouble(key, v);
  }
}

/// The gap between two panels that can be dragged left/right to resize.
/// Shows a resize cursor and a purple line on hover.
class ResizeHandle extends StatefulWidget {
  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDoubleTap,
    this.width = 12,
  });

  final ValueChanged<double> onDrag;

  /// Resets to the default width.
  final VoidCallback? onDoubleTap;
  final double width;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          width: widget.width,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 0,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF9B3BE8).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
