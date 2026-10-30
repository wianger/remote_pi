import 'dart:async';
import 'agent_catalog.dart';

import 'package:app/data/preferences/preferences.dart';
import 'package:app/data/transport/channel.dart';
import 'package:app/data/transport/connection_manager.dart';
import 'package:app/data/transport/epk_encoding.dart';
import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/pairing/storage.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/protocol/uuid7.dart';

class WorkspaceRepository extends IWorkspaceRepository {
  WorkspaceRepository(
    this._connection,
    this._storage,
    this._preferences, {
    this.timeout = const Duration(seconds: 25),
  });
  final ConnectionManager _connection;
  final PairingStorage _storage;
  final Preferences _preferences;
  final Duration timeout;

  @override
  WorkspaceSelection? get currentSelection {
    final peer = _connection.activePeer;
    return peer == null
        ? null
        : WorkspaceSelection(peer.remoteEpk, _connection.activeRoomId);
  }

  String _label(PeerRecord peer) {
    if (peer.nickname?.isNotEmpty == true) return peer.nickname!;
    return peer.sessionName;
  }

  bool _online(PeerRecord peer) => _connection
      .roomsFor(peer.remoteEpk)
      .any((room) => _connection.isRoomLive(peer.remoteEpk, room.roomId));

  @override
  Future<List<WorkspaceHost>> listHosts() async {
    final peers = await _storage.listPeers();
    _connection.subscribeToPeers(peers.map((peer) => peer.remoteEpk).toList());
    return peers
        .map(
          (peer) => WorkspaceHost(
            id: peer.remoteEpk,
            label: _label(peer),
            online: _online(peer),
          ),
        )
        .toList();
  }

  Future<PeerRecord> _peer(String hostId) async {
    final peers = await _storage.listPeers();
    for (final peer in peers) {
      if (toStandardB64(peer.remoteEpk) == toStandardB64(hostId)) return peer;
    }
    throw const WorkspaceFailure(
      'Pair this computer before opening a session.',
    );
  }

  Future<IChannel> _connect(String hostId) async {
    final peer = await _peer(hostId);
    final rooms = _connection
        .roomsFor(peer.remoteEpk)
        .where((room) => _connection.isRoomLive(peer.remoteEpk, room.roomId))
        .toList();
    if (rooms.isEmpty) {
      throw const WorkspaceFailure(
        'This computer is offline. Open Remote Pi on the computer and try again.',
      );
    }
    final current = _connection.activeRoomId;
    final room = rooms.firstWhere(
      (entry) => entry.roomId == current,
      orElse: () => rooms.first,
    );
    await _connection.switchTo(peer.copyWith(roomId: room.roomId));
    _connection.switchRoom(room.roomId);
    final channel = _connection.channel;
    if (channel == null) {
      throw const WorkspaceFailure('Could not connect to this computer.');
    }
    return channel;
  }

