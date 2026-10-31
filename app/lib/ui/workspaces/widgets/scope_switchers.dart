import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Devices are a top-level destination, presented as a prominent card and sheet.
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onRename != null)
                                IconButton(
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
                              if (entry.key == selected)
                                Icon(
                                  LucideIcons.check,
                                  size: 18,
                                  color: sheetContext.colors.accent,
                                ),
                            ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.glassEdge),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.selection,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.monitor, size: 22, color: colors.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device',
                  style: context.typo.sansBody.copyWith(
                    fontSize: 11,
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
          const SizedBox(width: 4),
          _DeviceActionButton(
            key: const Key('device-switch'),
            tooltip: 'Switch device',
            icon: LucideIcons.chevronsUpDown,
            onPressed: enabled && (devices.isNotEmpty || onAdd != null)
                ? () => _pick(context)
                : null,
          ),
        ],
      ),
    );
  }
}

class _DeviceActionButton extends StatelessWidget {
  const _DeviceActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 16,
            color: onPressed == null
                ? colors.muted.withValues(alpha: .35)
                : colors.muted2,
          ),
        ),
      ),
    );
  }
}

/// Workspaces are phone-side logical groups presented as a flat row. Sessions
/// inside one group may come from unrelated folders.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({
    super.key,
    required this.workspaces,
    this.labels = const {},
    required this.selected,
    required this.hasDevice,
    required this.onSelected,
    this.onCreate,
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
  final bool Function(String key)? canDelete;
  final Future<bool> Function(String key)? onDelete;

  String _name(String detail) =>
      detail
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      detail;

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<({bool add, String? workspace})>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .38),
      isScrollControlled: true,
      showDragHandle: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .72,
      ),
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return BayaGlassSurface(
          radius: 34,
          elevated: false,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: _SwitcherSheetHeader(
                      title: 'Switch workspace',
                      onClose: () => Navigator.of(sheetContext).pop(),
                      onAdd: enabled && onCreate != null
                          ? () => Navigator.of(
                              sheetContext,
                            ).pop((add: true, workspace: null))
                          : null,
                      addTooltip: 'New workspace',
                      addKey: const Key('workspace-add'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: workspaces.isEmpty
                        ? const _EmptyWorkspaceList()
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: workspaces.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 9),
                            itemBuilder: (_, index) {
                              final entry = workspaces.entries.elementAt(index);
                              final selected = entry.key == this.selected;
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
                                child: Material(
                                  key: ValueKey(
                                    'workspace-choice-${entry.key}',
                                  ),
                                  color: selected
                                      ? colors.selection
                                      : colors.surface.withValues(alpha: .48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    side: BorderSide(
                                      color: selected
                                          ? colors.accent.withValues(alpha: .32)
                                          : colors.border.withValues(alpha: .7),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: () => Navigator.of(
                                      sheetContext,
                                    ).pop((add: false, workspace: entry.key)),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        11,
                                        12,
                                        11,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? colors.accent
                                                  : colors.bg.withValues(
                                                      alpha: .54,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              border: Border.all(
                                                color: selected
                                                    ? colors.accent
                                                    : colors.border.withValues(
                                                        alpha: .75,
                                                      ),
                                              ),
                                            ),
                                            child: Icon(
                                              LucideIcons.layoutDashboard,
                                              size: 19,
                                              color: selected
                                                  ? colors.onAccent
                                                  : colors.muted2,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: sheetContext
                                                      .typo
                                                      .sansBody
                                                      .copyWith(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  entry.value,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: sheetContext
                                                      .typo
                                                      .sansBody
                                                      .copyWith(
                                                        color: colors.muted,
                                                        fontSize: 11.5,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? colors.accent
                                                  : colors.surface.withValues(
                                                      alpha: .7,
                                                    ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              selected
                                                  ? LucideIcons.check
                                                  : LucideIcons.chevronRight,
                                              size: 16,
                                              color: selected
                                                  ? colors.onAccent
                                                  : colors.muted2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
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
    return Material(
      color: colors.surface.withValues(alpha: .50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border.withValues(alpha: .72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('workspace-switch'),
        onTap: canOpen ? () => _pick(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.selection,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  LucideIcons.layoutDashboard,
                  size: 17,
                  color: canOpen ? colors.accent : colors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORKSPACE',
                      style: context.typo.monoSmall.copyWith(
                        color: colors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.sansBody.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.sansBody.copyWith(
                          color: colors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.bg.withValues(alpha: .44),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 15,
                  color: canOpen ? colors.muted2 : colors.muted,
                ),
              ),
            ],
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
