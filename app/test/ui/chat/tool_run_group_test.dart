import 'package:app/domain/session_state.dart';
import 'package:app/ui/chat/chat_page.dart';
import 'package:app/ui/chat/widgets/tool_run_group.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one copy action belongs to the last assistant segment per turn', () {
    final messages = <ChatMessage>[
      const UserMsg(id: 'user-1', text: 'First request'),
      const AssistantMsg(id: 'assistant-1-a', text: 'Starting'),
      const ToolEvent(
        id: 'tool-1',
        toolCallId: 'tool-1',
        tool: 'command',
        args: {},
        status: ToolEventStatus.completed,
      ),
      const AssistantMsg(id: 'assistant-1-b', text: 'Finished'),
      const UserMsg(id: 'user-2', text: 'Second request'),
      const AssistantMsg(id: 'assistant-2', text: 'Done'),
    ];

    expect(assistantCopyIdsForTurns(messages), {
      'assistant-1-b',
      'assistant-2',
    });
  });

  testWidgets('multiple tools collapse into one row and open a grouped sheet', (
    tester,
  ) async {
    const tools = [
      ToolEvent(
        id: 'tool-1',
        toolCallId: 'cmd-1',
        tool: 'command',
        args: {'description': 'Post review findings on PR 371'},
        status: ToolEventStatus.completed,
      ),
      ToolEvent(
        id: 'tool-2',
        toolCallId: 'agent-1',
        tool: 'message_agent',
        args: {'prompt': 'PR 371 fix round 1'},
        status: ToolEventStatus.completed,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: ToolRunGroup(tools: tools)),
      ),
    );
    expect(find.text('Ran a command, used a tool'), findsOneWidget);
    await tester.tap(find.text('Ran a command, used a tool'));
    await tester.pumpAndSettle();
    expect(find.text('Ran'), findsOneWidget);
    expect(find.text('Messaged agent'), findsOneWidget);
    expect(find.text('Post review findings on PR 371'), findsOneWidget);
  });
}
