import 'package:flutter/material.dart';
import 'package:app/ui/core/themes/themes.dart';

const kAppName = 'Baya';

/// A weaverbird gathers devices, workspaces and conversations into one place.
/// Geometry matches branding/baya-mark.svg and Android vector icons.
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
          highlight: AppBrandColors.highlight,
          background: tile ? AppBrandColors.background : null,
        ),
      ),
    ),
  );
}

class AppMarkPainter extends CustomPainter {
  const AppMarkPainter({
    required this.foreground,
    required this.highlight,
    this.background,
  });
  final Color foreground, highlight;
  final Color? background;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 108, 108),
          const Radius.circular(24),
        ),
        Paint()..color = background!,
      );
    }
    final body = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(28, 65)
      ..cubicTo(28, 54, 37, 46, 48, 46)
      ..cubicTo(48, 32, 57, 24, 68, 26)
      ..cubicTo(79, 27, 83, 38, 79, 48)
      ..cubicTo(79, 65, 65, 79, 48, 79)
      ..lineTo(28, 86)
      ..lineTo(32, 74)
      ..cubicTo(29, 71, 28, 68, 28, 65)
      ..close()
      // Negative space keeps the face and wing clear on any parent surface.
      ..moveTo(37, 59)
      ..cubicTo(45, 67, 55, 69, 66, 60)
      ..cubicTo(61, 73, 46, 77, 37, 65)
      ..close()
      ..addOval(Rect.fromCircle(center: const Offset(71, 40), radius: 2.6));
    canvas.drawPath(body, Paint()..color = foreground);
    final crown = Path()
      ..moveTo(49, 39)
      ..cubicTo(51, 29, 58, 25, 67, 26)
      ..cubicTo(73, 26, 78, 30, 80, 36)
      ..lineTo(64, 36)
      ..cubicTo(58, 36, 54, 39, 49, 43)
      ..close();
    canvas.drawPath(crown, Paint()..color = highlight);
    final beak = Path()
      ..moveTo(79, 42)
      ..lineTo(90, 48)
      ..lineTo(78, 51)
      ..close();
    canvas.drawPath(beak, Paint()..color = highlight);
    final thread = Path()
      ..moveTo(88, 51)
      ..cubicTo(88, 76, 77, 88, 58, 88);
    canvas.drawPath(
      thread,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppMarkPainter old) =>
      old.foreground != foreground ||
      old.highlight != highlight ||
      old.background != background;
}
