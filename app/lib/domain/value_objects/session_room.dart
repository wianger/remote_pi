/// A Pi conversation can have a daemon and a resumed terminal endpoint.
/// Keep routing ids distinct; only grouping/cache identity is shared.
final _piRoom = RegExp(r'^pi_([A-Za-z0-9_-]{16})_([di])_([A-Za-z0-9_-]{12})$');

String conversationRoomId(String roomId) {
  final match = _piRoom.firstMatch(roomId);
  return match == null ? roomId : 'pi_${match.group(1)}';
}

bool isInteractivePiRoom(String roomId) =>
    _piRoom.firstMatch(roomId)?.group(2) == 'i';

String? legacyPiInstanceRoomId(String roomId) =>
    _piRoom.firstMatch(roomId)?.group(3);
