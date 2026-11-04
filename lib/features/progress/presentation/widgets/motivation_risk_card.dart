import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/motivation_risk.dart';

String _pct(double v, String locale) {
  final rounded = (v * 10).round() / 10;
  final text = rounded == rounded.roundToDouble() ? rounded.toStringAsFixed(0) : rounded.toStringAsFixed(1);
  return locale == 'en' ? text : text.replaceAll('.', ',');
}

/// Motivation-risk nudge (ARCHITECTURE §9.5): what happened, why it matters
/// and one concrete next step. [compact] is the home-screen variant (one
/// reason, one action).
class MotivationRiskCard extends StatelessWidget {
  const MotivationRiskCard({super.key, required this.risk, this.compact = false});

  final MotivationRisk risk;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final reviewId = risk.latestAttemptId;
    // The declining exam is the more specific problem: lead with it.
    final declining = risk.isDeclining && reviewId != null;

    final reasonLines = <(String, String)>[
      if (declining)
        (
          l.socialRiskDeclining(_pct(risk.previousPercent!, locale), _pct(risk.latestPercent!, locale)),
          l.socialRiskDecliningWhy,
        ),
      if (risk.isInactive) (l.socialRiskInactive(risk.inactiveDays ?? MotivationRules.inactiveDays), l.socialRiskInactiveWhy),
    ];
    final step = declining ? l.socialRiskStepReview : l.socialRiskStepPractice;
    final (actionLabel, actionPath) = declining
        ? (l.socialRiskActionReview, RoutePaths.examReviewFor(reviewId))
        : (l.socialRiskActionPractice, RoutePaths.quickTest);

    final shown = compact ? reasonLines.take(1) : reasonLines;
    return Container(
      key: const ValueKey('motivation_risk_card'),
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.warningContainer,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down_rounded, color: t.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l.socialRiskTitle, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (what, why) in shown) ...[
            Text(what, style: theme.textTheme.bodyMedium),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(why, style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (!compact) Text(step, style: theme.textTheme.titleSmall),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
              onPressed: () => context.push(actionPath),
              icon: Icon(declining ? Icons.fact_check_outlined : Icons.bolt_outlined, size: 18),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
