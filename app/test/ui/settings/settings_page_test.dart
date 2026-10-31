import 'dart:async';

import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/channel.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/settings/settings_page.dart';
import 'package:app/ui/settings/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Storage extends PairingStorage {
  @override
  Future<List<PeerRecord>> listPeers() async => const [];
}

class _SecureStorage implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements IChannel {
  @override
  Stream<ServerMessage> get serverMessages => const Stream.empty();

  @override
  Future<void> send(ClientMessage message) async {}

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('settings no longer duplicates pairing management', (
    tester,
  ) async {
    final storage = _Storage();
    final prefs = Preferences(_SecureStorage());
    final conn = ConnectionManager(
      storage: storage,
      factory: (_, _) async => _Channel(),
    );
    final vm = SettingsViewModel(storage, prefs, conn);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: vm),
          ChangeNotifierProvider<Preferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pairings'), findsNothing);
    expect(find.text('Add new pairing'), findsNothing);
    expect(find.text('RELAY'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
    conn.dispose();
    prefs.dispose();
  });
}
