import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../core/utils/nav_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/practice_session_model.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/services/activity_reporter.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/services/learning_activity_service.dart';
import '../../../../shared/services/mistakes_service.dart';
import '../../../../shared/widgets/content_image.dart';
import '../../../../shared/widgets/elapsed_timer.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/math_markdown.dart';
import '../../data/practice_session_store.dart';
import '../../domain/practice_controller.dart';
import '../../domain/practice_launch.dart';

/// Loads questions for a [PracticeLaunch] from Firestore.
Future<List<QuestionModel>> loadPracticeQuestions(PracticeLaunch launch) {
  final data = FirebaseDataService();
  if (launch.questionIds.isNotEmpty) return data.getQuestionsByIds(launch.questionIds);
  return data.getQuestions(subjectId: launch.kind == PracticeKind.quick ? null : launch.subjectId);
}

/// The practice runner shared by the subject quiz, quick practice, lesson
/// practice and mistakes review.
class PracticeSessionView extends StatefulWidget {
  final PracticeLaunch launch;
  final QuestionLoader? loader;

  const PracticeSessionView({super.key, required this.launch, this.loader});

  @override
  State<PracticeSessionView> createState() => _PracticeSessionViewState();
}

class _PracticeSessionViewState extends State<PracticeSessionView> {
  late final PracticeController _c;
  final _scroll = ScrollController();
  bool _leaving = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _c = PracticeController(launch: widget.launch, loader: widget.loader ?? loadPracticeQuestions);
    // EXAM-19: no anonymous sessions writing to "current_user".
    if (_uidSafe() != null) _c.load();
  }

  String? _uidSafe() {
    try {
      return _uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l) {
    switch (widget.launch.kind) {
      case PracticeKind.quick:
        return l.learnQuickPracticeTitle;
      case PracticeKind.lesson:
        return l.learnLessonPracticeTitle;
      case PracticeKind.mistakes:
        return l.learnMistakesPracticeTitle;
      case PracticeKind.subject:
        return l.learnPracticeTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_uidSafe() == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title(l))),
        body: EmptyView(
          icon: Icons.lock_outline,
          message: l.learnSignInToPractice,
          action: FilledButton(
            onPressed: () => context.go(RoutePaths.login),
            child: Text(l.learnSignIn),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        switch (_c.status) {
          case PracticeStatus.loading:
            return Scaffold(
              appBar: AppBar(title: Text(_title(l))),
              body: LoadingView(message: l.learnLoadingQuestions),
            );
          case PracticeStatus.error:
            return Scaffold(
              appBar: AppBar(title: Text(_title(l))),
              body: ErrorView.forError(context, _c.error, onRetry: _c.load),
            );
          case PracticeStatus.empty:
            return Scaffold(
              appBar: AppBar(title: Text(_title(l))),
              body: EmptyView(
                icon: Icons.quiz_outlined,
                message: l.learnNoQuestionsTitle,
                subtitle: l.learnNoQuestionsBody,
                action: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(onPressed: () => popOrHome(context), child: Text(l.learnBack)),
                    if (widget.launch.kind != PracticeKind.quick)
                      FilledButton(
                        onPressed: () => context.pushReplacement(RoutePaths.quickTest),
                        child: Text(l.learnQuickPracticeTitle),
                      ),
                  ],
                ),
              ),
            );
          case PracticeStatus.running:
          case PracticeStatus.finished:
            return _running(context, l);
        }
      },
    );
  }

  Widget _running(BuildContext context, AppLocalizations l) {
    final q = _c.current;
    return PopScope(
      canPop: !_c.hasProgress || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => _c.hasProgress ? _confirmExit() : popOrHome(context),
          ),
          title: Text(
            l.learnQuestionProgress(_c.index + 1, _c.total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: ElapsedTimer(startedAt: _c.startedAt, semanticsLabel: l.learnElapsedTime),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _c.total == 0 ? 0 : (_c.index + (_c.isAnswered ? 1 : 0)) / _c.total,
              minHeight: 4,
              backgroundColor: context.tokens.surfaceMuted,
            ),
          ),
        ),
        body: q == null
            ? const SizedBox.shrink()
            : _QuestionBody(
                key: ValueKey(q.id),
                question: q,
                answer: _c.currentAnswer,
                scroll: _scroll,
                onSelect: (id) {
                  HapticFeedback.selectionClick();
                  _c.select(id);
                  _scrollToFeedback();
                },
              ),
        bottomNavigationBar: q == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter(context),
                    AppSpacing.sm,
                    AppSpacing.gutter(context),
                    AppSpacing.md,
                  ),
                  child: _c.isAnswered
                      ? FilledButton(
                          onPressed: _onNext,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTouch)),
                          child: Text(_c.isLast ? l.learnFinish : l.learnNext),
                        )
                      : OutlinedButton.icon(
                          onPressed: _onSkip,
                          icon: const Icon(Icons.skip_next_outlined),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTouch)),
                          label: Text(_c.isLast ? l.learnSkipAndFinish : l.learnSkip),
                        ),
                ),
              ),
      ),
    );
  }

  void _scrollToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.of(context, AppMotion.slow),
        curve: AppMotion.standard,
      );
    });
  }

  void _onSkip() {
    final wasLast = _c.isLast;
    _c.skip();
    if (wasLast) _complete();
    _resetScroll();
  }

  void _onNext() {
    final wasLast = _c.isLast;
    _c.next();
    if (wasLast) _complete();
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _confirmExit() async {
    final l = AppLocalizations.of(context)!;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.learnExitTitle),
        content: Text(l.learnExitBody(_c.answeredCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ExitChoice.discard),
            child: Text(l.learnExitDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ExitChoice.stay),
            child: Text(l.learnExitContinue),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _ExitChoice.finish),
            child: Text(l.learnExitFinish),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _ExitChoice.finish:
        _c.finish();
        _complete();
        break;
      case _ExitChoice.discard:
        setState(() => _leaving = true);
        // Pop after the rebuild so PopScope already allows it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) popOrHome(context);
        });
        break;
      case _ExitChoice.stay:
      case null:
        break;
    }
  }

  /// Finish flow: record in the background, then show results immediately.
  void _complete() {
    final result = _c.finish();
    final uid = _uidSafe();
    Future<ActivityResult?>? xp;
    if (uid != null && result.answers.isNotEmpty) {
      xp = LearningActivityService.instance.recordPracticeSession(uid, result);
      if (widget.launch.kind == PracticeKind.mistakes) {
        for (final a in result.answers.where((a) => a.isCorrect)) {
          final item = widget.launch.mistakes[a.question.id];
          if (item != null) MistakesService.instance.applyReview(uid, item, correct: true);
        }
      }
    }
    PracticeSessionStore.instance.put(result, xp);
    setState(() => _leaving = true);
    context.pushReplacement(RoutePaths.quizResults, extra: {
      'totalQuestions': result.total,
      'correctAnswers': result.correct,
      'totalTimeSeconds': result.elapsedSeconds,
    });
  }
}

