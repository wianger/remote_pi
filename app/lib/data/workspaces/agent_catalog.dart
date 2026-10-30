import 'package:app/domain/workspaces/workspace_repository.dart';

/// Keep future ids and availability metadata from a paired computer intact.
List<WorkspaceAgent> decodeWorkspaceAgents(Object? raw) {
  if (raw is! List) return const [];
  final agents = <String, WorkspaceAgent>{};
  for (final entry in raw) {
    if (entry is! Map) continue;
    final id = entry['id'];
    if (id is! String || id.trim().isEmpty || agents.containsKey(id)) continue;
    final name = entry['name'];
    agents[id] = WorkspaceAgent(
      id: id,
      label: name is String && name.trim().isNotEmpty ? name : id,
      description: entry['description'] is String ? entry['description'] : '',
      available: entry['available'] == true,
      unavailableReason: entry['reason'] is String ? entry['reason'] : null,
    );
  }
  return List.unmodifiable(agents.values);
}

/// Old room announcements lack an agent id. Only use their legacy naming
/// convention for Pi/Codex; other ids must be resolved by the computer.
bool matchesLegacyWorkspaceAgent(String? roomName, WorkspaceAgent agent) {
  final codex = roomName?.startsWith('Codex · ') == true;
  return switch (agent.id) {
    'pi' => !codex,
    'codex' => codex,
    _ => false,
  };
}
