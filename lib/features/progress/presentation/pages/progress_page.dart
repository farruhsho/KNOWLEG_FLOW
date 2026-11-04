import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/content/topic_names.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/exam_attempt_summary.dart';
import '../../../../shared/models/user_progress_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gamification/gamification_routes.dart';
import '../../data/progress_repository.dart';
import '../../domain/recommendations.dart';

/// Progress built only from real data (GAM-08/09): server stats, practice
/// aggregates, completed exam attempts and the mistakes queue. No invented
/// trends, no "AI forecast", no ORT score from practice.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

/// Display labels for ids shown on the progress page (UX-02): learning
/// subject titles and blueprint section titles first, then the bundled
/// curriculum names ([TopicNames]); never a raw id.
class ProgressLabels {
  const ProgressLabels({
    required this.lang,
    required this.names,
    this.subjectTitles = const {},
    this.sectionTitles = const {},
  });

  final String lang;
  final TopicNames names;
  final Map<String, String> subjectTitles;
  final Map<String, Map<String, String>> sectionTitles;

  String subject(String? id) {
    if (id == null || id.isEmpty) return '';
    final t = subjectTitles[id];
    return (t != null && t.trim().isNotEmpty) ? t : names.label(id, lang);
  }

  String section(String? id) {
    if (id == null || id.isEmpty) return '';
    final t = sectionTitles[id];
    if (t != null) {
      final v = pickLocalized(t, lang);
      if (v.trim().isNotEmpty) return v;
    }
    return subject(id);
  }