enum _ExitChoice { stay, discard, finish }

class _QuestionBody extends StatelessWidget {
  final QuestionModel question;
  final PracticeAnswer? answer;
  final ScrollController scroll;
  final ValueChanged<String> onSelect;

  const _QuestionBody({
    super.key,
    required this.question,
    required this.answer,
    required this.scroll,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final gutter = AppSpacing.gutter(context);
    final answered = answer != null && !answer!.isSkipped;

    return SingleChildScrollView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _DifficultyChip(difficulty: question.difficulty),
          ),
          const SizedBox(height: AppSpacing.md),
          MathMarkdown(
            question.getStem(lang),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ContentImage(source: question.imageUrl!),
          ],
          const SizedBox(height: AppSpacing.xl),
          for (final o in question.options) ...[
            _OptionTile(
              option: o,
              lang: lang,
              state: _stateFor(o),
              onTap: answered ? null : () => onSelect(o.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (answered) ...[
            const SizedBox(height: AppSpacing.md),
            _FeedbackPanel(question: question, answer: answer!, lang: lang, l: l),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(OptionModel o) {
    final a = answer;
    if (a == null || a.isSkipped) return _OptionState.idle;
    if (o.id == question.correctAnswer) return _OptionState.correct;
    if (o.id == a.selectedOptionId) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  final OptionModel option;
  final String lang;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({required this.option, required this.lang, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color border, Color badgeBg, Color badgeFg) = switch (state) {
      _OptionState.correct => (t.successContainer, t.success, t.success, scheme.surface),
      _OptionState.wrong => (t.dangerContainer, t.danger, t.danger, scheme.surface),
      _OptionState.dimmed => (scheme.surface, t.border, t.surfaceMuted, t.textTertiary),
      _OptionState.idle => (scheme.surface, t.borderStrong, t.surfaceMuted, scheme.onSurface),
    };
    final l = AppLocalizations.of(context)!;
    final semantic = switch (state) {
      _OptionState.correct => l.learnCorrect,
      _OptionState.wrong => l.learnWrong,
      _ => null,
    };
    return Semantics(
      button: onTap != null,
      label: semantic,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: border, width: state == _OptionState.idle ? 1 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                    child: state == _OptionState.correct || state == _OptionState.wrong
                        ? Icon(state == _OptionState.correct ? Icons.check : Icons.close, size: 16, color: badgeFg)
                        : Text(option.id, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: badgeFg)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: MathMarkdown(
                        option.getText(lang),
                        compact: true,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: state == _OptionState.dimmed ? t.textSecondary : scheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  final QuestionModel question;
  final PracticeAnswer answer;
  final String lang;
  final AppLocalizations l;

  const _FeedbackPanel({required this.question, required this.answer, required this.lang, required this.l});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final ok = answer.isCorrect;
    final explanation = question.getExplanation(lang);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? t.success : t.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ok ? l.learnCorrect : l.learnWrong,
                  style: theme.textTheme.titleMedium?.copyWith(color: ok ? t.success : t.danger),
                ),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l.learnCorrectAnswerIs(question.correctAnswer), style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(l.learnExplanation, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (explanation.trim().isEmpty)
            Text(l.learnNoExplanation, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary))
          else
            MathMarkdown(explanation, style: theme.textTheme.bodyMedium),
          if (!ok) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => unawaited(context.push(RoutePaths.tutor, extra: {
                  'questionId': question.id,
                  'mode': 'explain_mistake',
                })),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(l.learnAskTutor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final int difficulty;
  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final (String label, Color fg, Color bg) = switch (QuestionModel.normalizeDifficulty(difficulty)) {
      1 => (l.learnDifficultyEasy, t.success, t.successContainer),
      2 => (l.learnDifficultyMedium, t.warning, t.warningContainer),
      _ => (l.learnDifficultyHard, t.danger, t.dangerContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
