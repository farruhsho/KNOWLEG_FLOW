import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_question.dart';
import '../../domain/stem_markup.dart';
import 'exam_common.dart';
import 'exam_image_resolver.dart';

/// Renders stem markup ([StemMarkup]): paragraphs with inline `$…$` LaTeX,
/// display `$$…$$` formulas, bullet lists, tables and images. A formula that
/// fails to parse is shown as its source text instead of breaking the page.
class RichStem extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const RichStem(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    final blocks = StemMarkup.parse(text);
    if (blocks.isEmpty) return const SizedBox.shrink();
    if (blocks.length == 1 && blocks.first is ParagraphBlock) {
      return _Paragraph((blocks.first as ParagraphBlock).segments, base);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _block(blocks[i], base),
        ],
      ],
    );
  }

  Widget _block(StemBlock b, TextStyle base) => switch (b) {
        ParagraphBlock(:final segments) => _Paragraph(segments, base),
        DisplayMathBlock(:final tex) => _DisplayMath(tex, base),
        BulletListBlock(:final items) => _Bullets(items, base),
        TableBlock(:final headers, :final rows) =>
          ExamTable(headers: headers, rows: rows, style: base),
        ImageBlock(:final url, :final alt) => ExamImage(url: url, semanticLabel: alt),
      };
}

class _Paragraph extends StatelessWidget {
  final List<InlineSegment> segments;
  final TextStyle style;

  const _Paragraph(this.segments, this.style);

  @override
  Widget build(BuildContext context) {
    if (segments.every((s) => !s.isMath)) {
      return Text.rich(TextSpan(children: [
        for (final s in segments) _textSpan(s, style),
      ]), style: style);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
      return Text.rich(
        TextSpan(children: [
          for (final s in segments)
            if (s.isMath)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: InlineMath(s.text, style: style),
                  ),
                ),
              )
            else
              _textSpan(s, style),
        ]),
        style: style,
      );
    });
  }

  static TextSpan _textSpan(InlineSegment s, TextStyle style) => TextSpan(
        text: s.text,
        style: (s.bold || s.italic)
            ? TextStyle(
                fontWeight: s.bold ? FontWeight.w700 : null,
                fontStyle: s.italic ? FontStyle.italic : null,
              )
            : null,
      );
}

/// Inline LaTeX with a plain-text fallback.
class InlineMath extends StatelessWidget {
  final String tex;
  final TextStyle style;
  final MathStyle mathStyle;

  const InlineMath(this.tex,
      {super.key, required this.style, this.mathStyle = MathStyle.text});

  @override
  Widget build(BuildContext context) {
    return Math.tex(
      tex,
      mathStyle: mathStyle,
      textStyle: style,
      onErrorFallback: (_) => Text('\$$tex\$', style: style),
    );
  }
}

class _DisplayMath extends StatelessWidget {
  final String tex;
  final TextStyle style;
  const _DisplayMath(this.tex, this.style);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: InlineMath(tex, style: style, mathStyle: MathStyle.display),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<List<InlineSegment>> items;
  final TextStyle style;
  const _Bullets(this.items, this.style);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: _Paragraph(item, style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Simple bordered table; scrolls horizontally when wider than the screen.
class ExamTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final TextStyle? style;

  const ExamTable({super.key, required this.headers, required this.rows, this.style});

  factory ExamTable.fromQuestion(QuestionTable t, {TextStyle? style}) =>
      ExamTable(headers: t.headers, rows: t.rows, style: style);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final base = style ?? theme.textTheme.bodyMedium!;
    final columns = [headers.length, ...rows.map((r) => r.length)]
        .fold<int>(0, (m, n) => n > m ? n : m);
    if (columns == 0) return const SizedBox.shrink();
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: tokens.surfaceMuted) : null,
          children: [
            for (var c = 0; c < columns; c++)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: RichStem(
                  c < cells.length ? cells[c] : '',
                  style: header ? base.copyWith(fontWeight: FontWeight.w600) : base,
                ),
              ),
          ],
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: tokens.border, borderRadius: AppRadii.smAll),
        children: [
          if (headers.isNotEmpty) row(headers, header: true),
          for (final r in rows) row(r),
        ],
      ),
    );
  }
}

/// Question image: http(s) URLs load directly, Storage paths
/// (`exam_media/...`) are resolved through [examImageUrlResolverProvider].
class ExamImage extends ConsumerWidget {
  final String url;
  final String semanticLabel;

  const ExamImage({super.key, required this.url, this.semanticLabel = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(examImageUrlProvider(url));
    final tokens = context.tokens;
    Widget placeholder() => Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: AppRadii.mdAll,
          ),
          child: const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
    Widget failed() => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: AppRadii.mdAll,
          ),
          child: Row(
            children: [
              Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.l10n.examImageError,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        );
    return resolved.when(
      loading: placeholder,
      error: (_, __) => failed(),
      data: (u) => u == null
          ? failed()
          : Semantics(
              image: true,
              label: semanticLabel,
              child: ClipRRect(
                borderRadius: AppRadii.mdAll,
                child: InteractiveViewer(
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: u,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => placeholder(),
                    errorWidget: (_, __, ___) => failed(),
                  ),
                ),
              ),
            ),
    );
  }
}
