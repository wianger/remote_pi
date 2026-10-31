import 'dart:convert';
import 'package:app/domain/session_state.dart';
import 'package:app/protocol/protocol.dart';
import 'package:app/ui/chat/widgets/thinking_block.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Inline tool execution card that appears in the chat flow.
//
// Historically this widget rendered Allow/Deny buttons + a 60s countdown
// assuming the Pi paused execution until the user decided. With the current
// Claude SDK integration the pi-extension emits `tool_request` AFTER the
// SDK has already accepted the tool (`tool_execution_start` fires post
// auto-approval), so the buttons could only blink for a few hundred
// milliseconds before `tool_result` arrived — confusing UX with no real
// gating. Pi cards stay informational. Codex explicitly marks requests
// that are paused for a real decision with `approval_required`.

class ToolRequestCard extends StatefulWidget {
  final ToolEvent tool;
  final void Function(String toolCallId, ApproveDecision decision)? onDecide;

  const ToolRequestCard({super.key, required this.tool, this.onDecide});

  @override
  State<ToolRequestCard> createState() => _ToolRequestCardState();
}

class _ToolRequestCardState extends State<ToolRequestCard> {
  /// Cards start collapsed to a single readable row; tapping one reveals the
  /// command, output and outcome. Real approvals always start open.
  bool _expanded = false;
  bool _outputExpanded = false;
  ToolEvent get tool => widget.tool;
  void Function(String, ApproveDecision)? get onDecide => widget.onDecide;

  bool get _needsApproval =>
      tool.status == ToolEventStatus.pending &&
      tool.args is Map &&
      tool.args['approval_required'] == true;

