import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/stem_markup.dart';

void main() {
  test('inline math, bold and escaped dollars', () {
    final segs = StemMarkup.parseInline(r'Цена **5 \$**, найдите $x^2+1$ и $y$');
    expect(segs, [
      const InlineSegment.text('Цена '),
      const InlineSegment.text(r'5 $', bold: true),
      const InlineSegment.text(', найдите '),
      const InlineSegment.math('x^2+1'),
      const InlineSegment.text(' и '),
      const InlineSegment.math('y'),
    ]);
  });

  test('unclosed dollar stays text; blanks with underscores are untouched', () {
    expect(StemMarkup.parseInline(r'Стоит $5 за ____ штук'),
        [const InlineSegment.text(r'Стоит $5 за ____ штук')]);
  });

  test('blocks: paragraph, display math, bullets, table, image', () {
    final blocks = StemMarkup.parse('Первый абзац\n\n'
        r'$$\frac{a}{b}$$'
        '\n- пункт 1\n- пункт 2\n'
        '| x | y |\n|---|---|\n| 1 | 2 |\n'
        '![рисунок](https://example.com/a.png)');
    expect(blocks.map((b) => b.runtimeType).toList(), [
      ParagraphBlock,
      DisplayMathBlock,
      BulletListBlock,
      TableBlock,
      ImageBlock,
    ]);
    expect((blocks[1] as DisplayMathBlock).tex, r'\frac{a}{b}');
    final table = blocks[3] as TableBlock;
    expect(table.headers, ['x', 'y']);
    expect(table.rows, [
      ['1', '2'],
    ]);
    expect((blocks[4] as ImageBlock).url, 'https://example.com/a.png');
  });

  test('plain() is safe on garbage', () {
    expect(StemMarkup.plain(r'$$ unclosed'), contains('unclosed'));
    expect(StemMarkup.parse(''), isEmpty);
  });
}
