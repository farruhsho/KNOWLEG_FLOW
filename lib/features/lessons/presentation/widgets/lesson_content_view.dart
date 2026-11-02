import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/widgets/content_image.dart';
import '../../../../shared/widgets/math_markdown.dart';

/// Renders a lesson's content: the structured blocks when present, falling
/// back to the legacy `content` blob (Markdown-ish + LaTeX).
class LessonContentView extends StatelessWidget {
  final LessonModel lesson;
  const LessonContentView({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;
    final legacy = lesson.getContent(lang);
    final summary = lesson.getSummary(lang);

    final children = <Widget>[];
    void gap([double h = AppSpacing.xl]) => children.add(SizedBox(height: h));

    if (summary.trim().isNotEmpty) {
      children.add(_Block(
        icon: Icons.lightbulb_outline,
        title: l.learnLessonSummary,
        tinted: true,
        child: MathMarkdown(summary, style: body),
      ));
      gap();
    }

    if (lesson.sections.isNotEmpty) {
      for (final s in lesson.sections) {
        final title = pickLocalized(s.title, lang);
        final text = pickLocalized(s.body, lang);
        if (title.trim().isNotEmpty) {
          children.add(Text(title, style: theme.textTheme.titleLarge));
          gap(AppSpacing.sm);
        }
        if (text.trim().isNotEmpty) children.add(MathMarkdown(text, style: body));
        gap();
      }
    } else if (legacy.trim().isNotEmpty) {
      children.add(MathMarkdown(legacy, style: body));
      gap();
    }

    if (lesson.formulas.isNotEmpty) {
      children.add(_Block(
        icon: Icons.functions,
        title: l.learnLessonFormulas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in lesson.formulas) ...[
              if (pickLocalized(f.title, lang).isNotEmpty)
                Text(pickLocalized(f.title, lang), style: theme.textTheme.labelLarge),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Math.tex(
                  f.latex,
                  mathStyle: MathStyle.display,
                  textStyle: body?.copyWith(color: theme.colorScheme.onSurface),
                  onErrorFallback: (_) => Text(f.latex, style: body),
                ),
              ),
            ],
          ],
        ),
      ));
      gap();
    }

    if (lesson.examples.isNotEmpty) {
      children.add(Text(l.learnLessonExamples, style: theme.textTheme.titleLarge));
      gap(AppSpacing.sm);
      for (var i = 0; i < lesson.examples.length; i++) {
        children.add(_ExampleCard(index: i + 1, example: lesson.examples[i], lang: lang));
        gap(AppSpacing.md);
      }
      gap(AppSpacing.sm);
    }

    if (lesson.commonMistakes.isNotEmpty) {
      children.add(_Block(
        icon: Icons.report_gmailerrorred_outlined,
        title: l.learnLessonCommonMistakes,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in lesson.commonMistakes) MathMarkdown('- ${pickLocalized(m, lang)}', style: body, compact: true),
          ],
        ),
      ));
      gap();
    }

    if (lesson.images.isNotEmpty) {
      for (final src in lesson.images) {
        children.add(ContentImage(source: src));
        gap(AppSpacing.md);
      }
    }

    if (children.isEmpty) {
      children.add(Text(l.learnLessonNoContent, style: body?.copyWith(color: context.tokens.textSecondary)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _Block extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final bool tinted;

  const _Block({required this.icon, required this.title, required this.child, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tinted ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ExampleCard extends StatefulWidget {
  final int index;
  final LessonExample example;
  final String lang;
  const _ExampleCard({required this.index, required this.example, required this.lang});

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final solution = pickLocalized(widget.example.solution, widget.lang);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.learnLessonExampleN(widget.index), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: AppSpacing.sm),
          MathMarkdown(pickLocalized(widget.example.problem, widget.lang), style: theme.textTheme.bodyLarge),
          if (solution.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                label: Text(_open ? l.learnLessonHideSolution : l.learnLessonShowSolution),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.normal),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: _open
                  ? MathMarkdown(solution, style: theme.textTheme.bodyMedium)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}
