import 'dart:ui' as ui;

import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';

/// A bounded, diffused control layer. Conversation content stays opaque.
class BayaGlassSurface extends StatelessWidget {
  const BayaGlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.elevated = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final corners = BorderRadius.circular(radius);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: highContrast ? colors.inputFill : null,
        gradient: highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.48, 1],
                colors: [
                  colors.glassFill,
                  colors.glassTint,
                  colors.glassFill.withValues(alpha: colors.glassFill.a * .92),
                ],
              ),
        borderRadius: corners,
        border: Border.all(
          color: highContrast ? colors.muted2 : colors.glassEdge,
          width: highContrast ? 1.2 : 0.9,
        ),
      ),
      child: Stack(
        children: [
          if (!highContrast)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: corners,
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -1),
                      radius: 1.2,
                      colors: [
                        colors.glassHighlight,
                        colors.glassHighlight.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: elevated && !highContrast
            ? [
                BoxShadow(
                  color: colors.glassShadow,
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: corners,
        child: highContrast
            ? surface
            : BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: surface,
              ),
      ),
    );
  }
}
