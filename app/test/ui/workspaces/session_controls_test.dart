import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/workspaces/session_shell.dart';
import 'package:app/ui/workspaces/widgets/scope_switchers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../support/phone_controls.dart';

void main() {
  testWidgets('device switcher moves add, rename and delete into the sheet', (
    tester,
  ) async {
    String? switched;
    var renameCalls = 0;
    var deleteCalls = 0;
    var addCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: DeviceSwitcher(
            devices: const {
              'computer-a': 'Computer A',
              'computer-b': 'Computer B',
            },
            selected: 'computer-a',
            onSelected: (value) => switched = value,
            onAdd: () => addCalls++,
            onRename: (epk) async {
              renameCalls++;
              return true;
            },
            onDelete: (epk) async {
              deleteCalls++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Computer A'));
    expect(switched, isNull);
    expect(renameCalls, 0);
    expect(deleteCalls, 0);

    await tester.tap(find.byKey(const Key('device-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Switch device'), findsOneWidget);

    await tester.tap(find.byKey(const Key('device-rename-computer-a')));
    await tester.pumpAndSettle();
    expect(renameCalls, 1);
    expect(deleteCalls, 0);

    await tester.tap(find.byKey(const Key('device-switch')));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Computer B'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);

    await tester.tap(find.byKey(const Key('device-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('device-add')));
    await tester.pumpAndSettle();
    expect(addCalls, 1);

    await tester.tap(find.byKey(const Key('device-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer B'));
    await tester.pumpAndSettle();
    expect(switched, 'computer-b');
  });

  testWidgets('workspace switcher adds from a circle and deletes on swipe', (
    tester,
  ) async {
    var created = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: WorkspaceSwitcher(
            workspaces: const {
              'pc:workspace:alpha': 'one session',
              'pc:workspace:beta': 'two sessions',
            },
            labels: const {
              'pc:workspace:alpha': 'Alpha',
              'pc:workspace:beta': 'Beta',
            },
            selected: 'pc:workspace:alpha',
            hasDevice: true,
            onSelected: (_) {},
            onCreate: () => created++,
            canDelete: (_) => true,
            onDelete: (_) async {
              deleted++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('workspace-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Switch workspace'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-add')));
    await tester.pumpAndSettle();
    expect(created, 1);

    await tester.tap(find.byKey(const Key('workspace-switch')));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Beta'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets(
    'workspace control replaces status chips and delete persists across room refresh',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = Preferences();
      await prefs.load();
      final peer = phoneTestPeer(), channel = PhoneTestChannel();
      final storage = PhoneTestStorage([peer]);
      final conn = ConnectionManager(
        storage: storage,
        factory: (_, _) async => channel,
        emitDebounce: Duration.zero,
      );
      final selection = SessionSelection();
      conn.adopt(channel, peer);
      final vm = HomeViewModel(storage, prefs, conn);
      var cleaned = false;
      Future<void> cleanup() async {
        if (cleaned) return;
        cleaned = true;
        vm.dispose();
        conn.dispose();
        prefs.dispose();
        selection.dispose();
        await channel.disposeStreams();
      }

      addTearDown(cleanup);
      channel.control.add(
        RoomAnnounced(
          peer: peer.remoteEpk,
          roomId: 'alpha',
          name: 'Alpha task',
          cwd: '/code/alpha',
          startedAt: 1,
        ),
      );
      channel.control.add(
        RoomAnnounced(
          peer: peer.remoteEpk,
          roomId: 'beta',
          name: 'Beta task',
          cwd: '/code/beta',
          startedAt: 1,
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            ChangeNotifierProvider.value(value: selection),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: SizedBox(width: 330, child: SessionSidebar()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All'), findsNothing);
      expect(find.text('New session'), findsNothing);
      expect(find.textContaining('Working'), findsNothing);
      expect(find.text('Alpha task'), findsOneWidget);
      expect(find.text('Beta task'), findsNothing);
      await tester.tap(find.byKey(const Key('workspace-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('beta').last);
      await tester.pumpAndSettle();
      expect(find.text('Beta task'), findsOneWidget);
      expect(find.text('Alpha task'), findsNothing);
      expect(
        prefs.selectedWorkspace,
        HomeViewModel.workspaceKey(peer.remoteEpk, '/code/beta'),
      );
      expect(find.byTooltip('Rename session'), findsOneWidget);
      await tester.tap(find.byTooltip('Rename session'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Renamed Beta',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed Beta'), findsOneWidget);

      await tester.longPress(find.text('Renamed Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete from phone'));
      await tester.pumpAndSettle();
      expect(find.text('Delete from phone?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      channel.control.add(
        RoomAnnounced(
          peer: peer.remoteEpk,
          roomId: 'beta',
          name: 'Beta task',
          cwd: '/code/beta',
          startedAt: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(vm.allItems.map((item) => item.room.roomId), ['alpha']);
      final restored = Preferences();
      await restored.load();
      expect(restored.isSessionHidden(peer.remoteEpk, 'beta'), isTrue);
      restored.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await cleanup();
      await tester.pump();
    },
  );
}
