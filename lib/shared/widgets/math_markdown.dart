import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/design/tokens.dart';

/// Lightweight Markdown + LaTeX renderer for learning content.
///
/// Supports what lessons, handbook entries and question stems actually use:
/// `#`/`##`/`###` headings, `-`/`*`/`•` bullets, `1.` numbered items, `>`
/// quotes, paragraphs, inline `**bold**`, `*italic*`, `` `code` ``, inline
/// math `$…$` and display math `$$…$$` (CMS-27). Formulas that fail to parse
/// fall back to their source text instead of throwing. Long display formulas
/// scroll horizontally so nothing overflows a 360 dp screen.
class MathMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final bool compact;

  const MathMarkdown(this.data, {super.key, this.style, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final blocks = MarkdownBlock.parse(data);
    final gap = compact ? AppSpacing.xs : AppSpacing.sm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i].kind == BlockKind.heading ? gap * 2 : gap),
          _block(context, blocks[i], base),
        ],
      ],
    );
  }

  Widget _block(BuildContext context, MarkdownBlock b, TextStyle base) {
    final theme = Theme.of(context);
    switch (b.kind) {
      case BlockKind.heading:
        final hs = switch (b.level) {
          1 => theme.textTheme.titleLarge,
          2 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        return _rich(context, b.text, (hs ?? base).copyWith(color: theme.colorScheme.onSurface));
      case BlockKind.bullet:
      case BlockKind.numbered:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: b.kind == BlockKind.numbered ? 28 : 20,
              child: Text(
                b.kind == BlockKind.numbered ? '${b.level}.' : '•',
                style: base.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: _rich(context, b.text, base)),
          ],
        );
      case BlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
          ),
          child: _rich(context, b.text, base.copyWith(color: context.tokens.textSecondary)),
        );
      case BlockKind.math:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Math.tex(
            b.text,
            mathStyle: MathStyle.display,
            textStyle: base.copyWith(color: theme.colorScheme.onSurface),
            onErrorFallback: (_) => Text('\$\$${b.text}\$\$', style: base),
          ),
        );
      case BlockKind.paragraph:
        return _rich(context, b.text, base);
    }
  }

  Widget _rich(BuildContext context, String text, TextStyle style) {
    return Text.rich(
      TextSpan(children: inlineSpans(context, text, style)),
      style: style,
    );
  }

  static final RegExp _inline = RegExp(
    r'(\$[^$\n]+?\$)|(\*\*[^*\n]+?\*\*)|(\*[^*\s][^*\n]*?\*)|(`[^`\n]+`)',
  );

  /// Inline spans for [text]: bold, italic, code and `$math$`.
  static List<InlineSpan> inlineSpans(BuildContext context, String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start < last) continue;
      // `\$` escapes a literal dollar sign.
      if (m.group(1) != null && m.start > 0 && text[m.start - 1] == r'\') continue;
      if (m.start > last) spans.add(TextSpan(text: _unescape(text.substring(last, m.start))));
      final token = m.group(0)!;
      if (m.group(1) != null) {
        final tex = token.substring(1, token.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.text,
            textStyle: style,
            onErrorFallback: (_) => Text(token, style: style),
          ),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: context.tokens.surfaceMuted),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: _unescape(text.substring(last))));
    return spans;
  }

  static String _unescape(String s) => s.replaceAll(r'\$', r'$');
}

enum BlockKind { heading, bullet, numbered, quote, math, paragraph }

/// A parsed Markdown block. Public for tests.
class MarkdownBlock {
  final BlockKind kind;
  final String text;
  final int level; // heading level or list number

  const MarkdownBlock(this.kind, this.text, [this.level = 0]);

  static final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final _bullet = RegExp(r'^[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');

  static List<MarkdownBlock> parse(String source) {
    final out = <MarkdownBlock>[];
    final para = <String>[];
    void flush() {
      if (para.isNotEmpty) {
        out.add(MarkdownBlock(BlockKind.paragraph, para.join('\n')));
        para.clear();
      }
    }

    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (line.startsWith(r'$$')) {
        flush();
        final buf = StringBuffer();
        final rest = line.substring(2);
        if (rest.endsWith(r'$$') && rest.length >= 2) {
          buf.write(rest.substring(0, rest.length - 2));
        } else {
          buf.write(rest);
          while (++i < lines.length) {
            final t = lines[i].trim();
            if (t.endsWith(r'$$')) {
              buf.write('\n${t.substring(0, t.length - 2)}');
              break;
            }
            buf.write('\n$t');
          }
        }
        final tex = buf.toString().trim();
        if (tex.isNotEmpty) out.add(MarkdownBlock(BlockKind.math, tex));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null) {
        flush();
        out.add(MarkdownBlock(BlockKind.heading, h.group(2)!, h.group(1)!.length));
        continue;
      }
      final b = _bullet.firstMatch(line);
      if (b != null) {
        flush();
        out.add(MarkdownBlock(BlockKind.bullet, b.group(1)!));
        continue;
      }
      final n = _numbered.firstMatch(line);
      if (n != null) {
        flush();
        out.add(MarkdownBlock(BlockKind.numbered, n.group(2)!, int.parse(n.group(1)!)));
        continue;
      }
      if (line.startsWith('>')) {
        flush();
        out.add(MarkdownBlock(BlockKind.quote, line.substring(1).trim()));
        continue;
      }
      para.add(line);
    }
    flush();
    return out;
  }
}