  /// Errors and real approvals retain emphasis; ordinary activity is quiet.
  Color _statusColor(BuildContext context) {
    final colors = context.colors;
    return switch (tool.status) {
      ToolEventStatus.pending ||
      ToolEventStatus.allowed => _needsApproval ? colors.accent : colors.muted2,
      ToolEventStatus.completed => colors.muted2,
      ToolEventStatus.failed => colors.error,
      ToolEventStatus.denied || ToolEventStatus.expired => colors.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _statusColor(context);
    final name = tool.tool.toLowerCase();
    if (!_needsApproval &&
        (_running || tool.status == ToolEventStatus.completed) &&
        const {'think', 'thinking', 'reasoning'}.contains(name)) {
      final args = tool.args;
      return ThinkingBlock(
        text:
            _formatResult(tool.result) ??
            (args is Map
                ? _stringArg(args, const ['thought', 'thinking', 'text'])
                : ''),
        complete: !_running,
      );
    }
    final output = _formatResult(tool.result);
    final hasOutput = output != null && output.trim().isNotEmpty;
    final longOutput =
        hasOutput &&
        (output.length > 900 || '\n'.allMatches(output).length > 12);
    // Collapsed by default: the row shows what ran, and the command, output and
    // outcome stay one tap away. Real approvals always start open.
    final expanded = _expanded || _needsApproval;
    final preview = _previewText();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: !_needsApproval,
          expanded: expanded,
          child: InkWell(
            key: ValueKey('tool-details-${tool.toolCallId}'),
            borderRadius: BorderRadius.circular(10),
            onTap: _needsApproval
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      _headerIcon,
                      size: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, color),
                        if (!expanded && preview != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typo.monoSmall.copyWith(
                                fontSize: 11.5,
                                color: colors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _buildStatus(context, color),
                  ),
                  if (!_needsApproval) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        expanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        size: 15,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(left: 9, top: 2, bottom: 8),
            padding: const EdgeInsets.only(left: 17),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colors.border, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCodeBlock(context),
                if (hasOutput) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: _outputExpanded ? 420 : 132,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.codeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        output.trim(),
                        style: context.typo.mono.copyWith(
                          fontSize: 12,
                          height: 1.5,
                          color: colors.muted2,
                        ),
                      ),
                    ),
                  ),
                  if (longOutput)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('tool-output-toggle-${tool.toolCallId}'),
                        onPressed: () =>
                            setState(() => _outputExpanded = !_outputExpanded),
                        child: Text(
                          _outputExpanded ? 'Show less' : 'Show full output',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                if (_needsApproval) ...[
                  Text(
                    'The agent is waiting for your approval.',
                    style: TextStyle(color: colors.text, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: onDecide == null
                            ? null
                            : () => onDecide!(
                                tool.toolCallId,
                                ApproveDecision.deny,
                              ),
                        child: const Text('Deny'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: onDecide == null
                            ? null
                            : () => onDecide!(
                                tool.toolCallId,
                                ApproveDecision.allow,
                              ),
                        child: const Text('Allow once'),
                      ),
                    ],
                  ),
                ] else
                  _buildOutcome(context, color),
              ],
            ),
          ),
      ],
    );
  }

  /// One-line, human-readable summary shown while the card is collapsed.
  String? _previewText() {
    if (_needsApproval) return null;
    final args = tool.args;
    if (args is Map) {
      for (final key in const [
        'command',
        'cmd',
        'path',
        'file_path',
        'query',
        'prompt',
      ]) {
        final value = args[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim().replaceAll('\n', ' ');
        }
      }
    }
    if (args is String && args.trim().isNotEmpty) {
      return args.trim().replaceAll('\n', ' ');
    }
    return null;
  }

  IconData get _headerIcon => switch (tool.tool.toLowerCase()) {
    'bash' || 'commandexecution' => LucideIcons.terminal,
    'read' => LucideIcons.fileText,
    'edit' || 'write' || 'apply_patch' || 'filechange' => LucideIcons.filePen,
    'web_search' || 'websearch' => LucideIcons.search,
    final other when other.contains('message') || other.contains('agent') =>
      LucideIcons.send,
    _ => LucideIcons.wrench,
  };
  bool get _running =>
      tool.status == ToolEventStatus.pending ||
      tool.status == ToolEventStatus.allowed;

  String get _activityLabel {
    if (_needsApproval) return 'Waiting for approval';
    final description = tool.args is Map ? tool.args['description'] : null;
    if (description is String && description.trim().isNotEmpty) {
      return description;
    }
    return switch (tool.tool.toLowerCase()) {
      'bash' ||
      'commandexecution' => _running ? 'Running command' : 'Ran command',
      'read' => _running ? 'Reading file' : 'Read file',
      'edit' ||
      'write' ||
      'apply_patch' ||
      'filechange' => _running ? 'Editing files' : 'Edited files',
      'web_search' ||
      'websearch' => _running ? 'Searching the web' : 'Searched the web',
      _ => '${_running ? 'Using' : 'Used'} ${tool.tool}',
    };
  }

  Widget _buildHeader(BuildContext context, Color color) {
    return Text(
      _activityLabel,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.typo.sansBody.copyWith(fontSize: 14, color: color),
    );
  }

  /// Compact right-edge state: spinner while running, a label for terminal
  /// states, and a check once an ordinary call finishes.
  Widget _buildStatus(BuildContext context, Color color) {
    final statusLabel = switch (tool.status) {
      ToolEventStatus.pending ||
      ToolEventStatus.allowed => _needsApproval ? 'Approval' : 'Running',
      ToolEventStatus.completed => 'Done',
      ToolEventStatus.failed => 'Failed',
      ToolEventStatus.denied => 'Denied',
      ToolEventStatus.expired => 'Expired',
    };
    if (_running && !_needsApproval) {
      return SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
      );
    }
    if (tool.status != ToolEventStatus.completed) {
      return Text(
        statusLabel,
        style: context.typo.sansBody.copyWith(fontSize: 11, color: color),
      );
    }
    return Icon(LucideIcons.check, size: 14, color: context.colors.muted);
  }

  Widget _buildCodeBlock(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final content = _buildToolSummary(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.codeBg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (const {
            'bash',
            'commandexecution',
          }.contains(tool.tool.toLowerCase()))
            Text(r'$ ', style: typo.mono.copyWith(color: colors.muted)),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildToolSummary(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final display = _formatToolDisplay(tool.tool, tool.args);
    if (display == null) {
      return SelectableText(
        _formatArgs(tool.tool, tool.args),
        style: typo.mono,
      );
    }

    return Text.rich(
      TextSpan(
        style: typo.mono,
        children: [
          TextSpan(text: display.command),
          for (final line in display.lines) ...[
            const TextSpan(text: '\n'),
            TextSpan(
              text: line.text,
              style: TextStyle(color: line.color(colors)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutcome(BuildContext context, Color color) {
    final text = switch (tool.status) {
      ToolEventStatus.pending || ToolEventStatus.allowed => 'Running…',
      ToolEventStatus.completed => 'Done',
      ToolEventStatus.failed => tool.error ?? 'Tool failed',
      ToolEventStatus.denied => tool.error ?? 'Request denied',
      ToolEventStatus.expired => 'Request expired',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          tool.status == ToolEventStatus.completed
              ? LucideIcons.check
              : _running
              ? LucideIcons.ellipsis
              : LucideIcons.circleAlert,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: context.typo.sansBody.copyWith(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }

  static String? _formatResult(dynamic result) {
    if (result == null) return null;
    if (result is String) return result;
    if (result is Map && result['content'] is List) {
      return (result['content'] as List)
          .whereType<Map>()
          .where((entry) => entry['text'] is String)
          .map((entry) => entry['text'] as String)
          .join('\n');
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(result);
    } catch (_) {
      return result.toString();
    }
  }

  static String _formatArgs(String tool, dynamic args) {
    if (args == null) return '';
    final normalizedTool = tool.toLowerCase();
    if (args is Map) {
      return switch (normalizedTool) {
        'bash' || 'commandexecution' => (args['command'] as String?) ?? '',
        'edit' || 'write' =>
          '$normalizedTool ${_stringArg(args, const ['file_path', 'path'])}',
        _ => args.entries.map((e) => '${e.key}=${e.value}').join(' '),
      };
    }
    return args.toString();
  }

  static _ToolDisplay? _formatToolDisplay(String tool, dynamic args) {
    if (args is! Map) return null;
    return switch (tool.toLowerCase()) {
      'edit' => _formatEditDisplay(args),
      _ => null,
    };
  }

  static _ToolDisplay? _formatEditDisplay(Map args) {
    final filePath = _stringArg(args, const ['file_path', 'path']);
    final lines = <_DiffLine>[];
    final hunks = args['hunks'];
    if (hunks is! Iterable) return null;

    for (final hunk in hunks) {
      if (hunk is! Map || hunk['lines'] is! Iterable) continue;
      if (lines.isNotEmpty) lines.add(_DiffLine.context('      ...'));
      for (final rawLine in hunk['lines'] as Iterable) {
        if (rawLine is! Map) continue;
        final text = _lineText(rawLine);
        switch (rawLine['kind']) {
          case 'context':
            lines.add(_DiffLine.context(text));
          case 'remove':
            lines.add(_DiffLine.removed(text));
          case 'add':
            lines.add(_DiffLine.added(text));
          case 'ellipsis':
            lines.add(_DiffLine.context('      ...'));
        }
      }
    }

    if (lines.isEmpty) return null;
    return _ToolDisplay(command: 'edit $filePath', lines: lines);
  }

  static String _lineText(Map rawLine) {
    final sign = switch (rawLine['kind']) {
      'remove' => '-',
      'add' => '+',
      _ => ' ',
    };
    final lineNumber = rawLine['oldLine'] ?? rawLine['newLine'];
    final number = lineNumber is int ? lineNumber.toString().padLeft(3) : '   ';
    return '$sign $number ${rawLine['text'] ?? ''}';
  }

  static String _stringArg(Map args, List<String> keys) {
    for (final key in keys) {
      final value = args[key];
      if (value is String) return value;
    }
    return '';
  }
}

class _ToolDisplay {
  final String command;
  final List<_DiffLine> lines;

  const _ToolDisplay({required this.command, required this.lines});
}

class _DiffLine {
  final String text;
  final Color Function(AppColors colors) color;

  const _DiffLine._(this.text, this.color);

  factory _DiffLine.removed(String text) =>
      _DiffLine._(text, (colors) => colors.error);

  factory _DiffLine.added(String text) =>
      _DiffLine._(text, (colors) => colors.success);

  factory _DiffLine.context(String text) =>
      _DiffLine._(text, (colors) => colors.text);
}
