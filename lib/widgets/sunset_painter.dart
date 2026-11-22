import 'package:material_ui/material_ui.dart';

/// Placeholder image for the demo photo message.
class SunsetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sky = Rect.fromLTWH(0, 0, w, h * 0.62);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B2A5C), Color(0xFFD9573A), Color(0xFFF6B13D)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(sky),
    );
    canvas.drawCircle(
      Offset(w * 0.58, h * 0.6),
      h * 0.09,
      Paint()..color = const Color(0xFFFFE08A),
    );
    final mountains = Path()
      ..moveTo(0, h * 0.62)
      ..lineTo(0, h * 0.48)
      ..lineTo(w * 0.15, h * 0.38)
      ..lineTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.45, h * 0.34)
      ..lineTo(w * 0.62, h * 0.5)
      ..lineTo(w * 0.78, h * 0.4)
      ..lineTo(w, h * 0.52)
      ..lineTo(w, h * 0.62)
      ..close();
    canvas.drawPath(mountains, Paint()..color = const Color(0xFF2B2234));
    final water = Rect.fromLTWH(0, h * 0.62, w, h * 0.38);
    canvas.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE88A3A), Color(0xFF7A3A2E), Color(0xFF2A1E2C)],
        ).createShader(water),
    );
    // Sun reflection: short shimmering strokes on the water.
    final glint = Paint()
      ..color = const Color(0xFFFFD27A).withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = h * (0.67 + i * 0.05);
      final half = w * (0.07 - i * 0.009);
      canvas.drawLine(
        Offset(w * 0.58 - half, y),
        Offset(w * 0.58 + half, y),
        glint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
