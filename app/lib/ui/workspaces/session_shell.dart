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
  bool _workingOnly = false;

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
    final all = state is HomeList
        ? state.items(normalizeEpk: HomeViewModel.normalizeEpkForLookup)
        : <HomeItem>[];
    final working = all
        .where(
          (item) => vm.isRoomWorking(item.peer.remoteEpk, item.room.roomId),
        )
        .length;
    final items = all
        .where(
          (item) =>
              (!_workingOnly ||
                  vm.isRoomWorking(item.peer.remoteEpk, item.room.roomId)) &&
              '${item.displayName} ${item.room.cwd ?? ''} ${item.peer.nickname ?? item.peer.sessionName}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    final groups = <String, List<HomeItem>>{};
    for (final item in items) {
      (groups[item.peer.remoteEpk] ??= []).add(item);
    }
    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Icon(LucideIcons.layers2, color: colors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Remote Pi',
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workspaces',
                    style: context.typo.title.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${all.length} sessions${working > 0 ? ' · $working working' : ''}',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.close?.call();
                  openNewSession(context);
                },
                icon: const Icon(LucideIcons.plus, size: 17),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Text('New session'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: context.typo.sansBody.copyWith(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search projects and sessions',
                  isDense: true,
                  prefixIcon: Icon(LucideIcons.search, size: 17),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_workingOnly,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _workingOnly = false),
                  ),
                  ChoiceChip(
                    label: Text('Working $working'),
                    selected: _workingOnly,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _workingOnly = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: state is HomeLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state is HomeNoPeer
                              ? 'Pair a computer to see your workspaces.'
                              : _workingOnly
                              ? 'No sessions are working right now.'
                              : _query.isEmpty
                              ? 'Your projects will appear when a computer is online.'
                              : 'No matching workspaces',
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
                        for (final group in groups.values) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.monitor,
                                  size: 14,
                                  color: colors.muted,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    group.first.peer.nickname ??
                                        group.first.peer.sessionName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.muted2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${group.length}',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final item in group)
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
                            ),
                        ],
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

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.item,
    required this.selected,
    required this.online,
    required this.working,
    this.onTap,
  });
  final HomeItem item;
  final bool selected, online, working;
  final VoidCallback? onTap;
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
            selected ? LucideIcons.folderOpen : LucideIcons.folder,
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
        trailing: selected
            ? Icon(LucideIcons.chevronRight, size: 14, color: colors.muted2)
            : null,
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
    final items = state is HomeList
        ? state.items(normalizeEpk: HomeViewModel.normalizeEpkForLookup)
        : <HomeItem>[];
    final active = items
        .where(
          (item) => vm.isRoomWorking(item.peer.remoteEpk, item.room.roomId),
        )
        .length;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: const Text('Workspaces'),
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
                  'Your projects and agents, in one place.',
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
                      'Your workspaces',
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
                          : 'Open Remote Pi on your computer to see its projects here.',
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
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
