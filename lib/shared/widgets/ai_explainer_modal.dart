import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/routes/route_paths.dart';
import '../../features/tutor/application/tutor_controller.dart';
import '../../features/tutor/domain/tutor_models.dart';
import '../../features/tutor/presentation/tutor_messages.dart';
import '../../features/tutor/presentation/widgets/tutor_markdown.dart';
import '../../l10n/app_localizations.dart';
import '../models/question_model.dart';

/// Explanation dialog shown after a practice answer.
///
/// The "why is it wrong?" part is answered by the server-side `aiTutor`
/// callable (mode `explain_mistake`) — this widget holds no model API key and
/// never calls an LLM directly (SEC-001 / CMS-03 / FB-26). The student can
/// also continue in the full tutor chat.
///
/// Public API (constructor and [show]) is unchanged.
class AIExplainerModal extends ConsumerStatefulWidget {
  final QuestionModel question;
  final String userAnswer;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;

  const AIExplainerModal({
    super.key,
    required this.question,
    required this.userAnswer,
    this.onRetry,
    this.onNext,
  });

  /// Show the AI Explainer Modal
  static Future<void> show(
    BuildContext context, {
    required QuestionModel question,
    required String userAnswer,
    VoidCallback? onRetry,
    VoidCallback? onNext,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog(
      context: context,
      builder: (context) => AIExplainerModal(
        question: question,
        userAnswer: userAnswer,
        onRetry: onRetry,
        onNext: onNext,
      ),
    );
  }

  @override
  ConsumerState<AIExplainerModal> createState() => _AIExplainerModalState();
}

/// Size budgets (UTF-16 code units) for [buildExplainPrompt].
const int explainPromptStemBudget = 600;
const int explainPromptOptionsBudget = 800;
const int explainPromptOptionMax = 150;
const int explainPromptAnswerBudget = 100;

/// The "explain my mistake" message for [question], always within
/// [TutorRequest.maxMessageChars] (the server rejects longer messages).
///
/// The stem is cut to [explainPromptStemBudget]; all options share
/// [explainPromptOptionsBudget] (at most [explainPromptOptionMax] each); the
/// final text is clipped as a last resort.
String buildExplainPrompt(
  AppLocalizations l10n, {
  required QuestionModel question,
  required String languageCode,
  required String userAnswer,
}) {
  String pick(Map<String, String> m) =>
      m[languageCode] ?? m['ru'] ?? (m.isEmpty ? '' : m.values.first);

  final stemText = question.stem.isEmpty ? '' : question.getStem(languageCode).trim();
  final stem = clipTutorText(stemText, explainPromptStemBudget, ellipsis: true);

  final count = question.options.isEmpty ? 1 : question.options.length;
  final perOption = (explainPromptOptionsBudget ~/ count).clamp(20, explainPromptOptionMax);
  final options = question.options
      .map((o) => '${o.id}) ${clipTutorText(pick(o.text).trim(), perOption, ellipsis: true)}')
      .join('\n');

  final answer = userAnswer.trim().isEmpty
      ? l10n.tutorExplainerNoAnswer
      : clipTutorText(userAnswer.trim(), explainPromptAnswerBudget, ellipsis: true);
  final correct = clipTutorText(question.correctAnswer.trim(), explainPromptAnswerBudget, ellipsis: true);

  return clipTutorText(
    l10n.tutorExplainPrompt(stem, options, answer, correct),
    TutorRequest.maxMessageChars,
    ellipsis: true,
  );
}

enum _AiPhase { idle, loading, done, failed }

class _AIExplainerModalState extends ConsumerState<AIExplainerModal> {
  _AiPhase _phase = _AiPhase.idle;
  String? _reply;
  int? _remaining;
  TutorFailure? _failure;

  String get _lang => Localizations.localeOf(context).languageCode;

  /// The `explain_mistake` message. It must fit the server's
  /// [TutorRequest.maxMessageChars] (D13), so the stem and options are cut to
  /// a budget: with a questionId the server adds the full question, options
  /// and reference answer itself, and the excerpt only anchors the request.
  String _prompt(AppLocalizations l10n) => buildExplainPrompt(
        l10n,
        question: widget.question,
        languageCode: _lang,
        userAnswer: widget.userAnswer,
      );

  String _stem() => widget.question.stem.isEmpty ? '' : widget.question.getStem(_lang);

