import 'package:flutter/material.dart';
import 'package:app/ui/core/themes/themes.dart';

const kAppName = 'Pico';

/// The folded thread connects devices, workspaces and conversations.
/// Geometry matches branding/pico-mark.svg and Android vector icons.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 28, this.tile = false});
  final double size;
  final bool tile;
  @override
  Widget build(BuildContext context) => Semantics(
    label: kAppName,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: AppMarkPainter(
          foreground: tile ? AppBrandColors.foreground : context.colors.accent,
          terminal: AppBrandColors.terminal,
          background: tile ? AppBrandColors.background : null,
        ),
      ),
    ),
  );
}

class AppMarkPainter extends CustomPainter {
  const AppMarkPainter({
    required this.foreground,
    required this.terminal,
    this.background,
  });
  final Color foreground, terminal;
  final Color? background;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 108, 108),
          const Radius.circular(25),
        ),
        Paint()..color = background!,
      );
    }
    final path = Path()
      ..moveTo(74, 32)
      ..lineTo(46, 32)
      ..cubicTo(38, 32, 32, 37, 32, 43)
      ..cubicTo(32, 49, 38, 54, 46, 54)
      ..lineTo(62, 54)
      ..cubicTo(70, 54, 76, 59, 76, 65)
      ..cubicTo(76, 71, 70, 76, 62, 76)
      ..lineTo(34, 76);
    canvas.drawPath(
      path,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(74, 32), 5, Paint()..color = terminal);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppMarkPainter old) =>
      old.foreground != foreground ||
      old.terminal != terminal ||
      old.background != background;
}
