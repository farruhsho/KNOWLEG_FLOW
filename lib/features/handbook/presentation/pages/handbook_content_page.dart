import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/math_markdown.dart';
import '../../data/handbook_data.dart';
import '../../data/ort_structure.dart';

/// Handbook content viewer. Markdown + LaTeX is rendered properly (CMS-27);
/// the ORT structure and scoring sections come from the verified blueprint
/// asset (CMS-08). The fake bookmark button is gone.
class HandbookContentPage extends StatefulWidget {
  final String categoryId;

  const HandbookContentPage({
    super.key,
    required this.categoryId,
  });

  @override
  State<HandbookContentPage> createState() => _HandbookContentPageState();
}

class _HandbookContentPageState extends State<HandbookContentPage> {
  Future<OrtStructureFacts>? _facts;

  @override
  void initState() {
    super.initState();
    final c = HandbookData.byId(widget.categoryId);
    if (c != null && c.sections.any((s) => s.generated != null)) {
      _facts = OrtStructureFacts.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final category = HandbookData.byId(widget.categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.learnHandbookTitle)),
        body: EmptyView(
          icon: Icons.menu_book_outlined,
          message: l.learnHandbookNotFound,
          action: FilledButton(
            onPressed: () => context.go(RoutePaths.home),
            child: Text(l.learnBackHome),
          ),
        ),
      );
    }
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(title: Text(pickLocalized(category.title, lang), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<OrtStructureFacts>(
        future: _facts,
        builder: (context, snap) {
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
            children: [
              if (lang == 'ky' && category.sections.every((s) => !s.body.containsKey('ky') && s.generated == null))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(l.learnHandbookRussianOnly, style: Theme.of(context).textTheme.bodySmall),
                ),
              for (final s in category.sections) ...[
                _SectionCard(title: pickLocalized(s.title, lang), child: _sectionBody(context, l, lang, s, snap)),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.quickTest),
                icon: const Icon(Icons.bolt_outlined),
                label: Text(l.learnQuickPracticeTitle),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionBody(
    BuildContext context,
    AppLocalizations l,
    String lang,
    HandbookSection s,
    AsyncSnapshot<OrtStructureFacts> snap,
  ) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final gen = s.generated;
    if (gen == null) return MathMarkdown(pickLocalized(s.body, lang), style: style);
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final facts = snap.data;
    if (facts == null) {
      return Text(l.learnHandbookFactsUnavailable, style: style);
    }
    final md = gen == HandbookGenerated.ortStructure
        ? facts.structureMarkdown(l, lang)
        : facts.scoringMarkdown(l, lang);
    return MathMarkdown(md, style: style);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
