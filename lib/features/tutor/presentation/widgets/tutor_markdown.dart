import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/design/tokens.dart';

// ---------------------------------------------------------------------------
// Parsing — a deliberately small Markdown subset for tutor replies and
// question stems: headings, paragraphs, bullet / numbered lists, fenced
// code, **bold**, *italic*, `code`, and LaTeX in $…$, $$…$$, \(…\), \[…\].
// Anything not understood is rendered as plain text, never dropped.
// ---------------------------------------------------------------------------

@immutable
sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  final int level;
  final String text;
  const MdHeading(this.level, this.text);
}

class MdParagraph extends MdBlock {
  final String text;
  const MdParagraph(this.text);
}

class MdListItem extends MdBlock {
  /// `null` for a bullet, otherwise the marker such as `1.`.
  final String? marker;
  final String text;
  const MdListItem(this.text, {this.marker});
}

class MdCode extends MdBlock {
  final String code;
  const MdCode(this.code);
}

class MdMathBlock extends MdBlock {
  final String tex;
  const MdMathBlock(this.tex);
}

@immutable
sealed class MdInline {
  const MdInline();
}

class MdText extends MdInline {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  const MdText(this.text, {this.bold = false, this.italic = false, this.code = false});
}

class MdInlineMath extends MdInline {
  final String tex;
  const MdInlineMath(this.tex);
}

final _heading = RegExp(r'^(#{1,6})\s+(.+)$');
final _bullet = RegExp(r'^\s*[-*•]\s+(.+)$');
final _ordered = RegExp(r'^\s*(\d{1,3})[.)]\s+(.+)$');

List<MdBlock> parseTutorMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final para = <String>[];

  void flush() {
    if (para.isEmpty) return;
    blocks.add(MdParagraph(para.join('\n')));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final t = line.trim();

    if (t.startsWith('```')) {
      flush();
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      blocks.add(MdCode(buf.join('\n')));
      i++; // closing fence (or EOF)
      continue;
    }

    final mathOpen = t.startsWith(r'$$') ? r'$$' : (t.startsWith(r'\[') ? r'\[' : null);
    if (mathOpen != null) {
      final close = mathOpen == r'$$' ? r'$$' : r'\]';
      final rest = t.substring(2);
      final endHere = rest.indexOf(close);
      if (endHere >= 0) {
        final tail = rest.substring(endHere + 2).trim();
        if (tail.isEmpty) {
          flush();
          blocks.add(MdMathBlock(rest.substring(0, endHere).trim()));
          i++;
          continue;
        }
        // Formula followed by text on the same line: treat as inline text.
      } else {
        // Multi-line display math.
        final buf = <String>[rest];
        var j = i + 1;
        var closed = false;
        while (j < lines.length) {
          final l = lines[j];
          final idx = l.indexOf(close);
          if (idx >= 0) {
            buf.add(l.substring(0, idx));
            closed = true;
            break;
          }
          buf.add(l);
          j++;
        }
        if (closed) {
          flush();
          blocks.add(MdMathBlock(buf.join('\n').trim()));
          i = j + 1;
          continue;
        }
      }
    }

    if (t.isEmpty) {
      flush();
      i++;
      continue;
    }

    final h = _heading.firstMatch(t);
    if (h != null) {
      flush();
      blocks.add(MdHeading(h.group(1)!.length, h.group(2)!.trim()));
      i++;
      continue;
    }

    final o = _ordered.firstMatch(line);
    if (o != null) {
      flush();
      blocks.add(MdListItem(o.group(2)!.trim(), marker: '${o.group(1)}.'));
      i++;
      continue;
    }

    final b = _bullet.firstMatch(line);
    if (b != null) {
      flush();
      blocks.add(MdListItem(b.group(1)!.trim()));
      i++;
      continue;
    }

    para.add(t);
    i++;
  }
  flush();
  return blocks;
}

bool _isSpace(String c) => c.trim().isEmpty;
bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
bool _isWordChar(String c) => RegExp(r'[0-9A-Za-zА-Яа-яЁёҢңӨөҮү]').hasMatch(c);

