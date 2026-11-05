import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../domain/exam_failure.dart';
import '../../domain/exam_session.dart';
import '../controllers/exam_runner_controller.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';
import '../widgets/exam_countdown.dart';
import '../widgets/exam_style_choice.dart';
import '../widgets/question_palette.dart';
import '../widgets/question_view.dart';

/// Full-screen exam runner (RoutePaths.examRun). Minimal chrome: section and
/// part, a server-anchored countdown, progress, the question, and a bottom
/// bar with previous / mark / palette / next.
///
/// Strict style («Как на ОРТ», §10.2): no flag button, no "Finish section"
/// (the bar shows «Раздел закончится через …» instead and the section is
/// sent at its deadline), no clearing, one correction per answer, and an
/// instruction screen before every section.
class ExamRunnerPage extends ConsumerStatefulWidget {
  final String attemptId;

  const ExamRunnerPage({super.key, required this.attemptId});

  @override
  ConsumerState<ExamRunnerPage> createState() => _ExamRunnerPageState();
}

class _ExamRunnerPageState extends ConsumerState<ExamRunnerPage>
    with WidgetsBindingObserver {
  bool _navigatedToResult = false;

  ExamRunnerController get _controller =>
      ref.read(examRunnerControllerProvider(widget.attemptId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Sends the draft and stops the per-question clock (§9.5).
      _controller.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      _controller.onAppForeground();
    }
  }

  void _goToResult() {
    if (_navigatedToResult || !mounted) return;
    _navigatedToResult = true;
    ref.invalidate(localUnfinishedAttemptsProvider);
    context.pushReplacement(RoutePaths.examResultFor(widget.attemptId));
  }

  void _leave() {
    _controller.flushDraft();
    ref.invalidate(localUnfinishedAttemptsProvider);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.exams);
    }
  }

  Future<void> _confirmExit() async {
    final l = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.timer_outlined),
        title: Text(l.examExitTitle),
        content: Text(l.examExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.examExitLeave),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.examExitStay),
          ),
        ],
      ),
    );
    // "Stay" is the primary (safe) action; only an explicit "Leave" exits.
    if (leave == false && mounted) _leave();
  }

  void _showNotice(ExamRunnerNotice notice) {
    final l = context.l10n;
    final text = switch (notice) {
      ExamRunnerNotice.fiveMinutesLeft => l.examWarningFive,
      ExamRunnerNotice.oneMinuteLeft => l.examWarningOne,
      ExamRunnerNotice.autoSubmitted => l.examAutoSubmitted,
      ExamRunnerNotice.answerLocked => l.examStrictAnswerLocked,
    };
    if (notice == ExamRunnerNotice.answerLocked) {
      HapticFeedback.selectionClick();
    } else if (notice != ExamRunnerNotice.autoSubmitted) {
      HapticFeedback.mediumImpact();
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = examRunnerControllerProvider(widget.attemptId);
    ref.listen<int>(provider.select((s) => s.noticeSeq), (prev, next) {
      final notice = ref.read(provider).notice;
      if (notice != null && next != prev) _showNotice(notice);
    });
    ref.listen<ExamPhase?>(provider.select((s) => s.phase), (prev, next) {
      if (next == ExamPhase.completed) _goToResult();
    });
    final loading = ref.watch(provider.select((s) => s.loading));
    final hasSession = ref.watch(provider.select((s) => s.session != null));
    final loadFailure = ref.watch(provider.select((s) => s.loadFailure));
    final phase = ref.watch(provider.select((s) => s.phase));

    if (phase == ExamPhase.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToResult());
    }

    final Widget body;
    if (!hasSession && loading) {
      body = const ExamLoadingView();
    } else if (!hasSession) {
      body = ExamMessageView.error(
        context,
        error: loadFailure,
        onRetry: _controller.retryLoad,
      );
    } else {
      body = switch (phase!) {
        ExamPhase.inSection => _InSectionView(
          attemptId: widget.attemptId,
          onExit: _confirmExit,
        ),
        ExamPhase.submitting => ExamLoadingView(
          message: context.l10n.examSubmitting,
        ),
        ExamPhase.submitPending => _SubmitPendingView(
          attemptId: widget.attemptId,
        ),
        ExamPhase.sectionIntro => _SectionIntroView(
          attemptId: widget.attemptId,
        ),
        ExamPhase.completed => ExamLoadingView(
          message: context.l10n.examFinishedLoading,
        ),
      };
    }

    final showCloseBar = phase != ExamPhase.inSection;
    return PopScope(
      canPop: phase == ExamPhase.completed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Same as the close button: the "timer keeps running, answers are
        // saved" dialog only makes sense once an attempt is loaded. On the
        // loading / load-failure screen, back just leaves.
        if (hasSession) {
          _confirmExit();
        } else {
          _leave();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCloseBar)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    tooltip: context.l10n.examExit,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: hasSession ? _confirmExit : _leave,
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- in section

class _InSectionView extends ConsumerWidget {
  final String attemptId;
  final VoidCallback onExit;

  const _InSectionView({required this.attemptId, required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final hasQuestions = ref.watch(
      provider.select((s) => s.session?.hasQuestions ?? false),
    );
    final offline = ref.watch(provider.select((s) => s.offline));
    // Strict style shows it on the first instruction screen instead.
    final repeated = ref.watch(provider.select((s) {
      final session = s.session;
      final f = session?.freshness;
      return session != null &&
              !session.isStrict &&
              session.sectionIndex == 0 &&
              f != null
          ? f.repeated
          : 0;
    }));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RunnerHeader(attemptId: attemptId, onExit: onExit),
        if (offline) const _OfflineStrip(),
        if (repeated > 0) ExamFreshnessNotice(repeated: repeated),
        Expanded(
          child: hasQuestions
              ? ExamQuestionArea(attemptId: attemptId)
              : ExamMessageView(
                  icon: Icons.help_outline_rounded,
                  message: context.l10n.examNoQuestions,
                ),
        ),
        if (hasQuestions) _RunnerBottomBar(attemptId: attemptId),
      ],
    );
  }
}

/// «N заданий вы уже встречали» (§10.1): shown on the first section of a
/// fresh variant that had to reuse questions; dismissible.
class ExamFreshnessNotice extends StatefulWidget {
  final int repeated;

  const ExamFreshnessNotice({super.key, required this.repeated});

  @override
  State<ExamFreshnessNotice> createState() => _ExamFreshnessNoticeState();
}

class _ExamFreshnessNoticeState extends State<ExamFreshnessNotice> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const ValueKey('exam_freshness_notice'),
      color: scheme.secondaryContainer,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${l.examFreshnessRepeated(widget.repeated)}. ${l.examFreshnessWhy}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.warningContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.examOfflineBadge,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunnerHeader extends ConsumerWidget {
  final String attemptId;
  final VoidCallback onExit;

  const _RunnerHeader({required this.attemptId, required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final session = ref.watch(provider.select((s) => s.session))!;
    // Only fields that matter for the header; the session object changes on
    // every answer, but these selects keep the rebuild cheap.
    final index = session.currentIndex;
    final total = session.questionCount;
    final answered = session.answeredCount;
    final lang = session.language;
    final sectionTitle = session.sectionSpec.title.resolve(lang);
    final part = session.partAt(index);
    final showPart = session.sectionSpec.parts.length > 1;
    final clock = ref.watch(examClockProvider);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.examExit,
                icon: const Icon(Icons.close_rounded),
                onPressed: onExit,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      showPart
                          ? part.title.resolve(lang)
                          : l.examSectionLabel(
                              session.sectionIndex + 1,
                              session.sectionCount,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExamCountdown(
                key: ValueKey('countdown_${session.section.sectionId}'),
                deadline: session.localDeadline(),
                clock: clock,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.examQuestionOf(index + 1, total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l.examAnsweredOf(answered, total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : answered / total,
                minHeight: 4,
                backgroundColor: tokens.surfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current question (stem, passage, options). Public for widget tests.
class ExamQuestionArea extends ConsumerStatefulWidget {
  final String attemptId;

  const ExamQuestionArea({super.key, required this.attemptId});

  @override
  ConsumerState<ExamQuestionArea> createState() => _ExamQuestionAreaState();
}

class _ExamQuestionAreaState extends ConsumerState<ExamQuestionArea> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = examRunnerControllerProvider(widget.attemptId);
    final index = ref.watch(
      provider.select((s) => s.session?.currentIndex ?? 0),
    );
    final session = ref.read(provider).session!;
    if (!session.hasQuestions) return const SizedBox.shrink();
    final question = session.questions[index];
    final selected = ref.watch(
      provider.select((s) => s.session?.answers[question.id]),
    );
    final controller = ref.read(provider.notifier);
    final passage = session.passageFor(question);
    final strict = session.isStrict;
    final choices = strict
        ? ref.watch(provider.select((s) => s.session?.choicesMade(question.id) ?? 0))
        : 0;
    ref.listen<int?>(provider.select((s) => s.session?.currentIndex), (_, __) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    return QuestionWithPassage(
      key: ValueKey('q_area_${session.section.sectionId}'),
      passage: passage,
      lineEvery: session.sectionSpec.lineNumberingEvery,
      controller: _scroll,
      question: QuestionBody(
        key: ValueKey('q_${question.id}'),
        question: question,
        part: session.partAt(index),
        options: session.optionsFor(index),
        selected: selected,
        enabled: true,
        onSelect: (o) => controller.selectAnswer(question.id, o),
        // Strict: an answer can be corrected, never erased.
        onClear: strict ? null : () => controller.clearAnswer(question.id),
        footer: strict && selected != null
            ? _StrictAnswerHint(locked: choices >= ExamSession.strictMaxChoices)
            : null,
      ),
    );
  }
}

/// Strict style: whether the one correction is still available.
class _StrictAnswerHint extends StatelessWidget {
  final bool locked;

  const _StrictAnswerHint({required this.locked});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = context.tokens;
    return Padding(
      key: const ValueKey('strict_answer_hint'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.edit_outlined,
            size: 16,
            color: tokens.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              locked ? l.examStrictCorrectionUsed : l.examStrictCorrectionLeft,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunnerBottomBar extends ConsumerWidget {
  final String attemptId;

  const _RunnerBottomBar({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final l = context.l10n;
    final tokens = context.tokens;
    final index = ref.watch(
      provider.select((s) => s.session?.currentIndex ?? 0),
    );
    final total = ref.watch(
      provider.select((s) => s.session?.questionCount ?? 0),
    );
    final qid = ref.watch(
      provider.select((s) => s.session?.currentQuestion?.id),
    );
    final flagged = ref.watch(
      provider.select(
        (s) => qid != null && (s.session?.flags.contains(qid) ?? false),
      ),
    );
    final controller = ref.read(provider.notifier);
    final isLast = index >= total - 1;
    final strict = ref.watch(provider.select((s) => s.session?.isStrict ?? false));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l.examPrevious,
            onPressed: index > 0 ? controller.previous : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          // Strict style: no "come back later" flags (§10.2).
          if (!strict)
            IconButton(
              key: const ValueKey('flag_button'),
              tooltip: flagged ? l.examUnflag : l.examFlag,
              isSelected: flagged,
              onPressed: qid == null ? null : () => controller.toggleFlag(qid),
              icon: const Icon(Icons.outlined_flag_rounded),
              selectedIcon: Icon(Icons.flag_rounded, color: tokens.warning),
            ),
          IconButton(
            key: const ValueKey('palette_button'),
            tooltip: l.examPalette,
            onPressed: () => showExamPaletteSheet(context, ref, attemptId),
            icon: const Icon(Icons.grid_view_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: isLast && strict
                ? _StrictSectionCountdown(attemptId: attemptId)
                : isLast
                ? FilledButton(
                    onPressed: () =>
                        confirmFinishSection(context, ref, attemptId),
                    child: Text(
                      l.examFinishSection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : FilledButton.tonal(
                    onPressed: controller.next,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            l.examNext,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Strict style: where "Finish section" would be — the section ends by
/// itself at its deadline.
class _StrictSectionCountdown extends ConsumerWidget {
  final String attemptId;

  const _StrictSectionCountdown({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final deadline = ref.watch(
      provider.select((s) => s.session?.localDeadline()),
    );
    final clock = ref.watch(examClockProvider);
    final tokens = context.tokens;
    if (deadline == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('strict_section_countdown'),
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: ExamCountdown(
        deadline: deadline,
        clock: clock,
        style: Theme.of(context).textTheme.labelLarge,
        labelBuilder: context.l10n.examStrictSectionEndsIn,
      ),
    );
  }
}

/// What the palette sheet asks its opener to do after it closes.
enum ExamPaletteAction { finishSection }

/// Bottom sheet with the question palette and "Finish section".
///
/// "Finish section" closes the sheet and returns
/// [ExamPaletteAction.finishSection]; the confirmation and the submission run
/// here with the runner page's [context] and [ref]. They must not run inside
/// the sheet: its context and ref are disposed as soon as it pops, so the
/// submit call would throw and the section would never be sent.
Future<void> showExamPaletteSheet(
  BuildContext context,
  WidgetRef ref,
  String attemptId,
) async {
  final action = await showModalBottomSheet<ExamPaletteAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => _PaletteSheet(attemptId: attemptId),
  );
  if (action == ExamPaletteAction.finishSection && context.mounted) {
    await confirmFinishSection(context, ref, attemptId);
  }
}

class _PaletteSheet extends ConsumerWidget {
  final String attemptId;
  const _PaletteSheet({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final session = ref.watch(provider.select((s) => s.session));
    if (session == null) return const SizedBox.shrink();
    final l = context.l10n;
    final cells = [
      for (var i = 0; i < session.questionCount; i++) session.cell(i),
    ];
    final groups = <PaletteGroup>[];
    final parts = session.sectionSpec.parts;
    if (parts.length > 1) {
      var start = 0;
      for (final p in parts) {
        if (start >= cells.length) break;
        groups.add(
          PaletteGroup(
            title: p.title.resolve(session.language),
            start: start,
            count: p.questionCount,
          ),
        );
        start += p.questionCount;
      }
      if (start < cells.length) {
        groups.add(
          PaletteGroup(title: '', start: start, count: cells.length - start),
        );
      }
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              session.sectionSpec.title.resolve(session.language),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: QuestionPalette(
                cells: cells,
                groups: groups,
                showFlags: session.allowsFlags,
                onSelect: (i) {
                  ref.read(provider.notifier).goTo(i);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          if (session.canFinishEarly)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(ExamPaletteAction.finishSection),
                icon: const Icon(Icons.done_all_rounded),
                label: Text(l.examFinishSection),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Text(
                l.examStrictRuleNoEarlyFinish,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Confirmation listing unanswered / marked counts; finishing is final.
Future<void> confirmFinishSection(
  BuildContext context,
  WidgetRef ref,
  String attemptId,
) async {
  final provider = examRunnerControllerProvider(attemptId);
  final session = ref.read(provider).session;
  if (session == null || session.phase != ExamPhase.inSection) return;
  // Strict style: a section is never finished early.
  if (!session.canFinishEarly) return;
  final l = context.l10n;
  final tokens = context.tokens;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        l.examFinishSectionTitle(
          session.sectionSpec.title.resolve(session.language),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.examFinishSectionUnanswered(session.unansweredCount),
            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
              color: session.unansweredCount > 0 ? tokens.danger : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.examFinishSectionFlagged(session.flaggedCount),
            style: Theme.of(ctx).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.examFinishSectionWarning,
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.examKeepWorking),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.examFinishSectionConfirm),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(provider.notifier).submitSection();
  }
}

// --------------------------------------------------------- other phases

class _SubmitPendingView extends ConsumerWidget {
  final String attemptId;
  const _SubmitPendingView({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final failure = ref.watch(provider.select((s) => s.submitFailure));
    final l = context.l10n;
    if (failure?.kind == ExamFailureKind.sectionNotOver) {
      return ExamLoadingView(
        key: const ValueKey('strict_waiting_deadline'),
        message: l.examStrictWaitingDeadline,
      );
    }
    final isNetwork = failure == null || failure.kind.isRetryable;
    return ExamMessageView(
      icon: isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: isNetwork ? l.examOfflineTitle : null,
      message: isNetwork
          ? '${l.examOfflineBody}\n${l.examOfflineAutoRetry}'
          : '${examFailureMessage(l, failure)}\n${l.examOfflineBody}',
      actionLabel: l.examRetry,
      onAction: () => ref.read(provider.notifier).retrySubmit(),
      isError: !isNetwork,
    );
  }
}

class _SectionIntroView extends ConsumerWidget {
  final String attemptId;
  const _SectionIntroView({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final session = ref.watch(provider.select((s) => s.session))!;
    if (session.isStrict) return _StrictSectionInstruction(attemptId: attemptId);
    final clock = ref.watch(examClockProvider);
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final spec = session.sectionSpec;
    final lang = session.language;
    final calculators = session.blueprint.rules.calculatorsAllowed;
    final gutter = AppSpacing.gutter(context);
    // The primary action stays pinned at the bottom so it is reachable on a
    // small phone without scrolling past the rules.
    final details = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: AppSpacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: tokens.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.examSectionDone,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l.examNextSectionTitle.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                spec.title.resolve(lang),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  l.examSectionLabel(
                    session.sectionIndex + 1,
                    session.sectionCount,
                  ),
                  l.examQuestionsCount(spec.questionCount),
                  l.examMinutesCount(spec.durationMinutes),
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              if (spec.parts.length > 1) ...[
                const SizedBox(height: AppSpacing.md),
                for (final p in spec.parts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '• ${p.title.resolve(lang)} — ${l.examQuestionsCount(p.questionCount)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ExamCard(
                color: tokens.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RuleLine(
                      icon: Icons.lock_outline_rounded,
                      text: l.examRuleForwardOnly,
                    ),
                    _RuleLine(
                      icon: Icons.swap_horiz_rounded,
                      text: l.examRuleFreeNavigation,
                    ),
                    if (!calculators)
                      _RuleLine(
                        icon: Icons.calculate_outlined,
                        text: l.examRuleNoCalculator,
                      ),
                    if (spec.allowScratchpad)
                      _RuleLine(
                        icon: Icons.edit_note_rounded,
                        text: l.examRuleScratchpad(
                          spec.title.resolve(context.uiLang),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l.examNextSectionTimeRunning,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExamCountdown(
                  deadline: session.localDeadline(),
                  clock: clock,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: details),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpacing.md,
              gutter,
              AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('start_section_button'),
                    onPressed: () => ref.read(provider.notifier).startSection(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l.examStartSection),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Strict style: the instruction screen before every section (§10.2) —
/// section, questions, minutes, rules, scratch paper only where the
/// blueprint allows it, and an honest note that the timer already runs.
class _StrictSectionInstruction extends ConsumerWidget {
  final String attemptId;
  const _StrictSectionInstruction({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examRunnerControllerProvider(attemptId);
    final session = ref.watch(provider.select((s) => s.session))!;
    final clock = ref.watch(examClockProvider);
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final spec = session.sectionSpec;
    final lang = session.language;
    final calculators = session.blueprint.rules.calculatorsAllowed;
    final gutter = AppSpacing.gutter(context);
    final first = session.submitted.isEmpty;
    final repeated =
        first && session.freshness != null ? session.freshness!.repeated : 0;
    final details = SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!first) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: tokens.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.examSectionDone,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: tokens.success),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text(
                l.examSectionInstructionTitle.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(spec.title.resolve(lang), style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  l.examSectionLabel(session.sectionIndex + 1, session.sectionCount),
                  l.examQuestionsCount(spec.questionCount),
                  l.examMinutesCount(spec.durationMinutes),
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
              if (spec.parts.length > 1) ...[
                const SizedBox(height: AppSpacing.md),
                for (final p in spec.parts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '• ${p.title.resolve(lang)} — ${l.examQuestionsCount(p.questionCount)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
              if (repeated > 0) ...[
                const SizedBox(height: AppSpacing.md),
                ExamFreshnessNotice(repeated: repeated),
              ],
              const SizedBox(height: AppSpacing.lg),
              ExamCard(
                key: const ValueKey('strict_section_rules'),
                color: tokens.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (session.sectionCount > 1)
                      ExamRuleLine(Icons.lock_outline_rounded, l.examRuleForwardOnly),
                    ...strictRuleLines(context, includeInstruction: false),
                    if (!calculators)
                      ExamRuleLine(Icons.calculate_outlined, l.examRuleNoCalculator),
                    if (spec.allowScratchpad)
                      ExamRuleLine(
                        Icons.edit_note_rounded,
                        l.examRuleScratchpad(spec.title.resolve(context.uiLang)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l.examStrictTimerRunning, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExamCountdown(
                  key: const ValueKey('strict_instruction_countdown'),
                  deadline: session.localDeadline(),
                  clock: clock,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: details),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('start_section_button'),
                    onPressed: () => ref.read(provider.notifier).startSection(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l.examStartSection),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RuleLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.tokens.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
