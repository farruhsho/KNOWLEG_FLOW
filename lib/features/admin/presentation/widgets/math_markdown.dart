import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/design/tokens.dart';

/// Minimal Markdown + LaTeX used by question stems, explanations and lessons:
/// `$inline$`, `$$display$$`, `**bold**`, `#`/`##`/`###` headings, `- ` bullets,
/// `\$` for a literal dollar sign.
enum MdSegKind { text, bold, inlineMath, displayMath }

class MdSeg {
  final MdSegKind kind;
  final String value;
  const MdSeg(this.kind, this.value);

  @override
  bool operator ==(Object other) =>
      other is MdSeg && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'MdSeg($kind, "$value")';
}

/// Splits [input] into text / bold / math segments. Unclosed delimiters are
/// kept as literal text so a half-typed formula never breaks the preview.
List<MdSeg> parseMathMarkdown(String input) {
  final out = <MdSeg>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      out.add(MdSeg(MdSegKind.text, buf.toString()));
      buf.clear();
    }
  }

  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (c == r'\' && i + 1 < input.length && input[i + 1] == r'$') {
      buf.write(r'$');
      i += 2;
      continue;
    }
    if (input.startsWith(r'$$', i)) {
      final end = input.indexOf(r'$$', i + 2);
      if (end > i + 2) {
        flush();
        out.add(MdSeg(MdSegKind.displayMath, input.substring(i + 2, end).trim()));
        i = end + 2;
        continue;
      }
    }
    if (c == r'$') {
      var end = i + 1;
      while (end < input.length) {
        if (input[end] == r'$' && input[end - 1] != r'\') break;
        end++;
      }
      if (end < input.length && end > i + 1) {
        flush();
        out.add(MdSeg(MdSegKind.inlineMath, input.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    }
    if (input.startsWith('**', i)) {
      final end = input.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        out.add(MdSeg(MdSegKind.bold, input.substring(i + 2, end)));
        i = end + 2;
        continue;
      }
    }
    buf.write(c);
    i++;
  }
  flush();
  return out;
}

/// Renders [text] with inline/display LaTeX (flutter_math_fork). Long
/// formulas scroll horizontally instead of overflowing on phones.
class MathMarkdownText extends StatelessWidget {
  const MathMarkdownText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final segs = parseMathMarkdown(text);
    final blocks = <Widget>[];
    var line = <InlineSpan>[];
    var lineStyle = base;
    var prefix = '';

    Widget mathError(String tex) => Text(
          '\$$tex\$',
          style: base.copyWith(color: context.tokens.danger),
        );

    void flushLine() {
      if (line.isEmpty && prefix.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Text.rich(TextSpan(
          style: lineStyle,
          children: [if (prefix.isNotEmpty) TextSpan(text: prefix), ...line],
        )),
      ));
      line = <InlineSpan>[];
      lineStyle = base;
      prefix = '';
    }

    void startLine(String raw) {
      final h = RegExp(r'^(#{1,3})\s+').firstMatch(raw);
      if (h != null) {
        final level = h.group(1)!.length;
        lineStyle = (level == 1
                ? theme.textTheme.titleLarge
                : level == 2
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleSmall) ??
            base;
      } else if (raw.startsWith('- ') || raw.startsWith('* ')) {
        prefix = '•  ';
      }
    }

    String stripMarker(String raw) {
      final h = RegExp(r'^(#{1,3})\s+').firstMatch(raw);
      if (h != null) return raw.substring(h.end);
      if (raw.startsWith('- ') || raw.startsWith('* ')) return raw.substring(2);
      return raw;
    }

    var atLineStart = true;
    for (final seg in segs) {
      switch (seg.kind) {
        case MdSegKind.displayMath:
          flushLine();
          blocks.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                seg.value,
                mathStyle: MathStyle.display,
                textStyle: base,
                onErrorFallback: (_) => mathError(seg.value),
              ),
            ),
          ));
          atLineStart = true;
        case MdSegKind.inlineMath:
          line.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              seg.value,
              mathStyle: MathStyle.text,
              textStyle: lineStyle,
              onErrorFallback: (_) => mathError(seg.value),
            ),
          ));
          atLineStart = false;
        case MdSegKind.bold:
          line.add(TextSpan(text: seg.value, style: const TextStyle(fontWeight: FontWeight.w700)));
          atLineStart = false;
        case MdSegKind.text:
          final lines = seg.value.split('\n');
          for (var k = 0; k < lines.length; k++) {
            if (k > 0) {
              flushLine();
              atLineStart = true;
            }
            var piece = lines[k];
            if (atLineStart) {
              startLine(piece);
              piece = stripMarker(piece);
            }
            if (piece.isNotEmpty) {
              line.add(TextSpan(text: piece));
              atLineStart = false;
            }
          }
      }
    }
    flushLine();
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }
}

/// Multi-line editor with a live Markdown/LaTeX preview below it.
class MathTextField extends StatefulWidget {
  const MathTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.minLines = 2,
    this.helper,
    this.showPreview = true,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int minLines;
  final String? helper;
  final bool showPreview;

  @override
  State<MathTextField> createState() => _MathTextFieldState();
}

class _MathTextFieldState extends State<MathTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          minLines: widget.minLines,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(labelText: widget.label, helperText: widget.helper),
          onChanged: widget.onChanged,
        ),
        if (widget.showPreview)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _c,
            builder: (context, v, _) => v.text.contains(r'$') || v.text.contains('**')
                ? Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.tokens.surfaceMuted,
                      borderRadius: AppRadii.smAll,
                    ),
                    child: MathMarkdownText(v.text),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
