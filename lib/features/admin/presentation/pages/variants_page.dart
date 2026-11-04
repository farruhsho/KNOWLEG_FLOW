import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/models/admin_records.dart';
import '../../data/repositories/exam_repositories.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/localized_text.dart';
import '../widgets/admin_widgets.dart';

String variantStatusLabel(AppLocalizations l, String s) => switch (s) {
      'draft' => l.adminVariantDraft,
      'in_review' => l.adminVariantInReview,
      'published' => l.adminVariantPublished,
      'archived' => l.adminVariantArchived,
      _ => s,
    };

AdminTone variantStatusTone(String s) => switch (s) {
      'published' => AdminTone.success,
      'in_review' => AdminTone.info,
      'archived' => AdminTone.neutral,
      _ => AdminTone.warning,
    };

/// Exam variants by blueprint (`exam_variants`).
class VariantsPage extends ConsumerStatefulWidget {
  const VariantsPage({super.key});

  @override
  ConsumerState<VariantsPage> createState() => _VariantsPageState();
}

class _VariantsPageState extends ConsumerState<VariantsPage> {
  VariantFilter _f = (blueprintId: null, status: null);

  Future<void> _open(String id) async {
    await context.push<bool>('/admin/variants/$id');
    // The builder saves in place (drafts) — always refresh on return.
    if (mounted) ref.read(variantsPageProvider(_f).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final blueprints = ref.watch(adminBlueprintsProvider).valueOrNull ?? const <BlueprintSpec>[];
    final byId = {for (final b in blueprints) b.id: b};
    final state = ref.watch(variantsPageProvider(_f));
    final notifier = ref.read(variantsPageProvider(_f).notifier);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(l.adminVariantsNew),
      ),
      body: Column(
        children: [
          AdminFilterBar(children: [
            AdminDropdown<String>(
              label: l.adminFieldBlueprint,
              value: _f.blueprintId,
              allLabel: l.adminAll,
              width: 280,
              items: {for (final b in blueprints) b.id: pickLocalized(b.title, locale)},
              onChanged: (v) => setState(() => _f = (blueprintId: v, status: _f.status)),
            ),
            AdminDropdown<String>(
              label: l.adminFieldStatus,
              value: _f.status,
              allLabel: l.adminAll,
              width: 180,
              items: {for (final s in VariantDoc.statuses) s: variantStatusLabel(l, s)},
              onChanged: (v) => setState(() => _f = (blueprintId: _f.blueprintId, status: v)),
            ),
          ]),
          Expanded(
            child: PagedListBody<VariantDoc>(
              state: state,
              onLoadMore: notifier.loadMore,
              onRetry: notifier.retry,
              onRefresh: notifier.refresh,
              emptyMessage: l.adminVariantsEmpty,
              itemBuilder: (context, v) {
                final b = byId[v.blueprintId];
                final title = localizedOf(v.title, locale);
                return AdminListTile(
                  title: title.isEmpty ? l.adminVariantN(v.number) : title,
                  subtitle: l.adminVariantsMeta(
                    b == null ? v.blueprintId : pickLocalized(b.title, locale),
                    v.questionCount,
                    b?.totalQuestions ?? 0,
                  ),
                  leading: CircleAvatar(child: Text('${v.number}')),
                  chips: [
                    AdminPill(variantStatusLabel(l, v.status), tone: variantStatusTone(v.status)),
                    AdminPill(v.language.toUpperCase(), tone: AdminTone.info),
                  ],
                  onTap: () => _open(v.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
