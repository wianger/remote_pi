import 'package:app/ui/core/branding/app_brand.dart';
import 'dart:math' as math;
import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
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
    context.read<SessionSelection>().select(
      item.peer.remoteEpk,
      item.room.roomId,
      item.displayName,
      device,
      online,
    );
    close?.call();
    context.go(
      '/chat',
      extra: {'title': item.displayName, 'device': device, 'online': online},
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete from phone?'),
      content: Text(
        'Remove "${item.displayName}" and clear its cached messages on this phone? Computer history and the running agent are kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;
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
                width: math.min(336, MediaQuery.sizeOf(context).width - 44),
                backgroundColor: context.colors.surface,
                shape: const RoundedRectangleBorder(),
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
    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
              child: Row(
                children: [
                  const AppMark(size: 32, tile: true),
                  const SizedBox(width: 10),
                  Text(
                    kAppName,
                    style: brandTextStyle(fontSize: 19, color: colors.text),
                  ),
                  const Spacer(),
                  if (widget.close != null)
                    IconButton(
                      onPressed: widget.close,
                      tooltip: 'Close sidebar',
                      icon: const Icon(LucideIcons.panelLeftClose, size: 19),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScopeSelector(
                label: 'Device',
                icon: LucideIcons.monitor,
                child: DropdownButton<String>(
                  key: const Key('device-selector'),
                  value: vm.selectedDevice,
                  isExpanded: true,
                  hint: const Text('Pair a device'),
                  items: vm.devices.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value.nickname ?? entry.value.sessionName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _choosing
                      ? null
                      : (value) {
                          if (value != null) {
                            _choose(() => vm.selectDevice(value));
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScopeSelector(
                label: 'Workspace',
                icon: LucideIcons.folder,
                child: DropdownButton<String>(
                  key: const Key('workspace-selector'),
                  value: vm.selectedWorkspace,
                  isExpanded: true,
                  hint: Text(
                    vm.selectedDevice == null
                        ? 'Choose a device first'
                        : 'No workspaces yet',
                  ),
                  items: workspaces.entries.map((entry) {
                    final path = entry.value.room.cwd ?? 'Other sessions';
                    final parts = path
                        .split(RegExp(r'[/\\]'))
                        .where((part) => part.isNotEmpty);
                    final label = parts.lastOrNull ?? path;
                    final duplicate =
                        workspaces.values
                            .where(
                              (item) =>
                                  (item.room.cwd ?? 'Other sessions')
                                      .split(RegExp(r'[/\\]'))
                                      .where((part) => part.isNotEmpty)
                                      .lastOrNull ==
                                  label,
                            )
                            .length >
                        1;
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Tooltip(
                        message: path,
                        child: Text(
                          duplicate ? path : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _choosing
                      ? null
                      : (value) {
                          if (value != null) {
                            _choose(() => vm.selectWorkspace(value));
                          }
                        },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: FilledButton.icon(
                onPressed: () {
                  widget.close?.call();
                  openNewSession(context);
                },
                icon: const Icon(LucideIcons.plus, size: 17),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text('New session'),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                style: context.typo.sansBody.copyWith(fontSize: 14),
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
            Expanded(
              child: state is HomeLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state is HomeNoPeer
                              ? 'Pair a computer to get started.'
                              : _query.isNotEmpty
                              ? 'No matching sessions in this workspace.'
                              : 'No sessions on this device yet. Open a workspace to begin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.muted,
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in items)
                          _SessionRow(
                            item: item,
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
                            onTap: _opening ? null : () => _open(item),
                            onDelete: () => _deleteFromPhone(context, item),
                          ),
                      ],
                    ),
            ),
            Divider(color: colors.border, height: 1),
            ListTile(
              dense: true,
              leading: Icon(
                LucideIcons.scanLine,
                size: 18,
                color: colors.muted2,
              ),
              title: const Text(
                'Pair computer',
                style: TextStyle(fontSize: 13),
              ),
              onTap: () {
                widget.close?.call();
                context.push('/pair');
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(
                LucideIcons.settings2,
                size: 18,
                color: colors.muted2,
              ),
              title: const Text('Settings', style: TextStyle(fontSize: 13)),
              trailing: Text(
                vm.isRelayConnected ? 'Connected' : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  color: vm.isRelayConnected ? colors.success : colors.muted,
                ),
              ),
              onTap: () {
                widget.close?.call();
                context.push('/settings');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 17),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    child: DropdownButtonHideUnderline(
      child: DefaultTextStyle.merge(
        style: context.typo.sansBody.copyWith(fontSize: 13),
        child: child,
      ),
    ),
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.item,
    required this.selected,
    required this.online,
    required this.working,
    this.onTap,
    this.onDelete,
  });
  final HomeItem item;
  final bool selected, online, working;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final codex = item.room.name?.startsWith('Codex · ') == true;
    final title = codex
        ? item.displayName.replaceFirst('Codex · ', '')
        : item.displayName;
    final statusColor = working
        ? colors.working
        : online
        ? colors.success
        : colors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: colors.userBubble,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Row(
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
              Text(
                working
                    ? 'Working'
                    : online
                    ? 'Ready'
                    : 'Offline',
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: ValueKey('session-menu-${item.room.roomId}'),
          tooltip: 'Session actions',
          icon: Icon(LucideIcons.ellipsis, size: 18, color: colors.muted2),
          onSelected: (_) => onDelete?.call(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete from phone')),
          ],
        ),
        onLongPress: onDelete,
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
        backgroundColor: colors.bg,
        title: const Text('Sessions'),
        leading: SessionShell.menuOf(context) == null
            ? null
            : IconButton(
                onPressed: SessionShell.menuOf(context),
                tooltip: 'Sessions',
                icon: const Icon(LucideIcons.panelLeft, size: 21),
              ),
        actions: [
          IconButton(
            onPressed: () => openNewSession(context),
            tooltip: 'New session',
            icon: const Icon(LucideIcons.squarePen, size: 20),
          ),
        ],
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
                  style: context.typo.reading.copyWith(
                    fontSize: 34,
                    height: 1.2,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose a device, a workspace, then a session.',
                  style: TextStyle(color: colors.muted2, fontSize: 15),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => openNewSession(context),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Text('Open a workspace'),
                  ),
                ),
                const SizedBox(height: 34),
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
                      onDelete: () => _deleteFromPhone(context, item),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
