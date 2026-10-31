import 'dart:convert';
import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/pairing/storage.dart';
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
    'sidebar scrolls its header instead of overflowing in short windows',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final pc = phoneTestPeer();
      final prefs = Preferences();
      await prefs.load();
      await prefs.setSelectedWorkspace(
        HomeViewModel.workspaceKey(pc.remoteEpk, '/code/shared'),
      );
      final channel = PhoneTestChannel();
      final storage = PhoneTestStorage([pc]);
      final conn = ConnectionManager(
        storage: storage,
        factory: (_, _) async => channel,
        emitDebounce: Duration.zero,
      );
      conn.adopt(channel, pc);
      final vm = HomeViewModel(storage, prefs, conn);
      final selection = SessionSelection();
      channel.control.add(
        RoomAnnounced(
          peer: pc.remoteEpk,
          roomId: 'pc-one',
          name: 'Desktop one',
          cwd: '/code/shared',
          startedAt: 1,
        ),
      );
      channel.control.add(
        RoomAnnounced(
          peer: pc.remoteEpk,
          roomId: 'pc-two',
          name: 'Desktop two',
          cwd: '/code/shared',
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
              body: Center(
                child: SizedBox(
                  width: 330,
                  height: 480,
                  child: SessionSidebar(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The fixed header stack is taller than 480dp; it must scroll with the
      // session list instead of throwing a RenderFlex overflow.
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('Desktop one'),
        find.byType(ListView).first,
        const Offset(0, -80),
      );
      expect(find.text('Desktop one'), findsOneWidget);
      // Bottom actions stay pinned and tappable below the scroll area.
      expect(find.text('Pair computer'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
      conn.dispose();
      prefs.dispose();
      selection.dispose();
      await channel.disposeStreams();
    },
  );

  testWidgets(
    'device then workspace scopes sessions and remembers each device across relaunch',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final pc = phoneTestPeer();
      PeerRecord peer(int seed, String label) => PeerRecord(
        remoteEpk: base64Encode(List.filled(32, seed)),
        sessionName: label,
        relayUrl: 'https://example.invalid',
        pairedAt: '2026-10-30',
      );
      final laptop = peer(7, 'Laptop'), empty = peer(8, 'Empty device');
      final prefs = Preferences();
      await prefs.load();
      await prefs.setSelectedWorkspace(
        HomeViewModel.workspaceKey(pc.remoteEpk, '/code/shared'),
      );
      await prefs.setSelectedRoom(epk: pc.remoteEpk, roomId: 'pc-one');
      final channel = PhoneTestChannel();
      final storage = PhoneTestStorage([pc, laptop, empty]);
      final conn = ConnectionManager(
        storage: storage,
        factory: (_, _) async => channel,
        emitDebounce: Duration.zero,
      );
      conn.adopt(channel, pc);
      final vm = HomeViewModel(storage, prefs, conn);
      final selection = SessionSelection();
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
      void room(PeerRecord host, String id, String name, String cwd) =>
          channel.control.add(
            RoomAnnounced(
              peer: host.remoteEpk,
              roomId: id,
              name: name,
              cwd: cwd,
              startedAt: 1,
            ),
          );
      room(pc, 'pc-one', 'Desktop one', '/code/shared');
      room(pc, 'pc-two', 'Desktop two', '/code/shared');
      room(pc, 'pc-notes', 'Desktop notes', '/code/notes');
      room(laptop, 'laptop-one', 'Laptop task', '/code/shared');
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
      expect(find.text('Desktop one'), findsOneWidget);
      expect(find.text('Desktop two'), findsOneWidget);
      expect(find.text('Laptop task'), findsNothing);
      Future<void> choose(String key, String value) async {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      await choose('workspace-selector', 'notes');
      expect(find.text('Desktop notes'), findsOneWidget);
      await choose('device-selector', 'Laptop');
      expect(find.text('Laptop task'), findsOneWidget);
      expect(find.text('Desktop notes'), findsNothing);
      expect(vm.workspaces.length, 1);
      expect(vm.workspaces.values.single.peer.remoteEpk, laptop.remoteEpk);
      await choose('device-selector', 'Empty device');
      expect(vm.workspaceItems, isEmpty);
      expect(vm.workspaces, isEmpty);
      expect(find.text('No workspaces yet'), findsOneWidget);
      await choose('device-selector', 'PC');
      expect(find.text('Desktop notes'), findsOneWidget);
      expect(find.text('Desktop one'), findsNothing);
      // Browsing never redirects the transport or changes the active chat.
      expect(prefs.selectedPeerEpk, pc.remoteEpk);
      expect(prefs.selectedRoomId, 'pc-one');
      final restored = Preferences();
      await restored.load();
      expect(restored.selectedDeviceEpk, pc.remoteEpk);
      expect(
        restored.workspaceForDevice(pc.remoteEpk),
        HomeViewModel.workspaceKey(pc.remoteEpk, '/code/notes'),
      );
      restored.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await cleanup();
      await tester.pump();
    },
  );

  test(
    'migrates combined workspace and serializes per-device selections',
    () async {
      final pc = phoneTestPeer().remoteEpk;
      final laptop = base64Encode(List.filled(32, 7));
      final old = HomeViewModel.workspaceKey(pc, '/code/old');
      FlutterSecureStorage.setMockInitialValues({
        'prefs.selected_workspace': old,
      });
      final prefs = Preferences();
      await prefs.load();
      expect(prefs.selectedDeviceEpk, pc);
      expect(prefs.workspaceForDevice(pc), old);
      await Future.wait([
        prefs.setSelectedWorkspace(
          HomeViewModel.workspaceKey(laptop, '/code/new'),
        ),
        prefs.setSelectedDevice(pc),
      ]);
      final restored = Preferences();
      await restored.load();
      expect(restored.selectedDeviceEpk, pc);
      expect(
        restored.workspaceForDevice(laptop),
        HomeViewModel.workspaceKey(laptop, '/code/new'),
      );
      expect(restored.selectedWorkspace, old);
      prefs.dispose();
      restored.dispose();
    },
  );
}
