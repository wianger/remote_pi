import 'dart:async';
import 'dart:convert';
import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/channel.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/data/workspaces/workspace_repository.dart';
import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

class _Channel implements IChannel, IControlLink {
  final messages = StreamController<ServerMessage>.broadcast();
  final control = StreamController<ControlInbound>.broadcast();
  final sent = <ClientMessage>[];
  String room = '';
  @override
  Stream<ServerMessage> get serverMessages => messages.stream;
  @override
  Stream<ControlInbound> get controlFrames => control.stream;
  void setActiveRoom(String value) => room = value;
  @override
  void sendControl(Map<String, dynamic> json) {}
  @override
  Future<void> send(ClientMessage message) async => sent.add(message);
  @override
  Future<void> close() async {}
}

class _Storage extends PairingStorage {
  _Storage(this.peers);
  final List<PeerRecord> peers;
  @override
  Future<List<PeerRecord>> listPeers() async => peers;
  @override
  Future<List<PersistedRoom>> loadRooms(String remoteEpk) async => [];
  @override
  Future<void> saveRooms(String remoteEpk, List<PersistedRoom> rooms) async {}
}

void main() {
  test(
    'cancel restores A after a late B connection and sends no browse on A',
    () async {
      PeerRecord peer(int byte, String room) => PeerRecord(
        remoteEpk: base64Encode(List.filled(32, byte)),
        sessionName: room,
        roomId: room,
        relayUrl: 'https://example.invalid',
        pairedAt: '2026-10-30',
      );
      final a = peer(1, 'room-A'), b = peer(2, 'room-B');
      final channelA = _Channel(), channelB = _Channel();
      final bStarted = Completer<void>(), bConnected = Completer<IChannel>();
      final storage = _Storage([a, b]);
      final conn = ConnectionManager(
        storage: storage,
        emitDebounce: Duration.zero,
        factory: (peer, cancel) async {
          if (peer.remoteEpk == b.remoteEpk) {
            bStarted.complete();
            return bConnected.future;
          }
          return channelA;
        },
      );
      final prefs = Preferences();
      final repo = WorkspaceRepository(conn, storage, prefs);
      conn.adopt(channelA, a);
      conn.switchRoom(a.roomId!);
      channelA.control.add(
        RoomAnnounced(peer: b.remoteEpk, roomId: b.roomId!, startedAt: 1),
      );
      await Future<void>.delayed(Duration.zero);
      final browse = repo.browse(b.remoteEpk);
      final rejected = expectLater(browse, throwsA(isA<WorkspaceFailure>()));
      await bStarted.future;
      final restore = repo.restore(WorkspaceSelection(a.remoteEpk, a.roomId!));
      bConnected.complete(channelB);
      await Future.wait([restore, rejected]);
      expect(conn.activePeer!.remoteEpk, a.remoteEpk);
      expect(conn.activeRoomId, a.roomId);
      expect(channelA.room, a.roomId);
      expect(channelA.sent.whereType<WorkspaceBrowse>(), isEmpty);
      expect(channelB.sent.whereType<WorkspaceBrowse>(), isEmpty);
      conn.dispose();
      prefs.dispose();
      await channelA.messages.close();
      await channelA.control.close();
      await channelB.messages.close();
      await channelB.control.close();
    },
  );
}
