import 'package:flutter/foundation.dart';

/// Minimal Markdown-ish markup used in question stems, options, passages and
/// explanations:
///
/// * `$...$` inline LaTeX, `$$...$$` display LaTeX, `\$` a literal dollar;
/// * `**bold**`, `*italic*`;
/// * lines starting with `- ` or `• ` are bullet items;
/// * consecutive lines starting with `|` form a table (`|---|` separator
///   after the first row makes it a header row);
/// * a line `![alt](url)` is an image;
/// * blank lines separate paragraphs.
///
/// Parsing never throws: anything it does not recognise stays plain text.
sealed class StemBlock {
  const StemBlock();
}

class ParagraphBlock extends StemBlock {
  final List<InlineSegment> segments;
  const ParagraphBlock(this.segments);
}

class DisplayMathBlock extends StemBlock {
  final String tex;
  const DisplayMathBlock(this.tex);
}

class BulletListBlock extends StemBlock {
  final List<List<InlineSegment>> items;
  const BulletListBlock(this.items);
}

class TableBlock extends StemBlock {
  final List<String> headers;
  final List<List<String>> rows;
  const TableBlock({required this.headers, required this.rows});
}

class ImageBlock extends StemBlock {
  final String url;
  final String alt;
  const ImageBlock({required this.url, this.alt = ''});
}

@immutable
class InlineSegment {
  final String text;
  final bool isMath;
  final bool bold;
  final bool italic;

  const InlineSegment.text(this.text, {this.bold = false, this.italic = false})
      : isMath = false;
  const InlineSegment.math(this.text)
      : isMath = true,
        bold = false,
        italic = false;

  @override
  bool operator ==(Object other) =>
      other is InlineSegment &&
      other.text == text &&
      other.isMath == isMath &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(text, isMath, bold, italic);

  @override
  String toString() => isMath ? 'math($text)' : 'text($text${bold ? ',b' : ''}${italic ? ',i' : ''})';
}

abstract final class StemMarkup {
  static final _image = RegExp(r'^!\[([^\]]*)\]\(([^)\s]+)\)$');
  static final _tableSeparator = RegExp(r'^\|?[\s:|-]+\|?$');

  static List<StemBlock> parse(String source) {
    final text = source.replaceAll('\r\n', '\n');
    final blocks = <StemBlock>[];
    var cursor = 0;
    while (cursor < text.length) {
      final open = _indexOfUnescaped(text, r'$$', cursor);
      if (open < 0) {
        _parseTextBlocks(text.substring(cursor), blocks);
        break;
      }
      final close = _indexOfUnescaped(text, r'$$', open + 2);
      if (close < 0) {
        _parseTextBlocks(text.substring(cursor), blocks);
        break;
      }
      _parseTextBlocks(text.substring(cursor, open), blocks);
      final tex = text.substring(open + 2, close).trim();
      if (tex.isNotEmpty) blocks.add(DisplayMathBlock(tex));
      cursor = close + 2;
    }
    return blocks;
  }

  static int _indexOfUnescaped(String s, String pattern, int from) {
    var i = s.indexOf(pattern, from);
    while (i > 0 && s[i - 1] == r'\') {
      i = s.indexOf(pattern, i + 1);
    }
    return i;
  }

  static void _parseTextBlocks(String chunk, List<StemBlock> out) {
    final lines = chunk.split('\n');
    final paragraph = <String>[];
    final bullets = <List<InlineSegment>>[];
    final tableLines = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = paragraph.join('\n').trim();
      paragraph.clear();
      if (joined.isNotEmpty) out.add(ParagraphBlock(parseInline(joined)));
    }

    void flushBullets() {
      if (bullets.isEmpty) return;
      out.add(BulletListBlock(List.of(bullets)));
      bullets.clear();
    }

