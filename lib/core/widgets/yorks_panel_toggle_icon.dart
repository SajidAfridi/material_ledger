import 'package:flutter/material.dart';

/// A directional panel glyph: shaded when open, with a chevron showing the
/// next action. Vector geometry stays legible in optimized release builds.
class YorksPanelToggleIcon extends StatelessWidget {
  const YorksPanelToggleIcon({
    super.key,
    required this.expanded,
    this.atEnd = false,
    this.size = 22,
  });

  final bool expanded;
  final bool atEnd;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PanelTogglePainter(
      expanded: expanded,
      onRight: atEnd == (Directionality.of(context) == TextDirection.ltr),
      color:
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _PanelTogglePainter extends CustomPainter {
  const _PanelTogglePainter({
    required this.expanded,
    required this.onRight,
    required this.color,
  });

  final bool expanded;
  final bool onRight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 3, 20, 18),
      const Radius.circular(2),
    );
    canvas.drawRRect(frame, stroke);
    final divider = onRight ? 16.0 : 8.0;
    if (expanded) {
      canvas.save();
      canvas.clipRRect(frame);
      canvas.drawRect(
        Rect.fromLTRB(onRight ? divider : 2, 3, onRight ? 22 : divider, 21),
        Paint()..color = color.withValues(alpha: 0.28),
      );
      canvas.restore();
    }
    canvas.drawLine(Offset(divider, 3), Offset(divider, 21), stroke);
    final center = onRight ? 9.0 : 15.0;
    final direction = expanded == onRight ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(center - direction * 1.5, 9)
        ..lineTo(center + direction * 1.5, 12)
        ..lineTo(center - direction * 1.5, 15),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_PanelTogglePainter oldDelegate) =>
      expanded != oldDelegate.expanded ||
      onRight != oldDelegate.onRight ||
      color != oldDelegate.color;
}
