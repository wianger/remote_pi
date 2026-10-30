import 'dart:async';
import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/ui/workspaces/states/new_session_state.dart';
import 'package:app/ui/workspaces/viewmodels/new_session_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

const host = WorkspaceHost(id: 'computer', label: 'Computer', online: true);
WorkspaceDirectory directory(
  String path, {
  List<WorkspaceAgent> agents = const [WorkspaceAgent.pi, WorkspaceAgent.codex],
}) => WorkspaceDirectory(
  path: path,
  home: '/home',
  parent: '/',
  roots: const ['/'],
  folders: const [WorkspaceFolder(name: 'project', path: '/project')],
  agents: agents,
);

class FakeWorkspaces extends IWorkspaceRepository {
  @override
  WorkspaceSelection? get currentSelection =>
      const WorkspaceSelection('computer', 'original');
  @override
  Future<List<WorkspaceHost>> listHosts() async => [host];
  Future<WorkspaceDirectory> Function(String)? onBrowse;
  final opened = <WorkspaceAgent>[];
  final restored = <WorkspaceSelection?>[];
  @override
  Future<WorkspaceDirectory> browse(
    String hostId, {
    String? path,
    bool showHidden = false,
  }) async => onBrowse == null
      ? directory(path ?? '/home')
      : await onBrowse!(path ?? '/home');
  @override
  Future<OpenedWorkspace> open(
    String hostId,
    String path,
    WorkspaceAgent agent,
  ) async {
    opened.add(agent);
    return OpenedWorkspace(
      hostId: hostId,
      hostLabel: host.label,
      path: path,
      roomId: 'new',
      name: 'project',
      agent: agent,
    );
  }

  @override
  Future<void> restore(WorkspaceSelection? selection) async {
    restored.add(selection);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'future agent ids are selected and opened without a mobile whitelist',
    () async {
      const future = WorkspaceAgent(id: 'future-agent', label: 'New Agent');
      const unavailable = WorkspaceAgent(
        id: 'offline-agent',
        label: 'Unavailable',
        available: false,
      );
      final repo = FakeWorkspaces()
        ..onBrowse = (path) async =>
            directory(path, agents: [future, unavailable]);
      final vm = NewSessionViewModel(repo);
      await tick();
      expect((vm.state as NewSessionReady).agent.id, 'future-agent');
      vm.setAgent(
        const WorkspaceAgent(
          id: 'offline-agent',
          label: 'Spoofed availability',
        ),
      );
      expect((vm.state as NewSessionReady).agent.id, 'future-agent');
      final opened = await vm.open();
      expect(opened!.agent.id, 'future-agent');
      expect(repo.opened.single.id, 'future-agent');
      vm.dispose();
    },
  );

  test(
    'catalog refresh keeps the selected id and refreshes its label',
    () async {
      final repo = FakeWorkspaces();
      final vm = NewSessionViewModel(repo);
      await tick();
      vm.setAgent(WorkspaceAgent.codex);
      repo.onBrowse = (path) async => directory(
        path,
        agents: const [WorkspaceAgent(id: 'codex', label: 'Computer Codex')],
      );
      await vm.browse(path: '/project');
      expect((vm.state as NewSessionReady).agent.label, 'Computer Codex');
      vm.dispose();
    },
  );

  test(
    'loads folders, selects Codex and opens the chosen computer directory',
    () async {
      final repo = FakeWorkspaces();
      final vm = NewSessionViewModel(repo);
      await tick();
      expect((vm.state as NewSessionReady).directory!.path, '/home');
      await vm.browse(path: '/project');
      vm.setAgent(WorkspaceAgent.codex);
      final result = await vm.open();
      expect(result!.path, '/project');
      expect(repo.opened, [WorkspaceAgent.codex]);
      await vm.cancel();
      expect(repo.restored, isEmpty);
      vm.dispose();
    },
  );

  test('late folder response cannot overwrite a newer navigation', () async {
    final repo = FakeWorkspaces();
    final vm = NewSessionViewModel(repo);
    await tick();
    final old = Completer<WorkspaceDirectory>();
    repo.onBrowse = (path) =>
        path == '/old' ? old.future : Future.value(directory(path));
    final pending = vm.browse(path: '/old');
    await vm.browse(path: '/new');
    old.complete(directory('/old'));
    await pending;
    expect((vm.state as NewSessionReady).directory!.path, '/new');
    vm.dispose();
  });

  test(
    'cancel invalidates folder response and restores the previous room once',
    () async {
      final repo = FakeWorkspaces();
      final vm = NewSessionViewModel(repo);
      await tick();
      final response = Completer<WorkspaceDirectory>();
      repo.onBrowse = (_) => response.future;
      final browse = vm.browse(path: '/pending');
      await vm.cancel();
      await vm.cancel();
      response.complete(directory('/pending'));
      await browse;
      expect(repo.restored.single!.roomId, 'original');
      expect((vm.state as NewSessionReady).directory!.path, '/home');
      vm.dispose();
    },
  );

  test('shows startup error and allows retry', () async {
    final repo = FakeWorkspaces();
    final vm = NewSessionViewModel(repo);
    await tick();
    repo.onBrowse = (_) async => throw const WorkspaceFailure('offline');
    await vm.browse(path: '/new');
    expect((vm.state as NewSessionReady).error, 'offline');
    expect((vm.state as NewSessionReady).loading, false);
    vm.dispose();
  });
}
