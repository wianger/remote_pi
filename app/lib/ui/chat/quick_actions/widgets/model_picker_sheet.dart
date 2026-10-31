import 'package:app/config/dependencies.dart';
import 'package:app/data/actions/actions_repository.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/chat/quick_actions/viewmodels/quick_actions_viewmodel.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// Opens the model chooser on its own, without the intermediate Quick Actions
/// sheet. The composer's model button uses this so one tap lands directly on
/// the Claude-style model list.
Future<void> showStandaloneModelPicker(BuildContext context) {
  final vm = injector.get<QuickActionsViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  return showModelPickerSheet(
    context,
    vm: vm,
    onError: (message) => messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(fontSize: 12)),
      ),
    ),
  );
}

/// Apple-style model chooser with a single calm list and an optional effort
/// picker, matching the hierarchy used by Claude mobile.
Future<void> showModelPickerSheet(
  BuildContext context, {
  required QuickActionsViewModel vm,
  ValueChanged<String>? onError,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .34),
    isScrollControlled: true,
    showDragHandle: false,
    sheetAnimationStyle: AnimationStyle.noAnimation,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
    ),
    builder: (ctx) => ChangeNotifierProvider<QuickActionsViewModel>.value(
      value: vm,
      child: _ModelPickerBody(onError: onError),
    ),
  );
}

class _ModelPickerBody extends StatefulWidget {
  const _ModelPickerBody({this.onError});

  final ValueChanged<String>? onError;

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  late Future<ModelsCatalogue> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(forceRefresh: false);
  }

  Future<ModelsCatalogue> _load({required bool forceRefresh}) {
    return context.read<QuickActionsViewModel>().loadModels(
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load(forceRefresh: true));
    await _future.catchError((Object _) => const ModelsCatalogue(models: []));
  }

  Future<void> _onPick(WireModel model) async {
    final vm = context.read<QuickActionsViewModel>();
    try {
      await vm.setModel(model);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // The owning quick-actions sheet surfaces action errors; the standalone
      // entry point routes them to a snackbar instead.
      widget.onError?.call('Could not switch model. Try again.');
    }
  }

  Future<void> _showEffortPicker(ThinkingLevel? current) async {
    final vm = context.read<QuickActionsViewModel>();
    final picked = await showModalBottomSheet<ThinkingLevel>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return BayaGlassSurface(
          radius: 32,
          elevated: false,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reasoning effort',
                    style: sheetContext.typo.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: colors.surface.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final level in ThinkingLevel.values)
                          ListTile(
                            title: Text(_effortLabel(level)),
                            trailing: level == current
                                ? Icon(
                                    LucideIcons.check,
                                    size: 19,
                                    color: colors.accent,
                                  )
                                : null,
                            onTap: () => Navigator.of(sheetContext).pop(level),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    try {
      await vm.setThinking(picked);
    } catch (_) {
      widget.onError?.call('Could not change reasoning effort. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuickActionsViewModel>();
    final mq = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * .82),
          child: BayaGlassSurface(
            key: const Key('model-picker-sheet'),
            radius: 38,
            elevated: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                _Header(onRefresh: _refresh),
                Flexible(
                  child: FutureBuilder<ModelsCatalogue>(
                    future: _future,
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const _LoadingState();
                      }
                      if (snap.hasError) {
                        return _ErrorState(
                          message: snap.error is ActionFailure
                              ? (snap.error as ActionFailure).message
                              : 'Failed to load models',
                          onRetry: _refresh,
                        );
                      }
                      final catalogue = snap.data!;
                      if (catalogue.models.isEmpty) return const _EmptyState();
                      final current = vm.currentThinking;
                      final selected = catalogue.current;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                        children: [
                          _ModelList(
                            models: catalogue.models,
                            selected: selected,
                            onPick: _onPick,
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: context.colors.surface.withValues(
                              alpha: .62,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              key: const Key('model-picker-effort'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 5,
                              ),
                              title: const Text('Effort'),
                              subtitle: Text(
                                current == null
                                    ? 'Not reported'
                                    : _effortLabel(current),
                              ),
                              trailing: Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                                color: context.colors.muted,
                              ),
                              onTap: () => _showEffortPicker(current),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _effortLabel(ThinkingLevel level) => switch (level) {
    ThinkingLevel.off => 'Off',
    ThinkingLevel.minimal => 'Minimal',
    ThinkingLevel.low => 'Low',
    ThinkingLevel.medium => 'Medium',
    ThinkingLevel.high => 'High',
    ThinkingLevel.xhigh => 'Extra high',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: BayaGlassSurface(
                radius: 22,
                elevated: false,
                child: SizedBox.square(
                  dimension: 44,
                  child: IconButton(
                    tooltip: 'Close model picker',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, size: 21, color: colors.text),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Select model',
            style: context.typo.sansBody.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              letterSpacing: -.35,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                key: const Key('model-picker-refresh'),
                tooltip: 'Refresh models',
                onPressed: onRefresh,
                icon: Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: colors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({
    required this.models,
    required this.selected,
    required this.onPick,
  });

  final List<WireModel> models;
  final WireModel? selected;
  final ValueChanged<WireModel> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < models.length; index++) ...[
            _ModelTile(
              model: models[index],
              current:
                  selected?.id == models[index].id &&
                  selected?.provider == models[index].provider,
              onTap: () => onPick(models[index]),
            ),
            if (index != models.length - 1)
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: colors.border.withValues(alpha: .72),
              ),
          ],
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.current,
    required this.onTap,
  });

  final WireModel model;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          model.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.sansBody.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (model.reasoning) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Reasoning',
                            style: context.typo.sansBody.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.muted2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(model),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.sansBody.copyWith(
                      fontSize: 12,
                      color: colors.muted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (current) ...[
              const SizedBox(width: 12),
              Icon(LucideIcons.check, size: 20, color: colors.accent),
            ],
          ],
        ),
      ),
    );
  }

  static String _subtitle(WireModel model) {
    final pieces = <String>[
      model.provider,
      if (model.contextWindow > 0)
        '${(model.contextWindow / 1000).round()}k context',
      if (model.vision) 'vision',
    ];
    return pieces.join(' · ');
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          'No models available',
          style: TextStyle(fontSize: 13, color: context.colors.muted),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
