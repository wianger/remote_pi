import 'package:flutter/material.dart';
import 'package:app/ui/core/themes/themes.dart';

const kAppName = 'Baya';

/// A weaverbird gathers devices, workspaces and conversations into one place.
/// Geometry matches branding/baya-mark.svg and the Android vector icons: a
/// white tile carrying graphite line work with a small gold accent.
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
          foreground: tile
              ? AppBrandColors.foreground
              : context.colors.text.withValues(alpha: .88),
          highlight: tile ? AppBrandColors.highlight : context.colors.accent,
          background: tile ? AppBrandColors.background : null,
          edge: tile ? AppBrandColors.edge : null,
          // Thin line art loses definition when it is scaled down, so small
          // renders get proportionally heavier strokes.
          weight: size < 56 ? 1.22 : 1,
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
    this.edge,
    this.weight = 1,
  });

  final Color foreground, highlight;
  final Color? background;
  final Color? edge;
  final double weight;

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * weight
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    const bounds = Rect.fromLTWH(0, 0, 108, 108);
    final background = this.background;
    if (background != null) {
      final tile = RRect.fromRectAndRadius(bounds, const Radius.circular(24));
      canvas.drawRRect(tile, Paint()..color = background);
      if (edge case final line?) {
        canvas.drawRRect(
          tile.deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = line,
        );
      }
    }

    // Speech-bubble body that doubles as the bird's breast.
    final body = Path()
      ..moveTo(28, 65)
      ..cubicTo(28, 54, 37, 46, 48, 46)
      ..cubicTo(48, 32, 57, 24, 68, 26)
      ..cubicTo(79, 27, 83, 38, 79, 48)
      ..cubicTo(79, 65, 65, 79, 48, 79)
      ..lineTo(28, 86)
      ..lineTo(32, 74)
      ..cubicTo(29, 71, 28, 68, 28, 65)
      ..close();
    canvas.drawPath(body, _stroke(foreground, 3.2));

    // Interior feather / smile lines.
    canvas.drawPath(
      Path()
        ..moveTo(37.5, 59.5)
        ..cubicTo(45, 67, 55, 69, 65.5, 60.5)
        ..cubicTo(61, 72.5, 46.5, 76, 37.8, 65),
      _stroke(foreground, 2.4),
    );

    // Crown line over the head.
    canvas.drawPath(
      Path()
        ..moveTo(48.6, 39.6)
        ..cubicTo(51, 29.4, 58, 25.2, 67, 26.2)
        ..cubicTo(73, 27, 78, 30.6, 80, 36.4),
      _stroke(foreground, 2.8),
    );
    // A lighter second pass keeps it reading as a sketch rather than a wedge.
    canvas.drawPath(
      Path()
        ..moveTo(53.5, 33.5)
        ..cubicTo(58.5, 29.2, 64, 28.4, 69.6, 30.2),
      _stroke(foreground.withValues(alpha: .5), 1.6),
    );

    // Gold beak and the weaver's thread.
    canvas.drawPath(
      Path()
        ..moveTo(78.8, 43.2)
        ..lineTo(89.6, 48)
        ..lineTo(77.6, 52.2)
        ..close(),
      _stroke(highlight, 2.6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(88, 51.5)
        ..cubicTo(88, 76, 77, 88, 58, 88),
      _stroke(highlight, 2.6),
    );

    canvas.drawCircle(
      const Offset(71, 40.4),
      2.4 + (weight - 1) * 1.6,
      Paint()..color = foreground,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppMarkPainter old) =>
      old.foreground != foreground ||
      old.highlight != highlight ||
      old.background != background ||
      old.edge != edge ||
      old.weight != weight;
}
