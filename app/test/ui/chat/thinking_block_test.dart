import 'package:app/ui/chat/widgets/thinking_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'thinking starts compact, expands supplied content and collapses',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const ThinkingBlock(
            text: 'Inspect the chosen folder.',
            complete: false,
          ),
        ),
      );
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Inspect the chosen folder.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('thinking-disclosure')));
      await tester.pump();
      expect(find.text('Inspect the chosen folder.'), findsOneWidget);
      await tester.pumpWidget(
        wrap(
          const ThinkingBlock(
            text: 'Inspect the chosen folder.',
            complete: true,
          ),
        ),
      );
      expect(find.text('Thought process'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byKey(const ValueKey('thinking-disclosure')));
      await tester.pump();
      expect(find.text('Inspect the chosen folder.'), findsNothing);
    },
  );

  testWidgets('absent thinking content has no expandable placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ThinkingBlock(text: '', complete: true)),
    );
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    expect(find.byType(SelectableText), findsNothing);
  });
}
