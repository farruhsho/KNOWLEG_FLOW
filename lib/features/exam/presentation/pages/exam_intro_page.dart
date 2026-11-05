import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../billing/application/billing_providers.dart';
import '../../../billing/domain/entitlements.dart';
import '../../data/exam_remote_datasource.dart';
import '../../domain/exam_attempt.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/exam_failure.dart';
import '../../domain/exam_session.dart';
import '../../domain/exam_start.dart';
import '../../domain/exam_variant.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';
import '../widgets/exam_style_choice.dart';

/// Rules, structure, style and cost of a library variant before starting
/// (RoutePaths.examIntro).
class ExamIntroPage extends ConsumerWidget {
  final String variantId;

  const ExamIntroPage({super.key, required this.variantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final variantAsync = ref.watch(examVariantProvider(variantId));
    return Scaffold(
      appBar: AppBar(title: Text(l.examTabTitle)),
      body: variantAsync.when(
        loading: () => const ExamLoadingView(),
        error: (e, _) => ExamMessageView.error(
          context,
          error: e,
          onRetry: () => ref.invalidate(examVariantProvider(variantId)),
        ),
        data: (variant) {
          if (variant == null || !variant.isPublished) {
            return ExamMessageView(
              icon: Icons.lock_clock_outlined,
              message: l.examErrorVariantUnavailable,
            );
          }
          final bpAsync = ref.watch(examBlueprintProvider(variant.blueprintId));
          return bpAsync.when(
            loading: () => const ExamLoadingView(),
            error: (e, _) => ExamMessageView.error(
              context,
              error: e,
              onRetry: () =>
                  ref.invalidate(examBlueprintProvider(variant.blueprintId)),
            ),
            data: (bp) => bp == null
                ? ExamMessageView(
                    icon: Icons.lock_clock_outlined,
                    message: l.examErrorVariantUnavailable,
                  )
                : _IntroBody(blueprint: bp, variant: variant),
          );
        },
      ),
    );
  }
}

/// «Новый пробный» (mode `fresh`, §10.1): the same rules screen for a new
/// variant the server assembles at start, with a language choice
/// (RoutePaths.examFresh).
class ExamFreshIntroPage extends ConsumerWidget {
  final String blueprintId;

  /// Preselected content language (`?lang=`), else the profile language.
  final String? language;

  const ExamFreshIntroPage({super.key, required this.blueprintId, this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final bpAsync = ref.watch(examBlueprintProvider(blueprintId));
    return Scaffold(
      appBar: AppBar(title: Text(l.examFreshStart)),
      body: bpAsync.when(
        loading: () => const ExamLoadingView(),
        error: (e, _) => ExamMessageView.error(
          context,
          error: e,
          onRetry: () => ref.invalidate(examBlueprintProvider(blueprintId)),
        ),
        data: (bp) => bp == null || !bp.isActive
            ? ExamMessageView(
                icon: Icons.lock_clock_outlined,
                message: l.examErrorVariantUnavailable,
              )
            : _IntroBody(blueprint: bp, initialLanguage: language),
      ),
    );
  }
}

/// Content languages a fresh variant of [bp] can be assembled in. The
/// state language test is Kyrgyz only (§10.1).
List<String> freshLanguagesFor(ExamBlueprint bp) {
  if (bp.kind == BlueprintKind.stateLanguage) return const ['ky'];
  return bp.languages;
}

class _IntroBody extends ConsumerStatefulWidget {
  final ExamBlueprint blueprint;

  /// Null for a fresh variant.
  final ExamVariant? variant;
  final String? initialLanguage;

  const _IntroBody({required this.blueprint, this.variant, this.initialLanguage});

  @override
  ConsumerState<_IntroBody> createState() => _IntroBodyState();
}

class _IntroBodyState extends ConsumerState<_IntroBody> {
  bool _starting = false;
  ExamStyle _style = ExamStyle.standard;
  String? _language;

  /// Language for which the server answered POOL_TOO_SMALL (null = none).
  String? _poolTooSmallFor;

  bool get _fresh => widget.variant == null;

  String _freshLanguage() {
    final options = freshLanguagesFor(widget.blueprint);
    final chosen = _language;
    if (chosen != null && options.contains(chosen)) return chosen;
    final String preferred =
        widget.initialLanguage ?? ref.read(examLanguageProvider);
    return options.contains(preferred) ? preferred : options.first;
  }

