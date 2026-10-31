import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Devices are a top-level destination, presented as a prominent card and
/// sheet. The whole card is tappable so switching never depends on hitting a
/// small trailing icon.
class DeviceSwitcher extends StatelessWidget {
  const DeviceSwitcher({
    super.key,
    required this.devices,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.onAdd,
    this.onRename,
    this.onDelete,
  });

  final Map<String, String> devices;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final VoidCallback? onAdd;
  final Future<bool> Function(String epk)? onRename;
  final Future<bool> Function(String epk)? onDelete;

  bool get _canOpen => enabled && (devices.isNotEmpty || onAdd != null);

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<({bool add, String? device})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _SwitcherSheetHeader(
                  title: 'Switch device',
                  onClose: () => Navigator.pop(sheetContext),
                  onAdd: enabled && onAdd != null
                      ? () => Navigator.pop(sheetContext, (
                          add: true,
                          device: null,
                        ))
                      : null,
                  addTooltip: 'Pair another computer',
                  addKey: const Key('device-add'),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in devices.entries)
                      Dismissible(
                        key: ValueKey('device-row-${entry.key}'),
                        direction: enabled && onDelete != null
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        confirmDismiss: (_) => onDelete!(entry.key),
                        onDismissed: (_) {
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        background: const _SwipeDeleteBackground(),
                        child: ListTile(
                          selected: entry.key == selected,
                          selectedTileColor: sheetContext.colors.selection,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          leading: Icon(
                            LucideIcons.monitor,
                            color: sheetContext.colors.muted2,
                          ),
                          title: Text(entry.value),
                          trailing: onRename == null
                              ? null
                              : IconButton(
                                  key: ValueKey('device-rename-${entry.key}'),
                                  tooltip: 'Rename device',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: enabled
                                      ? () async {
                                          final renamed = await onRename!(
                                            entry.key,
                                          );
                                          if (renamed && sheetContext.mounted) {
                                            Navigator.pop(sheetContext);
                                          }
                                        }
                                      : null,
                                  icon: Icon(
                                    LucideIcons.pencil,
                                    size: 17,
                                    color: sheetContext.colors.muted2,
                                  ),
                                ),
                          onTap: () => Navigator.pop(sheetContext, (
                            add: false,
                            device: entry.key,
                          )),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice.add) {
      onAdd?.call();
      return;
    }
    if (choice.device case final device?) onSelected(device);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: .58),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.glassEdge),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('device-switch'),
        onTap: _canOpen ? () => _pick(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.selection,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.monitor,
                  size: 22,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEVICE',
                      style: context.typo.monoSmall.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      devices[selected] ?? 'Pair a device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.sansBody.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: _canOpen ? colors.muted2 : colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workspaces are phone-side logical groups. Sessions inside one group may
/// come from unrelated folders, so this is a lightweight nested control under
/// the device card — deliberately quieter than [DeviceSwitcher] so the two are
/// easy to tell apart in the sidebar.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({
    super.key,
    required this.workspaces,
    this.labels = const {},
    required this.selected,
    required this.hasDevice,
    required this.onSelected,
    this.onCreate,
    this.onRename,
    this.canDelete,
    this.onDelete,
    this.enabled = true,
  });

  final Map<String, String> workspaces;
  final Map<String, String> labels;
  final String? selected;
  final bool hasDevice;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCreate;
  final Future<bool> Function(String key, String name)? onRename;
  final bool Function(String key)? canDelete;
  final Future<bool> Function(String key)? onDelete;

  String _name(String detail) =>
      detail
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      detail;

  Future<void> _pick(BuildContext context) async {
    final choice =
        await showModalBottomSheet<
          ({bool add, String? workspace, String? rename})
        >(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          builder: (sheetContext) {
            final colors = sheetContext.colors;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _SwitcherSheetHeader(
                        title: 'Switch workspace',
                        onClose: () => Navigator.of(sheetContext).pop(),
                        onAdd: enabled && onCreate != null
                            ? () => Navigator.of(
                                sheetContext,
                              ).pop((add: true, workspace: null, rename: null))
                            : null,
                        addTooltip: 'New workspace',
                        addKey: const Key('workspace-add'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: workspaces.isEmpty
                          ? const _EmptyWorkspaceList()
                          : Material(
                              color: colors.surface.withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(26),
                              clipBehavior: Clip.antiAlias,
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: workspaces.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  indent: 58,
                                  color: colors.border.withValues(alpha: .7),
                                ),
                                itemBuilder: (_, index) {
                                  final entry = workspaces.entries.elementAt(
                                    index,
                                  );
                                  final isSelected = entry.key == selected;
                                  final label =
                                      labels[entry.key] ?? _name(entry.value);
                                  final deletable =
                                      enabled &&
                                      onDelete != null &&
                                      (canDelete?.call(entry.key) ?? true);
                                  return Dismissible(
                                    key: ValueKey('workspace-row-${entry.key}'),
                                    direction: deletable
                                        ? DismissDirection.endToStart
                                        : DismissDirection.none,
                                    confirmDismiss: (_) => onDelete!(entry.key),
                                    onDismissed: (_) {
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                                    background: const _SwipeDeleteBackground(),
                                    child: ListTile(
                                      key: ValueKey(
                                        'workspace-choice-${entry.key}',
                                      ),
                                      selected: isSelected,
                                      selectedTileColor: colors.selection,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 7,
                                          ),
                                      leading: Icon(
                                        LucideIcons.layoutDashboard,
                                        size: 20,
                                        color: isSelected
                                            ? colors.accent
                                            : colors.muted2,
                                      ),
                                      title: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: sheetContext.typo.sansBody
                                            .copyWith(
                                              fontSize: 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                      ),
                                      subtitle: Text(
                                        entry.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: sheetContext.typo.sansBody
                                            .copyWith(
                                              color: colors.muted,
                                              fontSize: 12,
                                            ),
                                      ),
                                      trailing: enabled && onRename != null
                                          ? IconButton(
                                              key: ValueKey(
                                                'workspace-rename-${entry.key}',
                                              ),
                                              tooltip: 'Rename workspace',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  Navigator.of(
                                                    sheetContext,
                                                  ).pop((
                                                    add: false,
                                                    workspace: null,
                                                    rename: entry.key,
                                                  )),
                                              icon: Icon(
                                                LucideIcons.pencil,
                                                size: 17,
                                                color: colors.muted2,
                                              ),
                                            )
                                          : null,
                                      onTap: () =>
                                          Navigator.of(sheetContext).pop((
                                            add: false,
                                            workspace: entry.key,
                                            rename: null,
                                          )),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    if (!context.mounted || choice == null) return;
    if (choice.add) {
      onCreate?.call();
      return;
    }
    if (choice.rename case final key?) {
      final label = labels[key] ?? _name(workspaces[key] ?? key);
      await onRename?.call(key, label);
      return;
    }
    if (choice.workspace case final workspace?) onSelected(workspace);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = workspaces[selected];
    final title = detail == null
        ? hasDevice
              ? 'No workspaces yet'
              : 'Choose a device first'
        : labels[selected] ?? _name(detail);
    final canOpen = enabled && hasDevice;
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('workspace-switch'),
          borderRadius: BorderRadius.circular(18),
          onTap: canOpen ? () => _pick(context) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
            child: Row(
              children: [
                Icon(
                  LucideIcons.layoutDashboard,
                  size: 16,
                  color: canOpen ? colors.muted2 : colors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workspace',
                        style: context.typo.sansBody.copyWith(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.sansBody.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronDown,
                  size: 15,
                  color: canOpen ? colors.muted2 : colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkspaceList extends StatelessWidget {
  const _EmptyWorkspaceList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: .65)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.layoutDashboard, size: 24, color: colors.muted2),
          const SizedBox(height: 10),
          Text(
            'No workspaces on this device',
            style: context.typo.sansBody.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use + to create one.',
            style: context.typo.sansBody.copyWith(
              color: colors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitcherSheetHeader extends StatelessWidget {
  const _SwitcherSheetHeader({
    required this.title,
    required this.onClose,
    required this.onAdd,
    required this.addTooltip,
    required this.addKey,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onAdd;
  final String addTooltip;
  final Key addKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: context.typo.title.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Close switcher',
              onPressed: onClose,
              icon: Icon(LucideIcons.x, size: 20, color: colors.text),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: colors.selection,
              shape: const CircleBorder(),
              child: IconButton(
                key: addKey,
                tooltip: addTooltip,
                onPressed: onAdd,
                icon: Icon(
                  LucideIcons.plus,
                  size: 19,
                  color: onAdd == null
                      ? colors.muted.withValues(alpha: .35)
                      : colors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trash2, size: 18, color: colors.error),
          const SizedBox(width: 7),
          Text(
            'Delete',
            style: context.typo.sansBody.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
