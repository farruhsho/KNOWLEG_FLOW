import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../billing/application/billing_providers.dart';
import '../../../billing/domain/entitlements.dart';
import '../../domain/exam_attempt.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/exam_variant.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';
import '../widgets/resume_banner.dart';

/// Root of the "Экзамены" tab.
class ExamsTabPage extends StatelessWidget {
  const ExamsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.examTabTitle),
        actions: [
          IconButton(
            tooltip: l.examHistoryAction,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(RoutePaths.examHistory),
          ),
        ],
      ),
      body: const ExamCatalogView(),
    );
  }
}

/// Catalog of directions (main / subject / state language) with variants.
class ExamCatalogView extends ConsumerWidget {
  const ExamCatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final blueprints = ref.watch(examBlueprintsProvider);
    return blueprints.when(
      loading: () => const ExamLoadingView(),
      error: (e, _) => ExamMessageView.error(
        context,
        error: e,
        onRetry: () => ref.invalidate(examBlueprintsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ExamMessageView(
              icon: Icons.inbox_outlined, message: l.examCatalogEmpty);
        }
        final main = list.where((b) => b.kind == BlueprintKind.main).toList();
        final subjects = list.where((b) => b.kind == BlueprintKind.subject).toList();
        final state =
            list.where((b) => b.kind == BlueprintKind.stateLanguage).toList();
        final gutter = AppSpacing.gutter(context);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(examBlueprintsProvider);
            ref.invalidate(localUnfinishedAttemptsProvider);
            await ref.read(examBlueprintsProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.huge),
            children: [
              if (!ref.watch(examCallablesSupportedProvider)) ...[
                const ExamPlatformNotice(),
                const SizedBox(height: AppSpacing.lg),
              ],
              const ExamResumeBanner(),
              Text(l.examCatalogIntro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.tokens.textSecondary,
                      )),
              const SizedBox(height: AppSpacing.lg),
              const _EntitlementCard(),
              const SizedBox(height: AppSpacing.lg),
              const _LanguageSelector(),
              if (main.isNotEmpty) ...[
                _GroupTitle(l.examCatalogMainTitle),
                for (final b in main)
                  _DirectionCard(
                      key: ValueKey('dir_${b.id}'), blueprint: b, initiallyExpanded: true),
              ],
              if (subjects.isNotEmpty) ...[
                _GroupTitle(l.examCatalogSubjectsTitle),
                for (final b in subjects)
                  _DirectionCard(key: ValueKey('dir_${b.id}'), blueprint: b),
              ],
              if (state.isNotEmpty) ...[
                _GroupTitle(l.examCatalogStateLanguageTitle),
                for (final b in state)
                  _DirectionCard(key: ValueKey('dir_${b.id}'), blueprint: b),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _EntitlementCard extends ConsumerWidget {
  const _EntitlementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ent = ref.watch(entitlementsProvider);
    final Entitlements? e = ent.valueOrNull;
    final title = ent.isLoading && e == null
        ? l.examLoading
        : e == null
            ? l.examEntitlementHint
            : e.hasFreeExam
                ? l.examEntitlementFree
                : e.credits > 0
                    ? l.examEntitlementCredits(e.credits)
                    : l.examEntitlementNone;
    final needsPurchase = e != null && !e.canStartExam;
    // BILLING_MODE=external (consumption-only build): balance and neutral
    // text only — no "Buy" button, no route to a purchase screen
    // (ARCHITECTURE §5, Google Play payments policy).
    final sellsInApp =
        ref.watch(billingModeProvider.select((m) => m.sellsInApp));
    return ExamCard(
      color: tokens.xpContainer,
      borderColor: tokens.xpContainer,
      child: Row(
        children: [
          Icon(Icons.confirmation_number_outlined, color: tokens.xp),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (e != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(l.examEntitlementHint, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (sellsInApp) ...[
            const SizedBox(width: AppSpacing.sm),
            needsPurchase
                ? FilledButton(
                    onPressed: () => context.push(RoutePaths.store),
                    child: Text(l.examBuy),
                  )
                : TextButton(
                    onPressed: () => context.push(RoutePaths.store),
                    child: Text(l.examBuy),
                  ),
          ],
        ],
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = ref.watch(examLanguageProvider);
    void select(String code) =>
        ref.read(examLanguageProvider.notifier).state = code;
    // Wrap (not Row) so the label and choices reflow on narrow phones and
    // with large text scaling instead of overflowing.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
          child: Text(l.examLanguageLabel,
              style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final code in const ['ru', 'ky'])
          ChoiceChip(
            key: ValueKey('exam_lang_$code'),
            label: Text(examLanguageName(l, code)),
            selected: lang == code,
            onSelected: (_) => select(code),
          ),
      ],
    );
  }
}

class _DirectionCard extends ConsumerStatefulWidget {
  final ExamBlueprint blueprint;
  final bool initiallyExpanded;

  const _DirectionCard({
    super.key,
    required this.blueprint,
    this.initiallyExpanded = false,
  });

  @override
  ConsumerState<_DirectionCard> createState() => _DirectionCardState();
}

class _DirectionCardState extends ConsumerState<_DirectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final bp = widget.blueprint;
    final ui = context.uiLang;
    final preferred = ref.watch(examLanguageProvider);
    final lang = bp.languageFor(preferred);
    final accent = SubjectColors.of(bp.subjectId ?? bp.sections.first.subjectArea);
    final summary = [
      l.examQuestionsCount(bp.totalQuestions),
      l.examMinutesCount(bp.totalMinutes),
      if (bp.sections.length > 1) l.examSectionsCount(bp.sections.length),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExamCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bp.title.resolve(ui), style: theme.textTheme.titleSmall),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(summary, style: theme.textTheme.bodySmall),
                          if (lang != preferred) ...[
                            const SizedBox(height: AppSpacing.xs),
                            ExamPill(
                              label: l.examOnlyLanguage(examLanguageName(l, lang)),
                              background: tokens.surfaceMuted,
                              foreground: tokens.textSecondary,
                              icon: Icons.translate_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: tokens.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.normal),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _VariantList(blueprintId: bp.id, language: lang)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantList extends ConsumerWidget {
  final String blueprintId;
  final String language;

  const _VariantList({required this.blueprintId, required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final query = (blueprintId: blueprintId, language: language);
    final state = ref.watch(variantListProvider(query));
    final statuses = ref.watch(variantStatusesProvider);
    final tokens = context.tokens;
    final children = <Widget>[Divider(height: 1, color: tokens.border)];
    if (state.isInitialLoading) {
      children.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox.square(
              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ));
    } else if (state.items.isEmpty && state.failure != null) {
      children.add(ExamMessageView.error(
        context,
        error: state.failure,
        onRetry: () => ref.read(variantListProvider(query).notifier).retry(),
      ));
    } else if (state.items.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(l.examVariantsEmpty, style: Theme.of(context).textTheme.bodySmall),
      ));
    } else {
      for (final v in state.items) {
        children.add(_VariantRow(
          variant: v,
          status: statuses[v.id] ?? VariantAttemptStatus.none,
        ));
      }
      if (state.failure != null) {
        children.add(TextButton.icon(
          onPressed: () => ref.read(variantListProvider(query).notifier).retry(),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.examRetry),
        ));
      } else if (state.hasMore) {
        children.add(TextButton(
          onPressed: state.loading
              ? null
              : () => ref.read(variantListProvider(query).notifier).loadMore(),
          child: Text(l.examShowMore),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _VariantRow extends StatelessWidget {
  final ExamVariant variant;
  final VariantAttemptStatus status;

  const _VariantRow({required this.variant, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final title = variant.title.isEmpty
        ? l.examVariantTitle(variant.number)
        : variant.title.resolve(context.uiLang);
    final Widget pill;
    if (status.isInProgress) {
      pill = ExamPill(
        label: l.examVariantInProgress,
        background: tokens.warningContainer,
        foreground: tokens.warning,
        icon: Icons.play_circle_outline_rounded,
      );
    } else if (status.isCompleted) {
      pill = ExamPill(
        label: l.examVariantBest(
            formatExamPercent(status.bestPercent ?? 0, context.uiLang)),
        background: tokens.successContainer,
        foreground: tokens.success,
        icon: Icons.check_rounded,
      );
    } else {
      pill = ExamPill(
        label: l.examVariantNotStarted,
        background: tokens.surfaceMuted,
        foreground: tokens.textSecondary,
      );
    }
    return InkWell(
      onTap: () => context.push(RoutePaths.examIntroFor(variant.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch + 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (variant.isAdvanced)
                      Text(l.examVariantAdvanced,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.primary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: pill),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
