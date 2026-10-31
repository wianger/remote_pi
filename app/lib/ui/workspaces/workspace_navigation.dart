import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<OpenedWorkspace?> openNewSession(
  BuildContext context, {
  String? workspaceKey,
}) async {
  final workspace = await context.push<OpenedWorkspace>('/new-session');
  if (!context.mounted || workspace == null) return null;
  if (workspaceKey != null) {
    await context.read<HomeViewModel>().assignSessionRoomToWorkspace(
      workspace.hostId,
      workspace.roomId,
      workspaceKey,
    );
    if (!context.mounted) return workspace;
  }
  context.read<SessionSelection>().select(
    workspace.hostId,
    workspace.roomId,
    workspace.name,
    workspace.hostLabel,
    true,
  );
  context.go(
    '/chat',
    extra: {
      'title': workspace.name,
      'device': workspace.hostLabel,
      'online': true,
    },
  );
  return workspace;
}