/// Splits a line of text into styled runs and inline formulas.
List<MdInline> parseInline(String s, {bool bold = false, bool italic = false}) {
  final out = <MdInline>[];
  final buf = StringBuffer();

  void flushText() {
    if (buf.isEmpty) return;
    out.add(MdText(buf.toString(), bold: bold, italic: italic));
    buf.clear();
  }

  var i = 0;
  while (i < s.length) {
    final c = s[i];

    // Escaped dollar / asterisk.
    if (c == r'\' && i + 1 < s.length && (s[i + 1] == r'$' || s[i + 1] == '*')) {
      buf.write(s[i + 1]);
      i += 2;
      continue;
    }

    // \( … \)
    if (s.startsWith(r'\(', i)) {
      final end = s.indexOf(r'\)', i + 2);
      if (end > i + 2) {
        flushText();
        out.add(MdInlineMath(s.substring(i + 2, end).trim()));
        i = end + 2;
        continue;
      }
    }

    // $$ … $$ inside a line
    if (s.startsWith(r'$$', i)) {
      final end = s.indexOf(r'$$', i + 2);
      if (end > i + 2) {
        flushText();
        out.add(MdInlineMath(s.substring(i + 2, end).trim()));
        i = end + 2;
        continue;
      }
    }

    // $ … $ — pandoc rules so prices like "5$ и 10$" stay text: the opening
    // $ must be followed by a non-space, the closing one preceded by a
    // non-space and not followed by a digit.
    if (c == r'$' && i + 1 < s.length && !_isSpace(s[i + 1])) {
      var j = i + 1;
      var found = -1;
      while (j < s.length) {
        if (s[j] == r'$' && s[j - 1] != r'\' && !_isSpace(s[j - 1]) &&
            (j + 1 >= s.length || !_isDigit(s[j + 1]))) {
          found = j;
          break;
        }
        j++;
      }
      if (found > i + 1) {
        flushText();
        out.add(MdInlineMath(s.substring(i + 1, found)));
        i = found + 1;
        continue;
      }
    }

    // **bold**
    if (s.startsWith('**', i)) {
      final end = s.indexOf('**', i + 2);
      if (end > i + 2) {
        flushText();
        out.addAll(parseInline(s.substring(i + 2, end), bold: true, italic: italic));
        i = end + 2;
        continue;
      }
    }

    // `code`
    if (c == '`') {
      final end = s.indexOf('`', i + 1);
      if (end > i + 1) {
        flushText();
        out.add(MdText(s.substring(i + 1, end), bold: bold, italic: italic, code: true));
        i = end + 1;
        continue;
      }
    }

    // *italic* / _italic_ (underscore only at word boundaries: snake_case stays)
    if ((c == '*' || c == '_') &&
        i + 1 < s.length &&
        !_isSpace(s[i + 1]) &&
        (c == '*' || i == 0 || !_isWordChar(s[i - 1]))) {
      var j = i + 1;
      var found = -1;
      while (j < s.length) {
        if (s[j] == c && !_isSpace(s[j - 1]) &&
            (c == '*' || j + 1 >= s.length || !_isWordChar(s[j + 1]))) {
          found = j;
          break;
        }
        j++;
      }
      if (found > i + 1) {
        flushText();
        out.addAll(parseInline(s.substring(i + 1, found), bold: bold, italic: true));
        i = found + 1;
        continue;
      }
    }

    buf.write(c);
    i++;
  }
  flushText();
  return out;
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Renders tutor replies / question text with basic Markdown and LaTeX.
/// A formula that fails to parse falls back to its source text.
class TutorMarkdown extends StatelessWidget {
  const TutorMarkdown(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final blocks = parseTutorMarkdown(text);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        final tight = blocks[i] is MdListItem && blocks[i - 1] is MdListItem;
        children.add(SizedBox(height: tight ? AppSpacing.xs : AppSpacing.sm));
      }
      children.add(_block(context, blocks[i], base));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _block(BuildContext context, MdBlock b, TextStyle base) {
    final theme = Theme.of(context);
    switch (b) {
      case MdHeading():
        final hs = (b.level <= 2 ? theme.textTheme.titleMedium : theme.textTheme.titleSmall) ??
            base.copyWith(fontWeight: FontWeight.w600);
        return Text.rich(TextSpan(children: _spans(context, parseInline(b.text), hs)));
      case MdParagraph():
        return Text.rich(TextSpan(children: _spans(context, parseInline(b.text), base)));
      case MdListItem():
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: b.marker == null ? 18 : 26,
              child: Text(b.marker ?? '•', style: base),
            ),
            Expanded(
              child: Text.rich(TextSpan(children: _spans(context, parseInline(b.text), base))),
            ),
          ],
        );
      case MdCode():
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.tokens.surfaceMuted,
            borderRadius: AppRadii.smAll,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(b.code, style: base.copyWith(fontFamily: 'monospace')),
          ),
        );
      case MdMathBlock():
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            b.tex,
            mathStyle: MathStyle.display,
            textStyle: base,
            onErrorFallback: (_) => Text(b.tex, style: base.copyWith(fontFamily: 'monospace')),
          ),
        );
    }
  }

  List<InlineSpan> _spans(BuildContext context, List<MdInline> parts, TextStyle base) {
    final codeBg = context.tokens.surfaceMuted;
    return [
      for (final p in parts)
        switch (p) {
          MdText() => TextSpan(
              text: p.text,
              style: base.copyWith(
                fontWeight: p.bold ? FontWeight.w700 : null,
                fontStyle: p.italic ? FontStyle.italic : null,
                fontFamily: p.code ? 'monospace' : null,
                backgroundColor: p.code ? codeBg : null,
              ),
            ),
          MdInlineMath() => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  p.tex,
                  mathStyle: MathStyle.text,
                  textStyle: base,
                  onErrorFallback: (_) =>
                      Text(p.tex, style: base.copyWith(fontFamily: 'monospace')),
                ),
              ),
            ),
        },
    ];
  }
}
