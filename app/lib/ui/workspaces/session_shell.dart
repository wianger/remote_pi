import 'package:app/ui/core/branding/app_brand.dart';
import 'dart:math' as math;
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/workspaces/session_dialogs.dart';
import 'package:app/ui/workspaces/widgets/scope_switchers.dart';
import 'package:app/ui/workspaces/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

Future<void> _openSession(
  BuildContext context,
  HomeItem item, {
  VoidCallback? close,
}) async {
  final vm = context.read<HomeViewModel>();
  try {
    await vm.openSession(item.peer.remoteEpk, roomId: item.room.roomId);
    if (!context.mounted) return;
    final device = item.peer.nickname ?? item.peer.sessionName;
    final online = vm.isRoomLive(item.peer.remoteEpk, item.room.roomId);
    final displayName = vm.displayNameOf(item);
    context.read<SessionSelection>().select(
      item.peer.remoteEpk,
      item.room.roomId,
      displayName,
      device,
      online,
    );
    close?.call();
    context.go(
      '/chat',
      extra: {'title': displayName, 'device': device, 'online': online},
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this session. Try again.'),
        ),
      );
    }
  }
}

Future<void> _deleteFromPhone(BuildContext context, HomeItem item) async {
  final vm = context.read<HomeViewModel>();
  final selection = context.read<SessionSelection>();
  final wasSelected = selection.matches(item.peer.remoteEpk, item.room.roomId);
  final confirmed = await showSessionDeleteDialog(
    context,
    name: item.displayName,
  );
  if (!context.mounted || !confirmed) return;
  try {
    await vm.deleteSession(item);
    if (!context.mounted) return;
    if (wasSelected) {
      selection.clear();
      context.go('/home');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove this session. Try again.'),
        ),
      );
    }
  }
}

enum _SessionAction { rename, info, delete }

Future<void> _showSessionActions(
  BuildContext context,
  HomeItem item, {
  required String displayName,
}) async {
  final action = await showModalBottomSheet<_SessionAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil, size: 20),
              title: const Text('Rename'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_SessionAction.rename),
            ),
            ListTile(
              leading: const Icon(LucideIcons.info, size: 20),
              title: const Text('Info'),
              onTap: () => Navigator.of(sheetContext).pop(_SessionAction.info),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.trash2,
                size: 20,
                color: sheetContext.colors.error,
              ),
              title: Text(
                'Delete from phone',
                style: TextStyle(color: sheetContext.colors.error),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_SessionAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  final vm = context.read<HomeViewModel>();
  switch (action) {
    case _SessionAction.rename:
      final name = await showSessionRenameDialog(
        context,
        currentName: displayName,
      );
      if (name != null) await vm.renameSession(item, name);
    case _SessionAction.info:
      await showSessionInfoDialog(
        context,
        peer: item.peer,
        room: item.room,
        name: displayName,
      );
    case _SessionAction.delete:
      await _deleteFromPhone(context, item);
  }
}