  Future<void> _askAi() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _phase = _AiPhase.loading;
      _failure = null;
    });
    try {
      final reply = await ref.read(tutorApiProvider).ask(TutorRequest(
            mode: TutorMode.explainMistake,
            message: _prompt(l10n),
            language: tutorLanguageFor(_lang),
            questionId: widget.question.id.isEmpty ? null : widget.question.id,
          ));
      if (!mounted) return;
      setState(() {
        _phase = _AiPhase.done;
        _reply = reply.reply;
        _remaining = reply.remainingToday;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _AiPhase.failed;
        _failure = TutorFailure.from(e);
      });
    }
  }

  void _openChat() {
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.maybeOf(context);
    final extra = TutorArgs(
      questionId: widget.question.id.isEmpty ? null : widget.question.id,
      mode: TutorMode.explainMistake,
      prefill: _prompt(l10n),
    ).toExtra();
    Navigator.of(context).pop();
    router?.push(RoutePaths.tutor, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final q = widget.question;
    final isCorrect = widget.userAnswer == q.correctAnswer;
    final accent = isCorrect ? tokens.success : tokens.danger;
    final accentBg = isCorrect ? tokens.successContainer : tokens.dangerContainer;
    final explanation = q.getExplanation(_lang);
    final canOpenChat = GoRouter.maybeOf(context) != null;
    final aiAvailable = ref.watch(tutorAvailableProvider);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: accentBg, borderRadius: AppRadii.mdAll),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: accent, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCorrect ? l10n.tutorExplainerCorrect : l10n.tutorExplainerIncorrect,
                          style: theme.textTheme.titleLarge?.copyWith(color: accent),
                        ),
                        if (!isCorrect) ...[
                          Text(l10n.tutorExplainerCorrectAnswer(q.correctAnswer),
                              style: theme.textTheme.bodyMedium),
                          Text(
                            l10n.tutorExplainerYourAnswer(widget.userAnswer.trim().isEmpty
                                ? l10n.tutorExplainerNoAnswer
                                : widget.userAnswer),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.tutorExplainerClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (q.stem.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(color: tokens.surfaceMuted, borderRadius: AppRadii.mdAll),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TutorMarkdown(_stem(), style: theme.textTheme.bodyLarge),
                  ),
                ),
              if (explanation.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.tutorExplainerExplanation, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TutorMarkdown(explanation),
              ],
              if (!isCorrect) ...[
                const SizedBox(height: AppSpacing.lg),
                _AiSection(
                  available: aiAvailable,
                  phase: _phase,
                  reply: _reply,
                  remaining: _remaining,
                  failure: _failure,
                  onAsk: _askAi,
                  onOpenChat: canOpenChat ? _openChat : null,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (widget.onRetry != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onRetry?.call();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.tutorExplainerTryAgain),
                    ),
                  if (widget.onNext != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onNext?.call();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.tutorExplainerNext),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.available,
    required this.phase,
    required this.reply,
    required this.remaining,
    required this.failure,
    required this.onAsk,
    required this.onOpenChat,
  });

  /// False where `aiTutor` cannot be called (no App Check provider, D7).
  final bool available;
  final _AiPhase phase;
  final String? reply;
  final int? remaining;
  final TutorFailure? failure;
  final VoidCallback onAsk;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final blocked = failure?.blocksInput ?? false;

    if (!available) {
      return DecoratedBox(
        decoration: BoxDecoration(color: tokens.surfaceMuted, borderRadius: AppRadii.mdAll),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.tutorUnavailablePlatform, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology_alt_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.tutorExplainerAiTitle, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            switch (phase) {
              _AiPhase.idle => const SizedBox.shrink(),
              _AiPhase.loading => Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: Text(l10n.tutorThinking, style: theme.textTheme.bodySmall)),
                  ],
                ),
              _AiPhase.done => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionArea(child: TutorMarkdown(reply ?? '')),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.tutorDisclaimer, style: theme.textTheme.bodySmall),
                    if (remaining != null)
                      Text(l10n.tutorRemainingToday(remaining!), style: theme.textTheme.bodySmall),
                  ],
                ),
              _AiPhase.failed => Text(
                  l10n.tutorFailureMessage(failure ?? TutorFailure.unknown),
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.danger),
                ),
            },
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (phase == _AiPhase.idle || (phase == _AiPhase.failed && !blocked))
                  FilledButton.tonalIcon(
                    onPressed: onAsk,
                    icon: Icon(phase == _AiPhase.failed ? Icons.refresh : Icons.auto_awesome_outlined),
                    label: Text(phase == _AiPhase.failed ? l10n.tutorRetry : l10n.tutorExplainerAiButton),
                  ),
                if (onOpenChat != null && phase != _AiPhase.loading)
                  TextButton.icon(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.forum_outlined),
                    label: Text(l10n.tutorExplainerOpenChat),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