  Future<void> _start() async {
    if (_starting) return;
    final l = context.l10n;
    final language = _fresh ? _freshLanguage() : widget.variant!.language;
    setState(() {
      _starting = true;
      _poolTooSmallFor = null;
    });
    try {
      final request = _fresh
          ? ExamStartRequest.fresh(
              blueprintId: widget.blueprint.id,
              language: language,
              style: _style,
              clientAppVersion: examClientAppVersion,
            )
          : ExamStartRequest.library(
              variantId: widget.variant!.id,
              style: _style,
              clientAppVersion: examClientAppVersion,
            );
      final payload = await ref.read(examRemoteProvider).start(request);
      final session = ExamSession.fromPayload(
        payload,
        clientNow: ref.read(examClockProvider)(),
        blueprint: widget.blueprint,
        uid: ref.read(examUidProvider),
        fallbackLanguage: language,
        variantTitle: widget.variant?.title,
        style: _style,
      );
      // Saved before navigating so the runner opens instantly (and offline).
      await ref.read(examLocalStoreProvider).save(session, includeContent: true);
      ref.invalidate(localUnfinishedAttemptsProvider);
      if (!mounted) return;
      context.pushReplacement(RoutePaths.examRunFor(payload.attemptId));
    } on ExamFailure catch (f) {
      if (!mounted) return;
      setState(() => _starting = false);
      if (f.kind == ExamFailureKind.poolTooSmall) {
        // Shown inline (not a snackbar): the student needs to know no
        // credit was charged and what to do instead.
        setState(() => _poolTooSmallFor = language);
        return;
      }
      if (f.kind == ExamFailureKind.noEntitlement) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.examCostNeedCredit)));
        // A consumption-only build (BILLING_MODE=external) never routes to
        // a purchase screen.
        if (ref.read(billingModeProvider).sellsInApp) {
          context.push(RoutePaths.store);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(examFailureMessage(l, f))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(examFailureMessage(l, e))));
    }
  }

  void _resume(String attemptId) =>
      context.pushReplacement(RoutePaths.examRunFor(attemptId));

  void _backToLibrary() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.exams);
    }
  }

  /// In-progress attempt this screen should resume instead of starting.
  VariantAttemptStatus _status() {
    final v = widget.variant;
    if (v != null) {
      return ref.watch(variantStatusesProvider
          .select((m) => m[v.id] ?? VariantAttemptStatus.none));
    }
    final language = _freshLanguage();
    final attempts = ref.watch(myExamAttemptsProvider).valueOrNull ?? const [];
    for (final a in attempts) {
      if (a.isInProgress &&
          a.blueprintId == widget.blueprint.id &&
          a.language == language &&
          a.variantId.startsWith('fresh_')) {
        return VariantAttemptStatus(inProgressAttemptId: a.id);
      }
    }
    return VariantAttemptStatus.none;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final bp = widget.blueprint;
    final v = widget.variant;
    final ui = context.uiLang;
    final status = _status();
    final ent = ref.watch(entitlementsProvider);
    final sellsInApp = ref.watch(billingModeProvider.select((m) => m.sellsInApp));
    final platformSupported = ref.watch(examCallablesSupportedProvider);
    final strict = _style.isStrict;
    final scratchSections = bp.sections
        .where((s) => s.allowScratchpad)
        .map((s) => s.title.resolve(ui))
        .toList();
    final language = v?.language ?? _freshLanguage();
    final variantTitle = v == null
        ? l.examFreshVariantLine
        : v.title.isEmpty
            ? l.examVariantTitle(v.number)
            : v.title.resolve(ui);
    final disclaimer =
        bp.scoring.disclaimer.resolve(ui, fallback: l.examDisclaimerFallback);
    final gutter = AppSpacing.gutter(context);
    final freshLanguages = freshLanguagesFor(bp);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xxl),
            children: [
              if (!platformSupported) ...[
                const ExamPlatformNotice(),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(bp.title.resolve(ui), style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  variantTitle,
                  l.examIntroLanguage(examLanguageName(l, language)),
                ].join(' · '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: tokens.textSecondary),
              ),
              if (v == null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l.examFreshSubtitle, style: theme.textTheme.bodySmall),
              ],
              if (_poolTooSmallFor != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _PoolTooSmallCard(
                  language: examLanguageName(l, _poolTooSmallFor!),
                  onLibrary: _backToLibrary,
                ),
              ],
              if (v == null && !status.isInProgress) ...[
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(l.examFreshLanguageLabel),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final code in freshLanguages)
                      ChoiceChip(
                        key: ValueKey('fresh_lang_$code'),
                        label: Text(examLanguageName(l, code)),
                        selected: language == code,
                        onSelected: _starting
                            ? null
                            : (_) => setState(() {
                                  _language = code;
                                  _poolTooSmallFor = null;
                                }),
                      ),
                  ],
                ),
                if (bp.kind == BlueprintKind.stateLanguage) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l.examFreshKyOnly, style: theme.textTheme.bodySmall),
                ],
              ],
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(l.examIntroStructure),
              ExamCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < bp.sections.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: tokens.border),
                      _SectionRow(index: i, section: bp.sections[i], lang: ui),
                    ],
                    Divider(height: 1, color: tokens.border),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(l.examTotal, style: theme.textTheme.titleSmall),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              '${l.examQuestionsCount(bp.totalQuestions)} · ${l.examMinutesCount(bp.totalMinutes)}',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (bp.sections.any((s) => s.parts.any((p) => !p.verified))) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l.examPartAssumption, style: theme.textTheme.bodySmall),
              ],
              // The style of an attempt in progress is fixed: no choice then.
              if (!status.isInProgress) ...[
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(l.examStyleTitle),
                ExamStyleChoice(
                  value: _style,
                  onChanged: _starting ? null : (s) => setState(() => _style = s),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(l.examIntroRules),
              ExamCard(
                key: ValueKey('exam_rules_${_style.wire}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bp.forwardOnlyAcrossSections && bp.sections.length > 1)
                      ExamRuleLine(Icons.lock_outline_rounded, l.examRuleForwardOnly),
                    if (strict)
                      ...strictRuleLines(context)
                    else ...[
                      if (bp.freeNavigationWithinSection)
                        ExamRuleLine(Icons.swap_horiz_rounded, l.examRuleFreeNavigation),
                      ExamRuleLine(Icons.timer_outlined, l.examRuleTimer),
                    ],
                    if (!bp.rules.calculatorsAllowed)
                      ExamRuleLine(Icons.calculate_outlined, l.examRuleNoCalculator),
                    if (scratchSections.isNotEmpty)
                      ExamRuleLine(Icons.edit_note_rounded,
                          l.examRuleScratchpad(scratchSections.join(', '))),
                    ExamRuleLine(Icons.save_outlined, l.examRuleKeepsRunning),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(l.examIntroCost),
              ExamCard(
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, color: tokens.xp),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        status.isInProgress
                            ? l.examCostResume
                            : ent.when(
                                loading: () => l.examLoading,
                                error: (_, __) => l.examEntitlementHint,
                                data: (e) => e.hasFreeExam
                                    ? l.examCostFree
                                    : e.credits > 0
                                        ? l.examCostCredit(e.credits)
                                        : l.examCostNeedCredit,
                              ),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: tokens.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(disclaimer, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ),
        ),
        _BottomAction(
          starting: _starting,
          status: status,
          entitlements: ent.valueOrNull,
          sellsInApp: sellsInApp,
          platformSupported: platformSupported,
          onStart: _start,
          onResume: _resume,
        ),
      ],
    );
  }
}