Future<void> showCreateWorkspace(BuildContext context) async {
  final vm = context.read<HomeViewModel>();
  final device = vm.selectedDevice;
  if (device == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pair a device first.')));
    return;
  }
  final name = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New workspace', style: sheetContext.typo.title),
              const SizedBox(height: 8),
              Text(
                'A workspace groups sessions from any folders on this computer.',
                style: sheetContext.typo.sansBody.copyWith(
                  color: sheetContext.colors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                onChanged: (_) => setSheetState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Workspace name',
                  hintText: 'e.g. Remote Pi',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: name.text.trim().isEmpty
                    ? null
                    : () async {
                        await vm.createWorkspace(
                          name: name.text,
                          deviceEpk: device,
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                icon: const Icon(LucideIcons.layoutDashboard, size: 18),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Create workspace'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
}

Future<void> _startSession(BuildContext context, {VoidCallback? close}) async {
  final vm = context.read<HomeViewModel>();
  final workspace = vm.selectedWorkspace;
  if (workspace == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Create a workspace first.')));
    return;
  }
  close?.call();
  await openNewSession(context, workspaceKey: workspace);
}

class SessionShell extends StatefulWidget {
  const SessionShell({super.key, required this.child});
  final Widget child;
  static VoidCallback? menuOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SessionMenu>()?.open;
  @override
  State<SessionShell> createState() => _SessionShellState();
}

class _SessionShellState extends State<SessionShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    return _SessionMenu(
      open: wide ? null : () => _scaffold.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffold,
        backgroundColor: context.colors.bg,
        drawer: wide
            ? null
            : Drawer(
                width: math.min(352, MediaQuery.sizeOf(context).width - 28),
                backgroundColor: context.colors.bg.withValues(alpha: 0),
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(28),
                  ),
                ),
                child: SessionSidebar(
                  close: () => _scaffold.currentState?.closeDrawer(),
                ),
              ),
        body: Row(
          children: [
            if (wide) ...[
              const SizedBox(width: 304, child: SessionSidebar()),
              VerticalDivider(width: 1, color: context.colors.border),
            ],
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _SessionMenu extends InheritedWidget {
  const _SessionMenu({required this.open, required super.child});
  final VoidCallback? open;
  @override
  bool updateShouldNotify(_SessionMenu oldWidget) => open != oldWidget.open;
}

class SessionSidebar extends StatefulWidget {
  const SessionSidebar({super.key, this.close});
  final VoidCallback? close;
  @override
  State<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends State<SessionSidebar> {
  String _query = '';
  bool _opening = false;
  bool _choosing = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(Future<void> Function() action) async {
    if (_choosing) return;
    setState(() => _choosing = true);
    try {
      await action();
      if (!mounted) return;
      _search.clear();
      setState(() => _query = '');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your selection. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<void> _open(HomeItem item) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await _openSession(context, item, close: widget.close);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _deleteSelectedDevice(HomeViewModel vm) async {
    final epk = vm.selectedDevice;
    if (epk == null) return;
    final peer = vm.devices[epk];
    if (peer == null) return;
    final name = peer.nickname ?? peer.sessionName;
    final confirmed = await showDeviceDeleteDialog(context, name: name);
    if (!mounted || !confirmed) return;
    try {
      await vm.deleteDevice(epk);
      if (!mounted) return;
      context.read<SessionSelection>().clear();
      widget.close?.call();
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this device. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<HomeViewModel>();
    final state = vm.state;
    final selection = context.watch<SessionSelection>();
    final workspaces = vm.workspaces;
    final items = vm.workspaceItems
        .where(
          (item) =>
              item.displayName.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return BayaGlassSurface(
      elevated: false,
      child: Material(
        color: colors.bg.withValues(alpha: 0),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: state is HomeLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
                            child: Row(
                              children: [
                                const AppMark(size: 36, tile: true),
                                const SizedBox(width: 10),
                                Text(
                                  kAppName,
                                  style: brandTextStyle(
                                    fontSize: 22,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DeviceSwitcher(
                              key: const Key('device-selector'),
                              devices: {
                                for (final entry in vm.devices.entries)
                                  entry.key:
                                      entry.value.nickname ??
                                      entry.value.sessionName,
                              },
                              selected: vm.selectedDevice,
                              enabled: !_choosing,
                              onSelected: (value) =>
                                  _choose(() => vm.selectDevice(value)),
                              onDeleteSelected: () => _deleteSelectedDevice(vm),
                              onRenameSelected: vm.selectedDevice == null
                                  ? null
                                  : () async {
                                      final epk = vm.selectedDevice!;
                                      final peer = vm.devices[epk];
                                      if (peer == null) return;
                                      final name = await showDeviceRenameDialog(
                                        context,
                                        currentName:
                                            peer.nickname ?? peer.sessionName,
                                      );
                                      if (name == null ||
                                          name.trim().isEmpty ||
                                          !context.mounted) {
                                        return;
                                      }
                                      await vm.renameDevice(epk, name);
                                    },
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: WorkspaceSwitcher(
                              key: const Key('workspace-selector'),
                              workspaces: workspaces,
                              labels: {
                                for (final key in workspaces.keys)
                                  key: vm.workspaceLabel(key) ?? key,
                              },
                              selected: vm.selectedWorkspace,
                              hasDevice: vm.selectedDevice != null,
                              enabled: !_choosing,
                              onSelected: (value) =>
                                  _choose(() => vm.selectWorkspace(value)),
                              onCreate: () => showCreateWorkspace(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: FilledButton.icon(
                              onPressed: vm.selectedWorkspace == null
                                  ? null
                                  : () => _startSession(
                                      context,
                                      close: widget.close,
                                    ),
                              icon: const Icon(
                                LucideIcons.messageSquarePlus,
                                size: 17,
                              ),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: Text('New session'),
                              ),
                              style: FilledButton.styleFrom(
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _search,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              style: context.typo.sansBody.copyWith(
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search sessions',
                                isDense: true,
                                prefixIcon: Icon(LucideIcons.search, size: 17),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                            child: Text(
                              'Sessions · ${vm.workspaceItems.length}',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (items.isEmpty)
                            SizedBox(
                              height: 200,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    state is HomeNoPeer
                                        ? 'Pair a computer to get started.'
                                        : _query.isNotEmpty
                                        ? 'No matching sessions in this workspace.'
                                        : 'No sessions in this workspace yet. '
                                              'Start one in any folder.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.muted,
                                      height: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  for (final item in items)
                                    _SessionRow(
                                      item: item,
                                      displayName: vm.displayNameOf(item),
                                      selected: selection.matches(
                                        item.peer.remoteEpk,
                                        item.room.roomId,
                                      ),
                                      online: vm.isRoomLive(
                                        item.peer.remoteEpk,
                                        item.room.roomId,
                                      ),
                                      working: vm.isRoomWorking(
                                        item.peer.remoteEpk,
                                        item.room.roomId,
                                      ),
                                      onTap: _opening
                                          ? null
                                          : () => _open(item),
                                      onLongPress: () => _showSessionActions(
                                        context,
                                        item,
                                        displayName: vm.displayNameOf(item),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              Divider(
                color: colors.border.withValues(alpha: 0.6),
                height: 1,
                indent: 20,
                endIndent: 20,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SidebarCircleAction(
                      key: const Key('sidebar-pair'),
                      tooltip: 'Pair computer',
                      icon: LucideIcons.scanLine,
                      onPressed: () {
                        widget.close?.call();
                        context.push('/pair');
                      },
                    ),
                    const SizedBox(width: 10),
                    _SidebarCircleAction(
                      key: const Key('sidebar-settings'),
                      tooltip: 'Settings',
                      icon: LucideIcons.settings2,
                      onPressed: () {
                        widget.close?.call();
                        context.push('/settings');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarCircleAction extends StatelessWidget {
  const _SidebarCircleAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BayaGlassSurface(
      radius: 23,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: 46,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 19, color: colors.accent),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.item,
    required this.displayName,
    required this.selected,
    required this.online,
    required this.working,
    this.onTap,
    this.onLongPress,
  });
  final HomeItem item;
  final String displayName;
  final bool selected, online, working;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final codex = item.room.name?.startsWith('Codex · ') == true;
    final title = codex
        ? displayName.replaceFirst('Codex · ', '')
        : displayName;
    final statusColor = working
        ? colors.working
        : online
        ? colors.success
        : colors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: colors.selection,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            selected ? LucideIcons.messagesSquare : LucideIcons.messageSquare,
            size: 19,
            color: selected ? colors.accent : colors.muted2,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            color: colors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    codex ? 'Codex' : 'Pi',
                    style: TextStyle(fontSize: 11, color: colors.muted2),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      working
                          ? 'Working'
                          : online
                          ? 'Ready'
                          : 'Offline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                  ),
                ],
              ),
              if (item.room.cwd case final cwd?)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    cwd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.monoSmall.copyWith(
                      fontSize: 10,
                      color: colors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        onLongPress: onLongPress,
        onTap: onTap,
      ),
    );
  }
}

class SessionWelcome extends StatelessWidget {
  const SessionWelcome({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<HomeViewModel>();
    final state = vm.state;
    final items = vm.workspaceItems;
    final active = items
        .where(
          (item) => vm.isRoomWorking(item.peer.remoteEpk, item.room.roomId),
        )
        .length;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg.withValues(alpha: 0),
        flexibleSpace: const BayaGlassSurface(
          radius: 0,
          elevated: false,
          child: SizedBox.expand(),
        ),
        centerTitle: true,
        title: const Text('Sessions'),
        leading: SessionShell.menuOf(context) == null
            ? null
            : IconButton(
                onPressed: SessionShell.menuOf(context),
                tooltip: 'Sessions',
                icon: const Icon(LucideIcons.panelLeft, size: 21),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
              children: [
                Text(
                  'What are we\nworking on?',
                  style: context.typo.sansBody.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose a device, a workspace, then a session.',
                  style: TextStyle(color: colors.muted2, fontSize: 15),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: vm.selectedDevice == null
                            ? null
                            : () => showCreateWorkspace(context),
                        icon: const Icon(LucideIcons.folderPlus, size: 17),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 11),
                          child: Text('New workspace'),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: vm.selectedWorkspace == null
                            ? null
                            : () => _startSession(context),
                        icon: const Icon(
                          LucideIcons.messageSquarePlus,
                          size: 17,
                        ),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 11),
                          child: Text('New session'),
                        ),
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      'Sessions in this workspace',
                      style: context.typo.sansBody.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$active working',
                      style: TextStyle(
                        color: active > 0 ? colors.working : colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      state is HomeNoPeer
                          ? 'Pair your computer from the sidebar to get started.'
                          : 'Start a connected agent on this device to see its projects here.',
                      style: TextStyle(color: colors.muted, height: 1.6),
                    ),
                  )
                else
                  for (final item in items)
                    _SessionRow(
                      item: item,
                      displayName: vm.displayNameOf(item),
                      selected: false,
                      online: vm.isRoomLive(
                        item.peer.remoteEpk,
                        item.room.roomId,
                      ),
                      working: vm.isRoomWorking(
                        item.peer.remoteEpk,
                        item.room.roomId,
                      ),
                      onTap: () => _openSession(context, item),
                      onLongPress: () => _showSessionActions(
                        context,
                        item,
                        displayName: vm.displayNameOf(item),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