    void flushTable() {
      if (tableLines.isEmpty) return;
      out.add(_table(tableLines));
      tableLines.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('|')) {
        flushParagraph();
        flushBullets();
        tableLines.add(trimmed);
        continue;
      }
      flushTable();
      if (trimmed.isEmpty) {
        flushParagraph();
        flushBullets();
        continue;
      }
      final img = _image.firstMatch(trimmed);
      if (img != null) {
        flushParagraph();
        flushBullets();
        out.add(ImageBlock(url: img.group(2)!, alt: img.group(1) ?? ''));
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        flushParagraph();
        bullets.add(parseInline(trimmed.substring(2).trim()));
        continue;
      }
      flushBullets();
      paragraph.add(line);
    }
    flushParagraph();
    flushBullets();
    flushTable();
  }

  static List<String> _cells(String line) {
    var l = line.trim();
    if (l.startsWith('|')) l = l.substring(1);
    if (l.endsWith('|')) l = l.substring(0, l.length - 1);
    return l.split('|').map((c) => c.trim()).toList();
  }

  static TableBlock _table(List<String> lines) {
    final hasHeader = lines.length > 1 && _tableSeparator.hasMatch(lines[1]) &&
        lines[1].contains('-');
    final rows = <List<String>>[];
    for (var i = 0; i < lines.length; i++) {
      if (hasHeader && i == 1) continue;
      if (!hasHeader && _tableSeparator.hasMatch(lines[i]) && lines[i].contains('-')) {
        continue;
      }
      rows.add(_cells(lines[i]));
    }
    if (hasHeader && rows.isNotEmpty) {
      return TableBlock(headers: rows.first, rows: rows.sublist(1));
    }
    return TableBlock(headers: const [], rows: rows);
  }

  /// Splits one paragraph into text / math segments.
  static List<InlineSegment> parseInline(String s) {
    final out = <InlineSegment>[];
    final buf = StringBuffer();
    var bold = false;
    var italic = false;

    void flush() {
      if (buf.isEmpty) return;
      out.add(InlineSegment.text(buf.toString(), bold: bold, italic: italic));
      buf.clear();
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length && s[i + 1] == r'$') {
        buf.write(r'$');
        i += 2;
        continue;
      }
      if (c == r'$') {
        final end = _closingDollar(s, i + 1);
        if (end > i + 1) {
          flush();
          out.add(InlineSegment.math(s.substring(i + 1, end).trim()));
          i = end + 1;
          continue;
        }
        buf.write(c);
        i++;
        continue;
      }
      if (c == '*' && i + 1 < s.length && s[i + 1] == '*') {
        if (bold || s.indexOf('**', i + 2) > i + 2) {
          flush();
          bold = !bold;
          i += 2;
          continue;
        }
      } else if (c == '*') {
        if (italic) {
          flush();
          italic = false;
          i++;
          continue;
        }
        final close = s.indexOf('*', i + 1);
        if (close > i + 1 &&
            s[i + 1] != ' ' &&
            s[close - 1] != ' ' &&
            (close + 1 >= s.length || s[close + 1] != '*')) {
          flush();
          italic = true;
          i++;
          continue;
        }
      }
      buf.write(c);
      i++;
    }
    flush();
    return out;
  }

  /// Index of the `$` closing inline math opened before [from]; -1 when it
  /// is not closed on the same line.
  static int _closingDollar(String s, int from) {
    for (var j = from; j < s.length; j++) {
      final c = s[j];
      if (c == '\n') return -1;
      if (c == r'\' && j + 1 < s.length) {
        j++;
        continue;
      }
      if (c == r'$') return j;
    }
    return -1;
  }

  /// Plain-text rendering (LaTeX left as source) for semantics labels.
  static String plain(String source) => parse(source).map((b) => switch (b) {
        ParagraphBlock(:final segments) => segments.map((s) => s.text).join(),
        DisplayMathBlock(:final tex) => tex,
        BulletListBlock(:final items) =>
          items.map((i) => i.map((s) => s.text).join()).join('\n'),
        TableBlock(:final headers, :final rows) =>
          [headers, ...rows].map((r) => r.join(' ')).join('\n'),
        ImageBlock(:final alt) => alt,
      }).join('\n');
}