/// POOL_TOO_SMALL: honest explanation, no credit charged, a way back to the
/// ready-made variants.
class _PoolTooSmallCard extends StatelessWidget {
  final String language;
  final VoidCallback onLibrary;

  const _PoolTooSmallCard({required this.language, required this.onLibrary});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return ExamCard(
      key: const ValueKey('exam_pool_too_small'),
      color: tokens.warningContainer,
      borderColor: tokens.warningContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: tokens.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l.examPoolTooSmallTitle, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l.examPoolTooSmallBody(language), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onLibrary,
              icon: const Icon(Icons.library_books_outlined),
              label: Text(l.examPoolTooSmallAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final bool starting;
  final VariantAttemptStatus status;
  final Entitlements? entitlements;

  /// False in a consumption-only build (BILLING_MODE=external): no purchase
  /// button, only a neutral disabled state when there are no credits.
  final bool sellsInApp;

  /// False on Windows / Linux (no App Check, contract D7).
  final bool platformSupported;
  final VoidCallback onStart;
  final ValueChanged<String> onResume;

  const _BottomAction({
    required this.starting,
    required this.status,
    required this.entitlements,
    required this.sellsInApp,
    required this.platformSupported,
    required this.onStart,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final gutter = AppSpacing.gutter(context);
    final Widget button;
    if (starting) {
      button = FilledButton.icon(
        onPressed: null,
        icon: const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(l.examStarting),
      );
    } else if (!platformSupported) {
      button = FilledButton.icon(
        key: const ValueKey('exam_platform_unsupported_button'),
        onPressed: null,
        icon: const Icon(Icons.phonelink_off_rounded),
        label: Text(l.examPlatformUnsupportedShort),
      );
    } else if (status.isInProgress) {
      button = FilledButton.icon(
        onPressed: () => onResume(status.inProgressAttemptId!),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(l.examContinue),
      );
    } else if (entitlements != null && !entitlements!.canStartExam) {
      button = sellsInApp
          ? FilledButton.icon(
              onPressed: () => context.push(RoutePaths.store),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(l.examBuyToStart),
            )
          : FilledButton.icon(
              key: const ValueKey('exam_no_credits_button'),
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(l.examNoCreditsAvailable),
            );
    } else {
      button = FilledButton.icon(
        key: const ValueKey('exam_start_button'),
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(l.examStart),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.md),
          child: SizedBox(width: double.infinity, child: button),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final int index;
  final ExamSection section;
  final String lang;

  const _SectionRow({required this.index, required this.section, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text('${index + 1}', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title.resolve(lang), style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${l.examQuestionsCount(section.questionCount)} · ${l.examMinutesCount(section.durationMinutes)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (section.parts.length > 1)
                  for (final p in section.parts)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        '• ${p.title.resolve(lang)} — ${l.examQuestionsCount(p.questionCount)}${p.verified ? '' : ' *'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