  String topic(String? id) => (id == null || id.isEmpty) ? '' : names.label(id, lang);
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  final _repo = ProgressRepository();
  Future<ProgressSnapshot>? _future;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) _future = _repo.load(uid);
  }

  Future<void> _reload() async {
    final uid = _uid;
    if (uid == null) return;
    final f = _repo.load(uid);
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // The FutureBuilder shows the error state with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final future = _future;
    final names = ref.watch(topicNamesProvider).valueOrNull ?? TopicNames.empty;
    return Scaffold(
      appBar: AppBar(title: Text(l.learnProgressTitle)),
      body: future == null
          ? EmptyView(
              icon: Icons.lock_outline,
              message: l.learnSignInToSave,
              action: FilledButton(onPressed: () => context.go(RoutePaths.login), child: Text(l.learnSignIn)),
            )
          : FutureBuilder<ProgressSnapshot>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return LoadingView(message: l.loading);
                if (snap.hasError) return ErrorView.forError(context, snap.error, onRetry: _reload);
                return RefreshIndicator(onRefresh: _reload, child: _content(context, l, snap.data!, names));
              },
            ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, ProgressSnapshot s, TopicNames names) {
    final gutter = AppSpacing.gutter(context);
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final p = s.progress;
    final stats = s.stats;
    final completed = s.completedAttempts;
    final labels = ProgressLabels(
      lang: lang,
      names: names,
      subjectTitles: {for (final x in s.subjects) x.id: x.getTitle(lang)},
      sectionTitles: s.sectionTitles,
    );
    String sectionTitle(String id) => labels.section(id);
    String blueprintTitle(String id) =>
        s.blueprintTitles[id] != null ? pickLocalized(s.blueprintTitles[id]!, lang) : id;

    final recs = RecommendationEngine.build(progress: p, attempts: s.attempts ?? const [], dueMistakes: s.dueMistakes);
    final practiceAcc = p?.practiceAccuracy;
    final minutes = ((p?.practiceSeconds ?? 0) / 60).round();

    final children = <Widget>[
      _Grid(items: [
        (l.learnStatLevel, stats == null ? '—' : '${stats.level}', l.learnXpTotal(stats?.xp ?? 0)),
        (l.learnStatStreak, '${stats?.liveStreak(DateTime.now()) ?? 0}', l.learnStatBestStreak(stats?.bestStreak ?? 0)),
        (l.learnStatAnswered, '${p?.practiceAnswered ?? 0}', l.learnStatSessions(p?.practiceSessions ?? 0)),
        (l.learnStatPracticeAccuracy, practiceAcc == null ? '—' : '${(practiceAcc * 100).round()}%', l.learnStatPracticeOnly),
        (l.learnStatPracticeTime, l.learnDurationMinutes(minutes), l.learnStatPracticeTimeHint),
        (l.learnStatExams, '${completed.length}', l.learnStatLessonsCompleted(p?.completedLessons.length ?? 0)),
      ]),
      const SizedBox(height: AppSpacing.xl),
      _Heading(l.learnRecommendationsTitle),
      if (recs.isEmpty)
        _Muted(l.learnRecommendationsNone)
      else
        for (final r in recs)
          _RecommendationCard(
            rec: r,
            title: _recTitle(l, r, labels),
            body: _recBody(l, r),
            // Reviewing mistakes changes the due count: refresh on return.
            onReturn: _reload,
          ),
      const SizedBox(height: AppSpacing.xl),
      _Heading(l.learnExamResultsTitle),
      if (s.attempts == null)
        _Muted(l.learnExamHistoryUnavailable)
      else if (completed.isEmpty)
        _Muted(l.learnExamHistoryEmpty)
      else ...[
        ..._bestByDirection(completed).entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(blueprintTitle(e.key)),
              trailing: Text('${e.value.toStringAsFixed(1)}%', style: theme.textTheme.titleMedium),
              subtitle: Text(l.learnBestResult),
            )),
        _Muted(l.learnExamResultUnofficial),
        const SizedBox(height: AppSpacing.md),
        Text(l.learnExamHistoryTitle, style: theme.textTheme.titleSmall),
        for (final a in completed.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(blueprintTitle(a.blueprintId), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_date(context, a.completedAt)),
            trailing: Text('${a.correct}/${a.total} · ${(a.percent ?? 0).round()}%'),
            onTap: () => context.push(RoutePaths.examResultFor(a.id)),
          ),
        TextButton(onPressed: () => context.push(RoutePaths.examHistory), child: Text(l.learnExamHistoryAll)),
        ..._sectionBars(context, l, completed, sectionTitle),
      ],
      const SizedBox(height: AppSpacing.xl),
      _Heading(l.learnPracticeBySubjectTitle),
      if ((p?.practiceBySubject ?? const {}).isEmpty)
        _Muted(l.learnPracticeBySubjectEmpty)
      else
        for (final e in (p!.practiceBySubject.entries.toList()..sort((a, b) => b.value.answered.compareTo(a.value.answered))))
          _AccuracyBar(label: labels.subject(e.key), tally: e.value),
      const SizedBox(height: AppSpacing.xl),
      _Heading(l.learnWeakTopicsTitle),
      ..._weakTopics(context, l, p, labels),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
      children: [
        if (s.isEmpty) ...[
          EmptyView(
            icon: Icons.insights_outlined,
            message: l.learnProgressEmptyTitle,
            subtitle: l.learnProgressEmptyBody,
            action: FilledButton(onPressed: () => context.push(RoutePaths.quickTest), child: Text(l.learnQuickPracticeTitle)),
          ),
        ] else
          ...children,
      ],
    );
  }

  static Map<String, double> _bestByDirection(List<ExamAttemptSummary> attempts) {
    final best = <String, double>{};
    for (final a in attempts) {
      final p = a.percent;
      if (p == null) continue;
      if ((best[a.blueprintId] ?? -1) < p) best[a.blueprintId] = p;
    }
    return best;
  }

  List<Widget> _sectionBars(
    BuildContext context,
    AppLocalizations l,
    List<ExamAttemptSummary> attempts,
    String Function(String) title,
  ) {
    final totals = <String, (int, int)>{};
    for (final a in attempts) {
      for (final s in a.sections) {
        final t = totals[s.id] ?? (0, 0);
        totals[s.id] = (t.$1 + s.correct, t.$2 + s.total);
      }
    }
    if (totals.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      Text(l.learnExamSectionsTitle, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      for (final e in totals.entries)
        _AccuracyBar(label: title(e.key), tally: PracticeTally(answered: e.value.$2, correct: e.value.$1)),
    ];
  }

  List<Widget> _weakTopics(BuildContext context, AppLocalizations l, UserProgressModel? p, ProgressLabels labels) {
    final topics = (p?.practiceByTopic.entries ?? const <MapEntry<String, PracticeTally>>[])
        .where((e) => e.value.answered >= RecommendationEngine.minTopicAnswers)
        .toList()
      ..sort((a, b) => (a.value.accuracy ?? 1).compareTo(b.value.accuracy ?? 1));
    if (topics.isEmpty) return [_Muted(l.learnWeakTopicsEmpty)];
    return [
      for (final e in topics.take(5)) _AccuracyBar(label: labels.topic(e.key), tally: e.value),
      TextButton(onPressed: () => context.push(kMistakesPath), child: Text(l.learnOpenMistakes)),
    ];
  }

  String _date(BuildContext context, DateTime? d) {
    if (d == null) return '';
    return DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(d.toLocal());
  }

  String _recTitle(AppLocalizations l, Recommendation r, ProgressLabels labels) {
    switch (r.kind) {
      case RecommendationKind.dueMistakes:
        return l.learnRecDueMistakesTitle(r.count ?? 0);
      case RecommendationKind.noExam:
        return l.learnRecNoExamTitle;
      case RecommendationKind.weakSubject:
        return l.learnRecWeakSubjectTitle(labels.subject(r.refId));
      case RecommendationKind.weakExamSection:
        return l.learnRecWeakSectionTitle(labels.section(r.refId));
      case RecommendationKind.weakTopic:
        return l.learnRecWeakTopicTitle(labels.topic(r.refId));
      case RecommendationKind.moreData:
        return l.learnRecMoreDataTitle(r.count ?? 0);
    }
  }

  String _recBody(AppLocalizations l, Recommendation r) {
    switch (r.kind) {
      case RecommendationKind.dueMistakes:
        return l.learnRecDueMistakesWhy;
      case RecommendationKind.noExam:
        return l.learnRecNoExamWhy;
      case RecommendationKind.weakSubject:
        return l.learnRecWeakSubjectWhy(r.percent ?? 0, r.count ?? 0);
      case RecommendationKind.weakExamSection:
        return l.learnRecWeakSectionWhy(r.percent ?? 0);
      case RecommendationKind.weakTopic:
        return l.learnRecWeakTopicWhy(r.percent ?? 0);
      case RecommendationKind.moreData:
        return l.learnRecMoreDataWhy;
    }
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _Muted extends StatelessWidget {
  final String text;
  const _Muted(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

class _Grid extends StatelessWidget {
  final List<(String, String, String)> items;
  const _Grid({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 2;
      final w = (c.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (label, value, hint) in items)
            Container(
              width: w,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(borderRadius: AppRadii.mdAll, border: Border.all(color: t.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(value, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(hint, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _AccuracyBar extends StatelessWidget {
  final String label;
  final PracticeTally tally;
  const _AccuracyBar({required this.label, required this.tally});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final acc = tally.accuracy ?? 0;
    final color = acc >= 0.75 ? t.success : (acc >= 0.5 ? t.warning : t.danger);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${(acc * 100).round()}% · ${l.learnAnswersCount(tally.answered)}', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(value: acc, minHeight: 6, color: color, backgroundColor: t.surfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final String title;
  final String body;
  final VoidCallback? onReturn;
  const _RecommendationCard({required this.rec, required this.title, required this.body, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Future<void> openMistakes() async {
      await context.push(kMistakesPath);
      onReturn?.call();
    }

    final (String label, VoidCallback onTap) = switch (rec.kind) {
      RecommendationKind.dueMistakes => (l.learnOpenMistakes, openMistakes),
      RecommendationKind.noExam => (l.learnRecOpenExams, () => context.go(RoutePaths.exams)),
      RecommendationKind.weakSubject => (l.learnStartPractice, () => context.push(RoutePaths.quizById(rec.refId ?? ''))),
      RecommendationKind.weakExamSection => (l.learnStartPractice, () => context.push(RoutePaths.quizById(rec.refId ?? ''))),
      RecommendationKind.weakTopic => (l.learnOpenMistakes, openMistakes),
      RecommendationKind.moreData => (l.learnQuickPracticeTitle, () => context.push(RoutePaths.quickTest)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: theme.textTheme.bodyMedium),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onTap, child: Text(label)),
          ),
        ],
      ),
    );
  }
}
