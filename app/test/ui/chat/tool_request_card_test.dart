import 'package:app/domain/session_state.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/chat/widgets/tool_request_card.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _bashTool = ToolEvent(
  id: 'tc1',
  toolCallId: 'tc1',
  tool: 'Bash',
  args: {'command': 'ls -la'},
);

const _editToolWithHunk = ToolEvent(
  id: 'tc2',
  toolCallId: 'tc4',
  tool: 'edit',
  args: {
    'path': 'app/test/ui/chat/tool_request_card_test.dart',
    'hunks': [
      {
        'lines': [
          {'kind': 'context', 'oldLine': 16, 'newLine': 16, 'text': 'args: {'},
          {'kind': 'remove', 'oldLine': 17, 'text': "  tool: 'Edit',"},
          {'kind': 'add', 'newLine': 17, 'text': "  tool: 'edit',"},
          {'kind': 'context', 'oldLine': 18, 'newLine': 18, 'text': '},'},
        ],
      },
    ],
  },
);

void main() {
  testWidgets('a failed thinking tool keeps its error visible in details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolRequestCard(
          tool: ToolEvent(
            id: 'failed-think',
            toolCallId: 'failed-think',
            tool: 'think',
            args: {'thought': 'Check the project.'},
            status: ToolEventStatus.failed,
            error: 'The tool could not continue.',
          ),
        ),
      ),
    );
    expect(find.text('Failed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tool-details-failed-think')));
    await tester.pump();
    expect(find.text('The tool could not continue.'), findsOneWidget);
  });

  testWidgets('single call collapses to one row and expands on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ToolRequestCard(
          tool: ToolEvent(
            id: 'output',
            toolCallId: 'output',
            tool: 'bash',
            args: {'command': 'git status'},
            result: 'Working tree clean',
            status: ToolEventStatus.completed,
          ),
        ),
      ),
    );
    // Collapsed default: the activity label and a dimmed command preview.
    expect(find.text('Ran command'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    // Output stays behind the tap.
    expect(find.text('Working tree clean'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tool-details-output')));
    await tester.pump();
    expect(find.text('Working tree clean'), findsOneWidget);
  });

  testWidgets('long output is collapsed behind Show full output', (
    tester,
  ) async {
    final longOutput = List.generate(40, (i) => 'line $i').join('\n');
    final tool = ToolEvent(
      id: 'long',
      toolCallId: 'long',
      tool: 'bash',
      args: {'command': 'git status'},
      status: ToolEventStatus.completed,
      result: longOutput,
    );
    await tester.pumpWidget(_wrap(ToolRequestCard(tool: tool)));
    expect(find.text('Ran command'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tool-details-long')));
    await tester.pump();
    expect(find.text('Show full output'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tool-output-toggle-long')));
    await tester.pump();
    expect(find.text('Show less'), findsOneWidget);
  });
  testWidgets('paused agent approval sends one explicit allow decision', (
    tester,
  ) async {
    ApproveDecision? decision;
    String? id;
    await tester.pumpWidget(
      _wrap(
        ToolRequestCard(
          tool: const ToolEvent(
            id: 'approval',
            toolCallId: 'approval',
            tool: 'commandExecution',
            args: {'command': 'git status', 'approval_required': true},
          ),
          onDecide: (value, choice) {
            id = value;
            decision = choice;
          },
        ),
      ),
    );
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    expect(find.textContaining('approval_required'), findsNothing);
    expect(find.text('Deny'), findsOneWidget);
    await tester.tap(find.text('Allow once'));
    expect(id, 'approval');
    expect(decision, ApproveDecision.allow);
  });
  group('ToolRequestCard (informational)', () {
    testWidgets('shows tool name and command', (tester) async {
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      expect(find.text('Running command'), findsOneWidget);
      // A lone call renders its command inline — no extra tap needed.
      expect(find.text('ls -la'), findsOneWidget);
    });

    testWidgets('edit renders rich hunks with context lines', (tester) async {
      await tester.pumpWidget(
        _wrap(const ToolRequestCard(tool: _editToolWithHunk)),
      );
      await tester.tap(find.byKey(const ValueKey('tool-details-tc4')));
      await tester.pump();

      expect(
        find.textContaining('   16 args: {', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining("-  17   tool: 'Edit',", findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining("+  17   tool: 'edit',", findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('   18 },', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('pending state shows RUNNING and no Allow/Deny buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      expect(find.text('Running command'), findsOneWidget);
      expect(find.text('Allow'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      expect(find.textContaining('60s'), findsNothing);
    });

    testWidgets('completed state shows DONE', (tester) async {
      const done = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.completed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: done)));
      expect(find.text('Ran command'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool-details-tc1')));
      await tester.pump();
      expect(find.textContaining('Done'), findsAny);
    });

    testWidgets('denied state shows DENIED label', (tester) async {
      const denied = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.denied,
        error: 'user denied',
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: denied)));
      expect(find.text('Denied'), findsOneWidget);
    });

    testWidgets('allowed state shows RUNNING (still in flight)', (
      tester,
    ) async {
      const allowed = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.allowed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: allowed)));
      expect(find.text('Running command'), findsOneWidget);
      expect(find.text('Allow'), findsNothing);
    });

    // Ordinary activity stays subtle; failures remain emphasized.
    // Assert the expanded outcome color (the same semantic token
    // is used by the activity header).
    Color? outcomeColor(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    testWidgets('completed stays subtle "Done"', (tester) async {
      const done = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.completed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: done)));
      await tester.tap(find.byKey(const ValueKey('tool-details-tc1')));
      await tester.pump();
      expect(outcomeColor(tester, 'Done'), AppColors.dark.muted2);
    });

    testWidgets('failed → red "✗ {error}" + FAILED label', (tester) async {
      const failed = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'exit 1'},
        status: ToolEventStatus.failed,
        error: 'command failed: exit 1',
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: failed)));
      expect(find.text('Failed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool-details-tc1')));
      await tester.pump();
      expect(
        outcomeColor(tester, 'command failed: exit 1'),
        AppColors.dark.error,
      );
    });

    testWidgets('running stays subtle "Running…"', (tester) async {
      // pending defaults
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      await tester.tap(find.byKey(const ValueKey('tool-details-tc1')));
      await tester.pump();
      expect(outcomeColor(tester, 'Running…'), AppColors.dark.muted2);
    });
  });
}
