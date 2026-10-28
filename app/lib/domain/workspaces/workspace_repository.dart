import 'package:app/domain/contracts/repository.dart';

enum WorkspaceAgent {
  pi('pi', 'Pi'),
  codex('codex', 'Codex');

  const WorkspaceAgent(this.id, this.label);
  final String id;
  final String label;
}

class WorkspaceHost {
  const WorkspaceHost({
    required this.id,
    required this.label,
    required this.online,
  });
  final String id;
  final String label;
  final bool online;
}

class WorkspaceFolder {
  const WorkspaceFolder({required this.name, required this.path});
  final String name;
  final String path;
}

class WorkspaceDirectory {
  const WorkspaceDirectory({
    required this.path,
    required this.home,
    required this.parent,
    required this.roots,
    required this.folders,
    required this.availableAgents,
    this.truncated = false,
  });
  final String path;
  final String home;
  final String? parent;
  final List<String> roots;
  final List<WorkspaceFolder> folders;
  final Set<WorkspaceAgent> availableAgents;
  final bool truncated;
}

class OpenedWorkspace {
  const OpenedWorkspace({
    required this.hostId,
    required this.hostLabel,
    required this.path,
    required this.roomId,
    required this.name,
    required this.agent,
  });
  final String hostId;
  final String hostLabel;
  final String path;
  final String roomId;
  final String name;
  final WorkspaceAgent agent;
}

class WorkspaceSelection {
  const WorkspaceSelection(this.hostId, this.roomId);
  final String hostId;
  final String roomId;
}

class WorkspaceFailure implements Exception {
  const WorkspaceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class IWorkspaceRepository extends Repository {
  WorkspaceSelection? get currentSelection;
  Future<List<WorkspaceHost>> listHosts();
  Future<WorkspaceDirectory> browse(
    String hostId, {
    String? path,
    bool showHidden = false,
  });
  Future<OpenedWorkspace> open(
    String hostId,
    String path,
    WorkspaceAgent agent,
  );
  Future<void> restore(WorkspaceSelection? selection);
}
