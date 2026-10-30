import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/workspaces/session_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../support/phone_controls.dart';

void main() {
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
      await tester.tap(find.byKey(const ValueKey('session-menu-beta')));
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
