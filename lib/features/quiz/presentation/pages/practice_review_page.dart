import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/practice_session_model.dart';
import '../../../../shared/widgets/math_markdown.dart';

/// Answer-by-answer review of a finished practice session (GAM-10).
class PracticeReviewPage extends StatelessWidget {
  final PracticeSessionResult result;

  const PracticeReviewPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.learnReviewAnswers)),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxxl),
        itemCount: result.answers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) => _ReviewCard(index: i, answer: result.answers[i]),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final PracticeAnswer answer;
  const _ReviewCard({required this.index, required this.answer});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final t = context.tokens;
    final q = answer.question;
    final (IconData icon, Color color, String status) = switch (answer.outcome) {
      PracticeOutcome.correct => (Icons.check_circle, t.success, l.learnCorrect),
      PracticeOutcome.wrong => (Icons.cancel, t.danger, l.learnWrong),
      PracticeOutcome.skipped => (Icons.skip_next, t.textSecondary, l.learnStatSkipped),
    };
    String optionText(String? id) {
      if (id == null) return '—';
      final o = q.options.where((o) => o.id == id);
      return o.isEmpty ? id : '$id. ${o.first.getText(lang)}';
    }

    final explanation = q.getExplanation(lang);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${l.learnQuestionNumber(index + 1)} · $status',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MathMarkdown(q.getStem(lang), style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          if (!answer.isSkipped)
            _line(context, l.learnYourAnswer, optionText(answer.selectedOptionId)),
          if (!answer.isCorrect)
            _line(context, l.learnRightAnswer, optionText(q.correctAnswer)),
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            MathMarkdown(explanation, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
          ],
          if (!answer.isCorrect) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(RoutePaths.tutor, extra: {
                  'questionId': q.id,
                  'mode': 'explain_mistake',
                }),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(l.learnAskTutor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: theme.textTheme.labelMedium),
          TextSpan(text: value, style: theme.textTheme.bodyMedium),
        ]),
      ),
    );
  }
}
