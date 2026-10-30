import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'high contrast keeps controls opaque and operable in both themes',
    (tester) async {
      for (final dark in [false, true]) {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? buildDarkTheme() : buildLightTheme(),
            home: MediaQuery(
              data: const MediaQueryData(highContrast: true),
              child: Scaffold(
                body: Center(
                  child: BayaGlassSurface(
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Choose workspace'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        final opaque = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(BayaGlassSurface),
                matching: find.byType(DecoratedBox),
              ),
            )
            .where((box) => (box.decoration as BoxDecoration).color != null);
        expect(opaque, isNotEmpty);
        expect((opaque.first.decoration as BoxDecoration).color!.a, 1);
        await tester.tap(find.text('Choose workspace'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
