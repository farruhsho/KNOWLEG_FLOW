import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/handbook_data.dart';
import '../widgets/handbook_search_delegate.dart';

/// Handbook: reference materials and formulas.
class HandbookPage extends StatelessWidget {
  const HandbookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.learnHandbookTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l.learnHandbookSearch,
            onPressed: () async {
              final categoryId = await showSearch<String?>(
                context: context,
                delegate: HandbookSearchDelegate(lang: lang, hint: l.learnHandbookSearch),
              );
              if (categoryId != null && categoryId.isNotEmpty && context.mounted) {
                context.push(RoutePaths.handbook(categoryId));
              }
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxxl),
        itemCount: HandbookData.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _CategoryTile(category: HandbookData.categories[i], lang: lang),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final HandbookCategory category;
  final String lang;
  const _CategoryTile({required this.category, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RoutePaths.handbook(category.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: AppRadii.smAll),
                child: Icon(category.icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickLocalized(category.title, lang), style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(pickLocalized(category.subtitle, lang), style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(l.learnHandbookSections(category.sections.length), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
