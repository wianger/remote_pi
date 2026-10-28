import 'package:app/routing/adaptive.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/home/states/home_state.dart';
import 'package:app/ui/home/viewmodels/home_viewmodel.dart';
import 'package:app/ui/workspaces/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

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
                width: 310,
                backgroundColor: context.colors.surface,
                child: SessionSidebar(
                  close: () => _scaffold.currentState?.closeDrawer(),
                ),
              ),
        body: Row(
          children: [
            if (wide) ...[
              const SizedBox(width: 300, child: SessionSidebar()),
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

  Future<void> _open(HomeItem item) async {
    if (_opening) return;
    setState(() => _opening = true);
    final vm = context.read<HomeViewModel>();
    await vm.openSession(item.peer.remoteEpk, roomId: item.room.roomId);
    if (!mounted) return;
    final device = item.peer.nickname ?? item.peer.sessionName;
    final online = vm.isRoomLive(item.peer.remoteEpk, item.room.roomId);
    context.read<SessionSelection>().select(
      item.peer.remoteEpk,
      item.room.roomId,
      item.displayName,
      device,
      online,
    );
    widget.close?.call();
    context.go(
      '/chat',
      extra: {'title': item.displayName, 'device': device, 'online': online},
    );
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vm = context.watch<HomeViewModel>();
    final state = vm.state;
    final selection = context.watch<SessionSelection>();
    final items = state is HomeList
        ? state
              .items(normalizeEpk: HomeViewModel.normalizeEpkForLookup)
              .where(
                (item) =>
                    '${item.displayName} ${item.room.cwd ?? ''} ${item.peer.sessionName}'
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList()
        : <HomeItem>[];
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Row(
                children: [
                  Icon(LucideIcons.terminal, color: colors.accent, size: 23),
                  const SizedBox(width: 10),
                  Text(
                    'Remote Pi',
                    style: brandTextStyle(fontSize: 20, color: colors.text),
                  ),
                  const Spacer(),
                  if (widget.close != null)
                    IconButton(
                      onPressed: widget.close,
                      tooltip: 'Close sidebar',
                      icon: const Icon(LucideIcons.panelLeftClose, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search sessions',
                  isDense: true,
                  prefixIcon: Icon(LucideIcons.search, size: 17),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'SESSIONS',
                    style: context.typo.mono.copyWith(
                      fontSize: 10,
                      color: colors.muted,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length}',
                    style: TextStyle(fontSize: 11, color: colors.muted),
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
                              ? 'Pair your computer to get started.'
                              : _query.isEmpty
                              ? 'Your sessions will appear here when the computer is online.'
                              : 'No matching sessions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.muted,
                            height: 1.6,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = selection.matches(
                          item.peer.remoteEpk,
                          item.room.roomId,
                        );
                        final online = vm.isRoomLive(
                          item.peer.remoteEpk,
                          item.room.roomId,
                        );
                        final working = vm.isRoomWorking(
                          item.peer.remoteEpk,
                          item.room.roomId,
                        );
                        final codex =
                            item.room.name?.startsWith('Codex · ') == true;
                        final device =
                            item.peer.nickname ?? item.peer.sessionName;
                        final title = codex
                            ? item.displayName.replaceFirst('Codex · ', '')
                            : item.displayName;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            selected: selected,
                            selectedTileColor: colors.accent.withValues(
                              alpha: 0.10,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            leading: Icon(
                              codex
                                  ? LucideIcons.sparkles
                                  : LucideIcons.messageSquare,
                              size: 18,
                              color: selected ? colors.accent : colors.muted2,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: selected ? colors.accent : colors.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${codex ? 'Codex' : 'Pi'} · $device',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.muted,
                              ),
                            ),
                            trailing: Tooltip(
                              message: working
                                  ? 'Working'
                                  : online
                                  ? 'Online'
                                  : 'Offline',
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: working
                                      ? colors.working
                                      : online
                                      ? colors.success
                                      : colors.muted,
                                ),
                              ),
                            ),
                            onTap: _opening ? null : () => _open(item),
                          ),
                        );
                      },
                    ),
            ),
            Divider(color: colors.border, height: 1),
            ListTile(
              leading: const Icon(LucideIcons.scanLine, size: 18),
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
              leading: const Icon(LucideIcons.settings2, size: 18),
              title: const Text('Settings', style: TextStyle(fontSize: 13)),
              trailing: Text(
                vm.isRelayConnected ? 'Connected' : 'Offline',
                style: TextStyle(
                  fontSize: 10,
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

class SessionWelcome extends StatelessWidget {
  const SessionWelcome({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        title: const Text('Workspace'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      LucideIcons.terminal,
                      size: 36,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Your work, wherever\nyou are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 29,
                      height: 1.2,
                      letterSpacing: -1,
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Continue a conversation from the sidebar, or choose a folder on your computer to start with Pi or Codex.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.muted2,
                      height: 1.7,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => openNewSession(context),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('New session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
