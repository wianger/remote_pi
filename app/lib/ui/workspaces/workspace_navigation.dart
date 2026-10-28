import 'package:app/domain/workspaces/workspace_repository.dart';
import 'package:app/routing/adaptive.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<void> openNewSession(BuildContext context) async {
  final workspace = await context.push<OpenedWorkspace>('/new-session');
  if (!context.mounted || workspace == null) return;
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
}
