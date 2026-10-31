import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/protocol/protocol.dart';
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
    'home overview summarizes the workspace without repeating its session list',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = Preferences();
      await prefs.load();
      final peer = phoneTestPeer();
      final channel = PhoneTestChannel();
      final storage = PhoneTestStorage([peer]);
      final connection = ConnectionManager(
        storage: storage,
        factory: (_, _) async => channel,
        emitDebounce: Duration.zero,
      );
      connection.adopt(channel, peer);
      final vm = HomeViewModel(storage, prefs, connection);
      channel.control.add(
        RoomAnnounced(
          peer: peer.remoteEpk,
          roomId: 'alpha',
          name: 'Alpha task',
          cwd: '/code/project',
          startedAt: 1,
        ),
      );
      channel.control.add(
        RoomAnnounced(
          peer: peer.remoteEpk,
          roomId: 'beta',
          name: 'Beta task',
          cwd: '/code/project',
          startedAt: 2,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vm,
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const SessionWelcome(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workspace-overview')), findsOneWidget);
      expect(find.text('CURRENT WORKSPACE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-sessions')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-focus-session')),
          matching: find.text('Beta task'),
        ),
        findsOneWidget,
      );
      expect(find.text('Alpha task'), findsNothing);
      expect(find.byKey(const Key('overview-new-session')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      connection.dispose();
      prefs.dispose();
      await channel.disposeStreams();
    },
  );
}
