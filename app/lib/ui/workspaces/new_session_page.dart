import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/workspaces/states/new_session_state.dart';
import 'package:app/ui/workspaces/viewmodels/new_session_viewmodel.dart';
import 'package:app/ui/workspaces/widgets/agent_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class NewSessionPage extends StatefulWidget {
  const NewSessionPage({super.key});
  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  final _path = TextEditingController();
  String? _lastPath;
  bool _leaving = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await context.read<NewSessionViewModel>().cancel();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }

  Future<void> _open() async {
    final result = await context.read<NewSessionViewModel>().open();
    if (!mounted || result == null) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewSessionViewModel>();
    final state = vm.state;
    final ready = state is NewSessionReady ? state : null;
    if (ready?.directory?.path != _lastPath) {
      _lastPath = ready?.directory?.path;
      _path.text = _lastPath ?? '';
    }
    final colors = context.colors;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && ready?.opening != true) _cancel();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          leading: IconButton(
            onPressed: ready?.opening == true ? null : _cancel,
            icon: const Icon(LucideIcons.x),
            tooltip: 'Cancel',
          ),
          title: const Text('New session'),
          actions: [
            IconButton(
              tooltip: 'Refresh computers',
              onPressed: ready?.opening == true ? null : vm.load,
              icon: const Icon(LucideIcons.refreshCw, size: 19),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: switch (state) {
                NewSessionLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                NewSessionUnavailable(:final message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: vm.load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
                NewSessionReady() => _content(context, state, vm),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    NewSessionReady state,
    NewSessionViewModel vm,
  ) {
    final colors = context.colors;
    final directory = state.directory;
    final locked = state.loading || state.opening;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COMPUTER',
            style: context.typo.mono.copyWith(
              color: colors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.host.id,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.monitor),
            ),
            items: state.hosts
                .map(
                  (host) => DropdownMenuItem(
                    value: host.id,
                    child: Text(
                      '${host.label}${host.online ? '' : ' · offline'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: locked
                ? null
                : (id) {
                    if (id != null) vm.selectHost(id);
                  },
          ),
          const SizedBox(height: 16),
          AgentPickerField(
            agents: directory?.agents ?? const [],
            selected: directory?.agents.isNotEmpty == true ? state.agent : null,
            computerLabel: state.host.label,
            enabled: !locked && state.host.online,
            onChanged: vm.setAgent,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a folder on your computer. Existing sessions in this folder will be reopened.',
            style: TextStyle(color: colors.muted2, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _path,
            enabled: !locked,
            autocorrect: false,
            enableSuggestions: false,
            style: context.typo.mono.copyWith(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Folder path',
              hintText: 'Absolute path on the computer',
              suffixIcon: IconButton(
                tooltip: 'Go to folder',
                onPressed: locked ? null : () => vm.browse(path: _path.text),
                icon: const Icon(LucideIcons.arrowRight, size: 18),
              ),
            ),
            onSubmitted: (path) => vm.browse(path: path),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Home folder',
                onPressed: locked
                    ? null
                    : () => vm.browse(path: directory?.home),
                icon: const Icon(LucideIcons.house, size: 18),
              ),
              IconButton(
                tooltip: 'Parent folder',
                onPressed: locked || directory?.parent == null
                    ? null
                    : () => vm.browse(path: directory!.parent),
                icon: const Icon(LucideIcons.arrowUp, size: 18),
              ),
              const Spacer(),
              Text(
                'Hidden folders',
                style: TextStyle(color: colors.muted2, fontSize: 12),
              ),
              Switch(
                value: state.showHidden,
                onChanged: locked ? null : (_) => vm.toggleHidden(),
              ),
            ],
          ),
          TextField(
            key: ValueKey(directory?.path),
            enabled: !locked,
            decoration: const InputDecoration(
              hintText: 'Filter folders',
              prefixIcon: Icon(LucideIcons.search, size: 18),
              isDense: true,
            ),
            onChanged: vm.setQuery,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: header),
              if (state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      state.error!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                ),
              if (state.loading || state.opening)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (state.visibleFolders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        state.loading
                            ? 'Reading folders…'
                            : directory == null
                            ? 'Select an online computer to browse folders.'
                            : 'No subfolders',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: state.visibleFolders.length,
                    itemBuilder: (context, index) {
                      final folder = state.visibleFolders[index];
                      return ListTile(
                        leading: Icon(
                          LucideIcons.folder,
                          color: colors.muted2,
                          size: 20,
                        ),
                        title: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.mono.copyWith(fontSize: 13),
                        ),
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          color: colors.muted,
                          size: 16,
                        ),
                        onTap: locked
                            ? null
                            : () => vm.browse(path: folder.path),
                      );
                    },
                  ),
                ),
              if (directory?.truncated == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Showing the first 300 folders. Enter a path to open another folder.',
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: FilledButton.icon(
            onPressed: state.canOpen ? _open : null,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                state.opening
                    ? 'Starting ${state.agent.label}…'
                    : 'Open ${state.agent.label} here',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
