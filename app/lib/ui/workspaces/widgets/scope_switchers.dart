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
    this.onRenameSelected,
    this.onDeleteSelected,
  });

  final Map<String, String> devices;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final VoidCallback? onRenameSelected;
  final VoidCallback? onDeleteSelected;

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Switch device',
                        style: sheetContext.typo.title,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close device picker',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in devices.entries)
                      ListTile(
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
                        trailing: entry.key == selected
                            ? Icon(
                                LucideIcons.check,
                                size: 18,
                                color: sheetContext.colors.accent,
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, entry.key),
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
    onSelected(choice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasSelection = selected != null && devices.containsKey(selected);
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
            onPressed: enabled && devices.isNotEmpty
                ? () => _pick(context)
                : null,
          ),
          _DeviceActionButton(
            key: const Key('device-rename'),
            tooltip: 'Rename device',
            icon: LucideIcons.pencil,
            onPressed: enabled && hasSelection ? onRenameSelected : null,
          ),
          _DeviceActionButton(
            key: const Key('device-delete'),
            tooltip: 'Delete device',
            icon: LucideIcons.trash2,
            danger: true,
            onPressed: enabled && hasSelection ? onDeleteSelected : null,
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
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

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
                : danger
                ? colors.error
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
    this.enabled = true,
  });

  final Map<String, String> workspaces;
  final Map<String, String> labels;
  final String? selected;
  final bool hasDevice;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCreate;

  String _name(String detail) =>
      detail
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      detail;

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'Switch workspace',
                          style: sheetContext.typo.title.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Close workspace picker',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: Icon(
                              LucideIcons.x,
                              size: 20,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Material(
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
                          final entry = workspaces.entries.elementAt(index);
                          final selected = entry.key == this.selected;
                          final label = labels[entry.key] ?? _name(entry.value);
                          return ListTile(
                            key: ValueKey('workspace-choice-${entry.key}'),
                            selected: selected,
                            selectedTileColor: colors.selection,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            leading: Icon(
                              LucideIcons.layoutDashboard,
                              size: 20,
                              color: selected ? colors.accent : colors.muted2,
                            ),
                            title: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sheetContext.typo.sansBody.copyWith(
                                fontSize: 16,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              entry.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sheetContext.typo.sansBody.copyWith(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    LucideIcons.check,
                                    size: 19,
                                    color: colors.accent,
                                  )
                                : null,
                            onTap: () =>
                                Navigator.of(sheetContext).pop(entry.key),
                          );
                        },
                      ),
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
    onSelected(choice);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = workspaces[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            'Workspace',
            style: context.typo.sansBody.copyWith(
              fontSize: 12,
              color: colors.muted,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('workspace-switch'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: enabled && workspaces.isNotEmpty
                      ? () => _pick(context)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.layoutDashboard,
                          size: 19,
                          color: colors.muted2,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail == null
                                    ? hasDevice
                                          ? 'No workspaces yet'
                                          : 'Choose a device first'
                                    : labels[selected] ?? _name(detail),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.typo.sansBody.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (detail != null)
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typo.sansBody.copyWith(
                                    color: colors.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: colors.muted2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onCreate != null)
              IconButton(
                key: const Key('workspace-create'),
                tooltip: 'New workspace',
                onPressed: enabled ? onCreate : null,
                icon: Icon(
                  LucideIcons.folderPlus,
                  size: 18,
                  color: colors.accent,
                ),
              ),
          ],
        ),
        Divider(height: 1, color: colors.border.withValues(alpha: .65)),
      ],
    );
  }
}
