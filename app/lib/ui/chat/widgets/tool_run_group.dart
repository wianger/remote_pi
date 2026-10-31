import 'dart:convert';

import 'package:app/domain/session_state.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Collapsed summary for completed tool calls in one user turn. Text segments
/// may separate the calls; the shape still follows the Claude mobile pattern
/// with one quiet row and one sheet containing every action.
class ToolRunGroup extends StatelessWidget {
  const ToolRunGroup({super.key, required this.tools});

  final List<ToolEvent> tools;

  bool _isCommand(ToolEvent tool) {
    final name = tool.tool.toLowerCase();
    return name.contains('command') ||
        name.contains('shell') ||
        name.contains('bash') ||
        name.contains('exec');
  }

  String get _summary {
    final commands = tools.where(_isCommand).length;
    final others = tools.length - commands;
    if (commands > 0 && others > 0) {
      return 'Ran ${commands == 1 ? 'a command' : '$commands commands'}, '
          'used ${others == 1 ? 'a tool' : '$others tools'}';
    }
    if (commands > 0) {
      return 'Ran ${commands == 1 ? 'a command' : '$commands commands'}';
    }
    return 'Used ${others == 1 ? 'a tool' : '$others tools'}';
  }

  String _preview(ToolEvent tool) {
    final args = tool.args;
    if (args is Map) {
      for (final key in const [
        'command',
        'cmd',
        'description',
        'path',
        'file_path',
        'query',
        'prompt',
      ]) {
        final value = args[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    if (args is String && args.trim().isNotEmpty) return args.trim();
    if (tool.error != null && tool.error!.isNotEmpty) return tool.error!;
    return tool.status.name;
  }

  IconData get _icon {
    final name = tools.first.tool.toLowerCase();
    if (_isCommand(tools.first)) return LucideIcons.terminal;
    if (name.contains('message') || name.contains('agent')) {
      return LucideIcons.wrench;
    }
    if (name.contains('read')) return LucideIcons.fileText;
    if (name.contains('search') || name.contains('grep')) {
      return LucideIcons.search;
    }
    return LucideIcons.wrench;
  }

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return BayaGlassSurface(
          radius: 34,
          elevated: false,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
              ),
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
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 42,
                          child: IconButton.filledTonal(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(LucideIcons.x, size: 20),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _summary,
                              style: sheetContext.typo.title.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 42),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Material(
                        color: colors.surface.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: tools.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 48,
                            color: colors.border.withValues(alpha: .7),
                          ),
                          itemBuilder: (_, index) {
                            final tool = tools[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              leading: Icon(
                                _iconFor(tool),
                                size: 19,
                                color: colors.muted2,
                              ),
                              title: Text(_labelFor(tool)),
                              subtitle: Text(
                                _preview(tool),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: sheetContext.typo.sansBody.copyWith(
                                  color: colors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                LucideIcons.chevronRight,
                                size: 17,
                                color: colors.muted,
                              ),
                              onTap: () => _showDetail(sheetContext, tool),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(ToolEvent tool) {
    if (_isCommand(tool)) return LucideIcons.terminal;
    final name = tool.tool.toLowerCase();
    if (name.contains('message') || name.contains('agent')) {
      return LucideIcons.wrench;
    }
    if (name.contains('read')) return LucideIcons.fileText;
    if (name.contains('search') || name.contains('grep')) {
      return LucideIcons.search;
    }
    return LucideIcons.wrench;
  }

  String _labelFor(ToolEvent tool) {
    if (_isCommand(tool)) return 'Ran';
    final name = tool.tool.toLowerCase();
    if (name.contains('message') || name.contains('agent')) {
      return 'Messaged agent';
    }
    if (name.contains('read')) return 'Read file';
    if (name.contains('write')) return 'Wrote file';
    if (name.contains('search') || name.contains('grep')) return 'Searched';
    return tool.tool;
  }

  Future<void> _showDetail(BuildContext context, ToolEvent tool) {
    final args = tool.args is String
        ? tool.args as String
        : const JsonEncoder.withIndent('  ').convert(tool.args);
    final result = tool.result is String
        ? tool.result as String
        : tool.result == null
        ? ''
        : const JsonEncoder.withIndent('  ').convert(tool.result);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return AlertDialog(
          title: Text(_labelFor(tool)),
          content: SingleChildScrollView(
            child: SelectableText(
              [
                args,
                if (result.isNotEmpty) '\n$result',
                if (tool.error != null) '\n${tool.error}',
              ].join('\n'),
              style: dialogContext.typo.monoSmall.copyWith(color: colors.text),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = tools.any((t) => t.status == ToolEventStatus.failed);
    return BayaGlassSurface(
      radius: 18,
      elevated: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
            child: Row(
              children: [
                Icon(
                  failed ? LucideIcons.circleAlert : _icon,
                  size: 19,
                  color: failed ? colors.error : colors.muted2,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _summary,
                    style: context.typo.sansBody.copyWith(
                      color: failed ? colors.error : colors.muted2,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
