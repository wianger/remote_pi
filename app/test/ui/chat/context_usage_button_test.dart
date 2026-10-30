import 'package:app/domain/contracts/context_usage_repository.dart';
import 'package:app/domain/entities/context_usage.dart';
import 'package:app/ui/chat/context/viewmodels/context_usage_viewmodel.dart';
import 'package:app/ui/chat/context/widgets/context_usage_button.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repository implements IContextUsageRepository {
  ContextUsageSnapshot value = const ContextUsageSnapshot(
    tokens: 40_000,
    window: 200_000,
    source: 'pi',
  );
  int requests = 0;

  @override
  Future<ContextUsageSnapshot> fetch() async {
    requests++;
    return value;
  }
}

Widget _app(
  ContextUsageViewModel vm, {
  bool enabled = true,
  bool working = false,
  int messages = 1,
}) => ChangeNotifierProvider.value(
  value: vm,
  child: MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(
      body: ContextUsageButton(
        enabled: enabled,
        working: working,
        messageCount: messages,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'loads usage automatically and opens the existing token details',
    (tester) async {
      final repository = _Repository();
      final vm = ContextUsageViewModel(repository);
      addTearDown(vm.dispose);
      await tester.pumpWidget(_app(vm));
      await tester.pumpAndSettle();
      expect(repository.requests, 1);
      expect(find.text('20%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        .2,
      );
      await tester.tap(find.byTooltip('Context usage'));
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      expect(find.text('40,000'), findsOneWidget);
      expect(find.text('200,000'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'refreshes after a turn and reconnect without polling streaming',
    (tester) async {
      final repository = _Repository();
      final vm = ContextUsageViewModel(repository);
      addTearDown(vm.dispose);
      await tester.pumpWidget(_app(vm));
      await tester.pumpAndSettle();
      repository.value = const ContextUsageSnapshot(
        tokens: 120_000,
        window: 200_000,
      );
      await tester.pumpWidget(_app(vm, working: true, messages: 2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(vm, working: true, messages: 3));
      await tester.pumpAndSettle();
      expect(repository.requests, 1);
      await tester.pumpWidget(_app(vm, messages: 4));
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      expect(find.text('60%'), findsOneWidget);
      await tester.pumpWidget(_app(vm, enabled: false, messages: 4));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byTooltip('Context usage'));
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      await tester.pumpWidget(_app(vm, messages: 4));
      await tester.pumpAndSettle();
      expect(repository.requests, 3);
    },
  );

  testWidgets(
    'unknown usage is distinct from zero and overfull usage is bounded',
    (tester) async {
      final repository = _Repository()
        ..value = const ContextUsageSnapshot(window: 200_000);
      final vm = ContextUsageViewModel(repository);
      addTearDown(vm.dispose);
      await tester.pumpWidget(_app(vm));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.value = const ContextUsageSnapshot(tokens: 0, window: 200_000);
      await vm.refresh();
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0,
      );
      repository.value = const ContextUsageSnapshot(
        tokens: 250_000,
        window: 200_000,
      );
      await vm.refresh();
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
