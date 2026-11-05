import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/design/tokens.dart';
import 'package:knowledge_flow/features/tutor/presentation/widgets/tutor_markdown.dart';

void main() {
  group('parseTutorMarkdown', () {
    test('headings, lists, code and display math', () {
      final blocks = parseTutorMarkdown('''
## Решение
1. Найдём корни
2) Сложим их
- по теореме Виета
* ещё пункт

\$\$x_1 + x_2 = 5\$\$

```
print(5)
```
Итог.''');
      expect(blocks[0], isA<MdHeading>());
      expect((blocks[0] as MdHeading).level, 2);
      expect((blocks[1] as MdListItem).marker, '1.');
      expect((blocks[2] as MdListItem).marker, '2.');
      expect((blocks[3] as MdListItem).marker, isNull);
      expect((blocks[4] as MdListItem).text, 'ещё пункт');
      expect((blocks[5] as MdMathBlock).tex, 'x_1 + x_2 = 5');
      expect((blocks[6] as MdCode).code, 'print(5)');
      expect((blocks[7] as MdParagraph).text, 'Итог.');
    });

    test(r'multi-line \[ \] math', () {
      final blocks = parseTutorMarkdown('До\n\\[\n\\frac{a}{b}\n\\]\nПосле');
      expect(blocks.whereType<MdMathBlock>().single.tex, r'\frac{a}{b}');
      expect(blocks.whereType<MdParagraph>(), hasLength(2));
    });

    test('**bold** at line start is not a bullet', () {
      final blocks = parseTutorMarkdown('**Ответ:** 5');
      expect(blocks.single, isA<MdParagraph>());
    });

    test('unterminated fence keeps the text', () {
      final blocks = parseTutorMarkdown('```\ncode');
      expect((blocks.single as MdCode).code, 'code');
    });
  });

  group('parseInline', () {
    test(r'$...$ becomes math', () {
      final parts = parseInline(r'Корни уравнения $x^2-5x+6=0$ равны 2 и 3');
      expect(parts.whereType<MdInlineMath>().single.tex, 'x^2-5x+6=0');
      expect((parts.first as MdText).text, 'Корни уравнения ');
    });

    test('prices are not math', () {
      expect(parseInline(r'стоит 5$ и 10$').whereType<MdInlineMath>(), isEmpty);
      expect(parseInline(r'from $5 to $10').whereType<MdInlineMath>(), isEmpty);
      expect(parseInline(r'escaped \$x\$').whereType<MdInlineMath>(), isEmpty);
    });

    test(r'\( \) and inline $$ $$', () {
      expect(parseInline(r'a \(\sqrt{2}\) b').whereType<MdInlineMath>().single.tex, r'\sqrt{2}');
      expect(parseInline(r'a $$y=1$$ b').whereType<MdInlineMath>().single.tex, 'y=1');
    });

    test('bold, italic, code; snake_case stays plain', () {
      final p = parseInline('**важно** и *курсив* и `code` и snake_case_name');
      final texts = p.whereType<MdText>().toList();
      expect(texts.firstWhere((t) => t.text == 'важно').bold, isTrue);
      expect(texts.firstWhere((t) => t.text == 'курсив').italic, isTrue);
      expect(texts.firstWhere((t) => t.text == 'code').code, isTrue);
      expect(texts.map((t) => t.text).join(), contains('snake_case_name'));
      expect(texts.every((t) => !t.italic || t.text == 'курсив'), isTrue);
    });

    test('math inside bold is still math', () {
      final p = parseInline(r'**Ответ: $x=2$**');
      expect(p.whereType<MdInlineMath>().single.tex, 'x=2');
    });
  });

  testWidgets('renders text and survives invalid LaTeX', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppTokens.light]),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: TutorMarkdown('## Шаг 1\nСумма корней \$x_1+x_2=5\$.\n\n\$\$\\frac{1}{\$\$\n\n- пункт'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('Шаг 1', findRichText: true), findsOneWidget);
    expect(find.textContaining('пункт', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
