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
          dimensional:
              tile && !(MediaQuery.maybeOf(context)?.highContrast ?? false),
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
    this.dimensional = false,
  });
  final Color foreground, highlight;
  final Color? background;
  final bool dimensional;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    const bounds = Rect.fromLTWH(0, 0, 108, 108);
    if (background != null) {
      final tile = RRect.fromRectAndRadius(bounds, const Radius.circular(24));
      canvas.drawRRect(
        tile,
        dimensional
            ? (Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppBrandColors.backgroundLight,
                    background!,
                    AppBrandColors.backgroundDeep,
                  ],
                  stops: const [0, 0.55, 1],
                ).createShader(bounds))
            : (Paint()..color = background!),
      );
      if (dimensional) {
        canvas.save();
        canvas.clipRRect(tile);
        canvas.drawRRect(
          tile.deflate(0.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppBrandColors.reflection.withValues(alpha: 0.48),
                AppBrandColors.reflection.withValues(alpha: 0.04),
                AppBrandColors.reflection.withValues(alpha: 0.16),
              ],
            ).createShader(bounds),
        );
        canvas.restore();
      }
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
    if (dimensional) {
      canvas.drawPath(
        body.shift(const Offset(0, 1.8)),
        Paint()..color = AppBrandColors.shadow.withValues(alpha: 0.38),
      );
    }
    canvas.drawPath(
      body,
      dimensional
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppBrandColors.foregroundLight,
                  AppBrandColors.foreground,
                  AppBrandColors.foregroundShade,
                ],
                stops: [0, 0.45, 1],
              ).createShader(const Rect.fromLTRB(34, 26, 79, 86)))
          : (Paint()..color = foreground),
    );
    if (dimensional) {
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65
          ..color = AppBrandColors.reflection.withValues(alpha: 0.35),
      );
    }
    final crown = Path()
      ..moveTo(49, 39)
      ..cubicTo(51, 29, 58, 25, 67, 26)
      ..cubicTo(73, 26, 78, 30, 80, 36)
      ..lineTo(64, 36)
      ..cubicTo(58, 36, 54, 39, 49, 43)
      ..close();
    final gold = dimensional
        ? (Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppBrandColors.highlightLight,
                AppBrandColors.highlight,
                AppBrandColors.highlightDeep,
              ],
              stops: [0, 0.6, 1],
            ).createShader(const Rect.fromLTRB(49, 25, 90, 52)))
        : (Paint()..color = highlight);
    if (dimensional) {
      canvas.drawPath(
        crown.shift(const Offset(0, 0.9)),
        Paint()..color = AppBrandColors.shadow.withValues(alpha: 0.2),
      );
    }
    canvas.drawPath(crown, gold);
    final beak = Path()
      ..moveTo(79, 42)
      ..lineTo(90, 48)
      ..lineTo(78, 51)
      ..close();
    canvas.drawPath(beak, gold);
    if (dimensional && size.shortestSide >= 48) {
      final glint = Path()
        ..moveTo(53, 34)
        ..cubicTo(58, 29, 64, 28, 70, 30);
      canvas.drawPath(
        glint,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..color = AppBrandColors.reflection.withValues(alpha: 0.55),
      );
    }
    final thread = Path()
      ..moveTo(88, 51)
      ..cubicTo(88, 76, 77, 88, 58, 88);
    canvas.drawPath(
      thread,
      (dimensional
            ? (Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppBrandColors.highlightLight,
                    AppBrandColors.highlight,
                    AppBrandColors.highlightDeep,
                  ],
                  stops: [0, 0.65, 1],
                ).createShader(const Rect.fromLTRB(58, 51, 88, 88)))
            : (Paint()..color = highlight))
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
      old.background != background ||
      old.dimensional != dimensional;
}
