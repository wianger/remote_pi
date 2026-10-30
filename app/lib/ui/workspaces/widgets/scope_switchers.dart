import 'package:app/ui/core/themes/themes.dart';
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
  });

  final Map<String, String> devices;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool enabled;

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
    return Material(
      color: colors.inputFill.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled && devices.isNotEmpty ? () => _pick(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device',
                      style: context.typo.sansBody.copyWith(
                        fontSize: 12,
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
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronsUpDown, size: 17, color: colors.muted2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workspaces are directories within the device, presented as a flat path row.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({
    super.key,
    required this.workspaces,
    required this.selected,
    required this.hasDevice,
    required this.onSelected,
    this.enabled = true,
  });

  final Map<String, String> workspaces;
  final String? selected;
  final bool hasDevice;
  final bool enabled;
  final ValueChanged<String> onSelected;

  String _name(String path) =>
      path
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      path;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final path = workspaces[selected];
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
        PopupMenuButton<String>(
          tooltip: 'Switch workspace',
          enabled: enabled && workspaces.isNotEmpty,
          position: PopupMenuPosition.under,
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final entry in workspaces.entries)
              PopupMenuItem(
                value: entry.key,
                height: 68,
                child: Row(
                  children: [
                    Icon(LucideIcons.folder, size: 18, color: colors.muted2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _name(entry.value),
                            style: context.typo.sansBody.copyWith(fontSize: 14),
                          ),
                          Text(
                            entry.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.monoSmall,
                          ),
                        ],
                      ),
                    ),
                    if (entry.key == selected) ...[
                      const SizedBox(width: 8),
                      Icon(LucideIcons.check, size: 16, color: colors.accent),
                    ],
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(LucideIcons.folderOpen, size: 19, color: colors.muted2),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path == null
                            ? hasDevice
                                  ? 'No workspaces yet'
                                  : 'Choose a device first'
                            : _name(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.sansBody.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (path != null)
                        Tooltip(
                          message: path,
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.monoSmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronDown, size: 16, color: colors.muted2),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.border.withValues(alpha: .65)),
      ],
    );
  }
}
