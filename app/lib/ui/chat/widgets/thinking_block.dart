import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Quiet disclosure for agent-provided thinking; it never invents content.
class ThinkingBlock extends StatefulWidget {
  const ThinkingBlock({super.key, required this.text, required this.complete});
  final String text;
  final bool complete;

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canExpand = widget.text.trim().isNotEmpty;
    final expanded = _expanded && canExpand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: canExpand,
          expanded: canExpand ? expanded : null,
          child: InkWell(
            key: const ValueKey('thinking-disclosure'),
            borderRadius: BorderRadius.circular(8),
            onTap: canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                children: [
                  if (widget.complete)
                    Icon(LucideIcons.brain, size: 16, color: colors.muted)
                  else
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.muted,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.complete ? 'Thought process' : 'Thinking…',
                      style: context.typo.sansBody.copyWith(
                        fontSize: 14,
                        color: colors.muted2,
                      ),
                    ),
                  ),
                  if (canExpand)
                    Icon(
                      expanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 15,
                      color: colors.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(left: 7, top: 3, bottom: 6),
            padding: const EdgeInsets.only(left: 13),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colors.border.withValues(alpha: .82),
                  width: .8,
                ),
              ),
            ),
            child: SelectableText(
              widget.text,
              style: context.typo.sansBody.copyWith(
                fontSize: 14,
                height: 1.6,
                color: colors.muted2,
              ),
            ),
          ),
      ],
    );
  }
}