  Future<Map<String, dynamic>> _request(
    String hostId,
    ClientMessage Function(String) makeMessage,
  ) async {
    final channel = await _connect(hostId);
    final id = uuid7();
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription<ServerMessage> subscription;
    subscription = channel.serverMessages.listen(
      (message) {
        switch (message) {
          case WorkspaceListing(:final inReplyTo, :final directory)
              when inReplyTo == id:
            if (!completer.isCompleted) completer.complete(directory);
          case WorkspaceOpened(:final inReplyTo, :final workspace)
              when inReplyTo == id:
            if (!completer.isCompleted) completer.complete(workspace);
          case WorkspaceError(:final inReplyTo, :final error)
              when inReplyTo == id:
            if (!completer.isCompleted) {
              completer.completeError(WorkspaceFailure(error));
            }
          case ErrorMessage(:final inReplyTo, :final message)
              when inReplyTo == id:
            if (!completer.isCompleted) {
              completer.completeError(WorkspaceFailure(message));
            }
          default:
            break;
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            const WorkspaceFailure('The computer disconnected.'),
          );
        }
      },
      onError: (Object _, StackTrace _) {
        if (!completer.isCompleted) {
          completer.completeError(
            const WorkspaceFailure('The computer disconnected.'),
          );
        }
      },
    );
    // Observe reply errors immediately: a synchronous channel can reply while
    // send() is still completing. Keep those errors on the awaited chain.
    final reply = completer.future.timeout(
      timeout,
      onTimeout: () {
        throw const WorkspaceFailure(
          'The computer did not respond. Update Remote Pi on the computer and reconnect.',
        );
      },
    );
    try {
      final results = await Future.wait<dynamic>([
        reply,
        channel.send(makeMessage(id)),
      ], eagerError: true);
      return results.first as Map<String, dynamic>;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<WorkspaceDirectory> browse(
    String hostId, {
    String? path,
    bool showHidden = false,
  }) async {
    try {
      final data = await _request(
        hostId,
        (id) => WorkspaceBrowse(id: id, path: path, showHidden: showHidden),
      );
      final directories = (data['directories'] as List).cast<Map>();
      return WorkspaceDirectory(
        path: data['path'] as String,
        home: data['home'] as String,
        parent: data['parent'] as String?,
        roots: (data['roots'] as List).cast<String>(),
        folders: directories
            .map(
              (entry) => WorkspaceFolder(
                name: entry['name'] as String,
                path: entry['path'] as String,
              ),
            )
            .toList(),
        agents: decodeWorkspaceAgents(data['agents']),
        truncated: data['truncated'] == true,
      );
    } on WorkspaceFailure {
      rethrow;
    } catch (_) {
      throw const WorkspaceFailure(
        'Could not read the folders on this computer.',
      );
    }
  }

  @override
  Future<OpenedWorkspace> open(
    String hostId,
    String path,
    WorkspaceAgent agent,
  ) async {
    final peer = await _peer(hostId);
    RoomInfo? existing;
    for (final room in _connection.roomsFor(hostId)) {
      if (room.cwd == path &&
          matchesLegacyWorkspaceAgent(room.name, agent) &&
          _connection.isRoomLive(hostId, room.roomId)) {
        existing = room;
        break;
      }
    }
    String roomId;
    String cwd;
    String name;
    if (existing != null) {
      roomId = existing.roomId;
      cwd = existing.cwd ?? path;
      name = existing.name ?? agent.label;
    } else {
      final result = await _request(
        hostId,
        (id) => WorkspaceOpen(id: id, path: path, agent: agent.id),
      );
      roomId = result['room_id'] as String;
      cwd = result['cwd'] as String;
      name = result['name'] as String;
      final deadline = DateTime.now().add(timeout);
      RoomInfo? ready;
      while (DateTime.now().isBefore(deadline)) {
        for (final room in _connection.roomsFor(hostId)) {
          if ((room.roomId == roomId || room.cwd == cwd && room.name == name) &&
              _connection.isRoomLive(hostId, room.roomId)) {
            ready = room;
            break;
          }
        }
        if (ready != null) {
          roomId = ready.roomId;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (ready == null) {
        throw WorkspaceFailure(
          '${agent.label} did not come online. Check its sign-in and startup on the computer, then try again.',
        );
      }
    }
    await _preferences.setSelectedRoom(epk: peer.remoteEpk, roomId: roomId);
    await _connection.switchTo(peer.copyWith(roomId: roomId));
    _connection.switchRoom(roomId);
    return OpenedWorkspace(
      hostId: peer.remoteEpk,
      hostLabel: _label(peer),
      path: cwd,
      roomId: roomId,
      name: name,
      agent: agent,
    );
  }

  @override
  Future<void> restore(WorkspaceSelection? selection) async {
    if (selection == null) return;
    final peer = await _peer(selection.hostId);
    await _connection.switchTo(peer.copyWith(roomId: selection.roomId));
    _connection.switchRoom(selection.roomId);
  }
}
