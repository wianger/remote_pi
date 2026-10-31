import 'dart:async';

import 'package:app/ui/core/themes/themes.dart';
import 'package:app/ui/core/widgets/baya_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plan/32b — renders the agent's Markdown reply (GFM + code) themed to the
/// app's dark/mono look. Links open in the system browser (url_launcher);
/// code blocks get a copy button. Tolerant of partial markdown so it can also
/// drive the live streaming bubble.
class AgentMarkdown extends StatelessWidget {
  const AgentMarkdown(this.data, {super.key, this.selectable = false});

  final String data;

  /// Wrap in a [SelectionArea] so prose/code can be selected + copied. Off for
  /// the streaming bubble (content changes every frame).
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final base = typo.reading.copyWith(
      fontSize: typo.reading.fontSize ?? 16,
      height: 1.5,
      letterSpacing: -0.05,
    );
    // Keep the reading face for prose while matching Apple's compact, calm
    // transcript rhythm. Headings are deliberately restrained on a phone.
    final mdTheme = GptMarkdownThemeData(
      brightness: Theme.of(context).brightness,
      highlightColor: colors.codeBg,
      linkColor: colors.accent,
      linkHoverColor: colors.accent,
      hrLineColor: colors.border,
      hrLineThickness: .6,
      hrLinePadding: const EdgeInsets.symmetric(vertical: 10),
      autoAddDividerLineAfterH1: false,
      h1: base.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      h2: base.copyWith(
        fontSize: 18.5,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      h3: base.copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h4: base.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      h5: base.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h6: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: colors.muted2,
      ),
    );
    final markdown = GptMarkdown(
      data,
      style: base,
      onLinkTap: (url, _) => _openLink(context, url),
      // Inline `code` — subtle highlight, keeps the baseline.
      highlightBuilder: (context, text, style) => Text(
        text,
        style: typo.mono.copyWith(
          fontSize: 13,
          color: colors.highlight,
          backgroundColor: colors.codeBg,
        ),
      ),
      // Fenced ``` blocks — dark card + copy button.
      codeBuilder: (context, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      // The package defaults to generous list indents. Apple's transcript
      // style keeps bullets compact and aligns their text with the prose.
      unOrderedListBuilder: (context, child, config) => UnorderedListView(
        spacing: 5,
        padding: 8,
        bulletSize: 4,
        bulletColor: colors.muted2,
        child: child,
      ),
      orderedListBuilder: (context, no, child, config) => OrderedListView(
        no: no,
        spacing: 8,
        padding: 4,
        style: base.copyWith(fontSize: 14.5, color: colors.muted2),
        child: child,
      ),
    );
    final themed = GptMarkdownTheme(gptThemeData: mdTheme, child: markdown);
    return selectable ? SelectionArea(child: themed) : themed;
  }

  static Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !context.mounted) return;
      await showBayaNotice(
        context,
        title: 'Could not open the link',
        message: url,
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBayaNotice(
        context,
        title: 'Could not open the link',
        message: url,
      );
    }
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.codeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 10,
                      color: colors.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _CopyButton(code: code),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              code,
              style: typo.mono.copyWith(color: colors.text, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      key: const Key('code-copy'),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 15,
      splashRadius: 16,
      tooltip: 'Copy code',
      onPressed: _copy,
      icon: Icon(
        _copied ? LucideIcons.check : LucideIcons.copy,
        color: _copied ? colors.success : colors.muted,
      ),
    );
  }
}
