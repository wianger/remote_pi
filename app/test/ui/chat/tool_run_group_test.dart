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

  test('thinking and tool boundaries keep only the newest segment', () {
    final messages = <ChatMessage>[
      const UserMsg(id: 'user-1', text: 'Do the thing'),
      const AssistantMsg(id: 'a-1', text: 'Looking'),
      const ThinkingMsg(id: 't-1', text: 'reasoning', complete: true),
      const AssistantMsg(id: 'a-2', text: 'Running the command'),
      const ToolEvent(
        id: 'tool-1',
        toolCallId: 'tool-1',
        tool: 'command',
        args: {},
        status: ToolEventStatus.completed,
      ),
      const AssistantMsg(id: 'a-3', text: 'Done'),
    ];

    expect(assistantCopyIdsForTurns(messages), {'a-3'});
  });

  test('consecutive calls group; calls split by text stay separate', () {
    const a = ToolEvent(
      id: 'tool-1',
      toolCallId: 'cmd-1',
      tool: 'command',
      args: {'command': 'git status'},
      status: ToolEventStatus.completed,
    );
    const b = ToolEvent(
      id: 'tool-2',
      toolCallId: 'cmd-2',
      tool: 'command',
      args: {'command': 'git diff'},
      status: ToolEventStatus.completed,
    );
    const c = ToolEvent(
      id: 'tool-3',
      toolCallId: 'cmd-3',
      tool: 'command',
      args: {'command': 'ls'},
      status: ToolEventStatus.completed,
    );

    final items = toolRunItemsForMessages([
      const UserMsg(id: 'u1', text: 'Go'),
      a,
      b,
      const AssistantMsg(id: 'a1', text: 'Now the next one'),
      c,
    ]);

    expect(items.length, 4);
    expect(items[0], isA<UserMsg>());
    expect(items[1], isA<ToolRunItem>());
    expect((items[1] as ToolRunItem).tools, [a, b]);
    expect(items[2], isA<AssistantMsg>());
    // A lone call renders as the plain card, not as a group.
    expect(items[3], same(c));
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
    // The collapsed row now names what ran instead of only counting calls.
    expect(
      find.text('Post review findings on PR 371  ·  +1 more'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ran a command, used a tool'));
    await tester.pumpAndSettle();
    expect(find.text('Ran'), findsOneWidget);
    expect(find.text('Messaged agent'), findsOneWidget);
    expect(find.text('Post review findings on PR 371'), findsOneWidget);
  });

  testWidgets('a single tool opens its final detail without an extra chooser', (
    tester,
  ) async {
    const tool = ToolEvent(
      id: 'tool-1',
      toolCallId: 'cmd-1',
      tool: 'command',
      args: {'command': 'git status'},
      result: 'working tree clean',
      status: ToolEventStatus.completed,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: ToolRunGroup(tools: [tool])),
      ),
    );

    await tester.tap(find.byKey(const Key('tool-run-group')));
    await tester.pumpAndSettle();

    expect(find.text('COMMAND'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('working tree clean'), findsOneWidget);
  });
}
