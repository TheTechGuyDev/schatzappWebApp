import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Left-menu icons drawn to match the supplied icon set:
/// round chat bubble, phone handset, wallet with clasp, stories ring and
/// profile circle.
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
  final bool active;

  @override
  Widget build(BuildContext context) {
    // The phone is a solid handset when active, outlined otherwise.
    if (kind == NavIconKind.calls) {
      return Icon(
        active ? Icons.call : Icons.call_outlined,
        color: color,
        size: size,
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _NavIconPainter(kind, color),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter(this.kind, this.color);

  final NavIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on a 24 x 24 grid.
    final s = size.width / 24;
    canvas.scale(s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (kind) {
      case NavIconKind.chats:
        // Round speech bubble with a tail at the bottom left.
        const c = Offset(12.6, 11);
        const r = 8.2;
        const start = 150 * math.pi / 180;
        const sweep = 300 * math.pi / 180;
        final p = Path()
          ..addArc(Rect.fromCircle(center: c, radius: r), start, sweep)
          ..lineTo(3.4, 20.6)
          ..lineTo(c.dx + r * math.cos(start), c.dy + r * math.sin(start));
        canvas.drawPath(p, stroke);
      case NavIconKind.wallets:
        // Wallet body, lid line and a small clasp.
        canvas.drawRRect(
          RRect.fromLTRBR(3, 5, 21, 19, const Radius.circular(3.2)),
          stroke,
        );
        canvas.drawLine(
          const Offset(3.6, 8.6),
          const Offset(20.4, 8.6),
          stroke,
        );
        final clasp = Path()
          ..addArc(
            Rect.fromCircle(center: const Offset(17.3, 13.8), radius: 1.6),
            -0.3 * math.pi,
            1.6 * math.pi,
          );
        canvas.drawPath(clasp, stroke);
      case NavIconKind.stories:
        // Four arcs with dots in the gaps (diagonals).
        const c = Offset(12, 12);
        const r = 8.4;
        final rect = Rect.fromCircle(center: c, radius: r);
        for (var i = 0; i < 4; i++) {
          final gap = (45 + 90 * i) * math.pi / 180;
          canvas.drawArc(rect, gap + 0.30, math.pi / 2 - 0.60, false, stroke);
          canvas.drawCircle(
            Offset(c.dx + r * math.cos(gap), c.dy + r * math.sin(gap)),
            1.45,
            fill,
          );
        }
      case NavIconKind.profile:
        // Circle with head and shoulders.
        canvas.drawCircle(const Offset(12, 12), 9.2, stroke);
        canvas.drawCircle(const Offset(12, 9.6), 3.1, stroke);
        final shoulders = Path()
          ..moveTo(6.1, 18.6)
          ..cubicTo(7.4, 15.1, 16.6, 15.1, 17.9, 18.6);
        canvas.drawPath(shoulders, stroke);
      case NavIconKind.calls:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter old) =>
      old.kind != kind || old.color != color;
}
