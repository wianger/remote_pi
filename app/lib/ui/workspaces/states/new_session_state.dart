import 'package:app/domain/workspaces/workspace_repository.dart';

sealed class NewSessionState {
  const NewSessionState();
}

class NewSessionLoading extends NewSessionState {
  const NewSessionLoading();
}

class NewSessionUnavailable extends NewSessionState {
  const NewSessionUnavailable(this.message);
  final String message;
}

class NewSessionReady extends NewSessionState {
  const NewSessionReady({
    required this.hosts,
    required this.host,
    this.directory,
    this.agent = WorkspaceAgent.pi,
    this.loading = false,
    this.opening = false,
    this.showHidden = false,
    this.query = '',
    this.error,
  });
  final List<WorkspaceHost> hosts;
  final WorkspaceHost host;
  final WorkspaceDirectory? directory;
  final WorkspaceAgent agent;
  final bool loading;
  final bool opening;
  final bool showHidden;
  final String query;
  final String? error;

  bool get canOpen =>
      !loading &&
      !opening &&
      directory?.availableAgents.contains(agent) == true;
  List<WorkspaceFolder> get visibleFolders =>
      directory?.folders
          .where(
            (folder) =>
                folder.name.toLowerCase().contains(query.trim().toLowerCase()),
          )
          .toList() ??
      const [];

  NewSessionReady copyWith({
    List<WorkspaceHost>? hosts,
    WorkspaceHost? host,
    WorkspaceDirectory? directory,
    WorkspaceAgent? agent,
    bool? loading,
    bool? opening,
    bool? showHidden,
    String? query,
    String? error,
    bool clearDirectory = false,
    bool clearError = false,
  }) => NewSessionReady(
    hosts: hosts ?? this.hosts,
    host: host ?? this.host,
    directory: clearDirectory ? null : directory ?? this.directory,
    agent: agent ?? this.agent,
    loading: loading ?? this.loading,
    opening: opening ?? this.opening,
    showHidden: showHidden ?? this.showHidden,
    query: query ?? this.query,
    error: clearError ? null : error ?? this.error,
  );

  @override
  bool operator ==(Object other) =>
      other is NewSessionReady &&
      identical(hosts, other.hosts) &&
      host.id == other.host.id &&
      identical(directory, other.directory) &&
      agent == other.agent &&
      loading == other.loading &&
      opening == other.opening &&
      showHidden == other.showHidden &&
      query == other.query &&
      error == other.error;
  @override
  int get hashCode => Object.hash(
    hosts,
    host.id,
    directory,
    agent,
    loading,
    opening,
    showHidden,
    query,
    error,
  );
}
