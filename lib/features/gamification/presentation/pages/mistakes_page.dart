import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/mistake_model.dart';
import '../../../../shared/models/practice_session_model.dart';
import '../../../../shared/models/question_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/services/mistakes_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../quiz/domain/practice_launch.dart';

/// "Ошибки и повторение" (GAM-10): wrong answers from practice and exams,
/// scheduled 1 → 3 → 7 → 14 → 30 days. Practice items can be re-practised
/// and marked resolved; exam items open the attempt review.
class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});

  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<List<MistakeItem>>? _stream;
  late final Future<List<SubjectModel>> _subjects;
  final Map<String, QuestionModel?> _questions = {};
  final Set<String> _requested = {};
  bool _dueOnly = true;
  String? _subject;
  int _attempt = 0;

  static const _batchLimit = 20;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) _stream = MistakesService.instance.watchOpen(uid);
    _subjects = FirebaseDataService().getSubjects().catchError((Object _) => <SubjectModel>[]);
  }

  /// Loads stems for practice items that are visible and not loaded yet.
  void _ensureQuestions(Iterable<MistakeItem> items) {
    final ids = items
        .where((m) => m.source == MistakeSource.practice && !_requested.contains(m.questionId))
        .map((m) => m.questionId)
        .take(30)
        .toList();
    if (ids.isEmpty) return;
    _requested.addAll(ids);
    FirebaseDataService().getQuestionsByIds(ids).then((qs) {
      if (!mounted) return;
      setState(() {
        for (final id in ids) {
          _questions[id] = null;
        }
        for (final q in qs) {
          _questions[q.id] = q;
        }
      });
    }).catchError((Object _) {
      _requested.removeAll(ids); // retry on next build
    });
  }

  void _practice(List<MistakeItem> items) {
    final practice = items.where((m) => m.clientWritable).take(_batchLimit).toList();
    if (practice.isEmpty) return;
    final subject = _subject ?? (practice.map((m) => m.subjectId).toSet().length == 1 ? practice.first.subjectId : '');
    context.push(
      RoutePaths.quizById(subject.isEmpty ? 'mistakes' : subject),
      extra: PracticeLaunch(
        kind: PracticeKind.mistakes,
        subjectId: subject.isEmpty ? null : subject,
        questionIds: [for (final m in practice) m.questionId],
        mistakes: {for (final m in practice) m.questionId: m},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stream = _stream;
    return Scaffold(
      appBar: AppBar(title: Text(l.learnMistakesTitle)),
      body: stream == null
          ? EmptyView(
              icon: Icons.lock_outline,
              message: l.learnSignInToSave,
              action: FilledButton(onPressed: () => context.go(RoutePaths.login), child: Text(l.learnSignIn)),
            )
          : FutureBuilder<List<SubjectModel>>(
              future: _subjects,
              builder: (context, subjSnap) => StreamBuilder<List<MistakeItem>>(
                key: ValueKey(_attempt),
                stream: stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return ErrorView.forError(context, snap.error, onRetry: () {
                      setState(() {
                        _attempt++;
                        _stream = MistakesService.instance.watchOpen(_uid!);
                      });
                    });
                  }
                  if (!snap.hasData) return LoadingView(message: l.loading);
                  return _content(context, l, snap.data!, subjSnap.data ?? const []);
                },
              ),
            ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, List<MistakeItem> all, List<SubjectModel> subjects) {
    final now = DateTime.now();
    final lang = contentLanguageOf(context);
    final titles = {for (final s in subjects) s.id: s.getTitle(lang)};
    if (all.isEmpty) {
      return EmptyView(
        icon: Icons.task_alt,
        message: l.learnMistakesEmptyTitle,
        subtitle: l.learnMistakesEmptyBody,
        action: FilledButton(onPressed: () => context.push(RoutePaths.quickTest), child: Text(l.learnQuickPracticeTitle)),
      );
    }
    final subjectIds = all.map((m) => m.subjectId).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final filtered = all.where((m) {
      if (_dueOnly && !m.isDue(now)) return false;
      if (_subject != null && m.subjectId != _subject) return false;
      return true;
    }).toList();
    final dueCount = all.where((m) => m.isDue(now)).length;
    _ensureQuestions(filtered.take(40));
    final gutter = AppSpacing.gutter(context);
    final practicable = filtered.where((m) => m.clientWritable).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xxxl),
      children: [
        Text(l.learnMistakesDueToday(dueCount), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l.learnMistakesSrsNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l.learnMistakesFilterDue)),
            ButtonSegment(value: false, label: Text(l.learnMistakesFilterAll)),
          ],
          selected: {_dueOnly},
          onSelectionChanged: (v) => setState(() => _dueOnly = v.first),
        ),
        if (subjectIds.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                label: Text(l.learnMistakesAllSubjects),
                selected: _subject == null,
                onSelected: (_) => setState(() => _subject = null),
              ),
              for (final s in subjectIds)
                ChoiceChip(
                  label: Text(titles[s] ?? s),
                  selected: _subject == s,
                  onSelected: (_) => setState(() => _subject = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (practicable > 0)
          FilledButton.icon(
            onPressed: () => _practice(filtered),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTouch)),
            icon: const Icon(Icons.replay),
            label: Text(l.learnMistakesPracticeN(practicable > _batchLimit ? _batchLimit : practicable)),
          ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              l.learnMistakesNothingDue,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
            ),
          )
        else
          for (final m in filtered)
            _MistakeTile(
              item: m,
              question: _questions[m.questionId],
              subjectTitle: titles[m.subjectId] ?? m.subjectId,
              onPractice: () => _practice([m]),
              onResolve: () => MistakesService.instance.markResolved(_uid!, m),
            ),
      ],
    );
  }
}

class _MistakeTile extends StatelessWidget {
  final MistakeItem item;
  final QuestionModel? question;
  final String subjectTitle;
  final VoidCallback onPractice;
  final VoidCallback onResolve;

  const _MistakeTile({
    required this.item,
    required this.question,
    required this.subjectTitle,
    required this.onPractice,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = contentLanguageOf(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final exam = item.source == MistakeSource.exam;
    final stem = question?.getStem(lang).replaceAll(RegExp(r'[*$#`]'), '').replaceAll('\n', ' ').trim();
    final title = exam
        ? l.learnMistakeFromExam
        : (stem == null || stem.isEmpty ? l.learnMistakeQuestion : stem);
    final next = item.nextReviewAt;
    final when = next == null || !next.isAfter(DateTime.now())
        ? l.learnMistakeReviewToday
        : l.learnMistakeReviewOn(DateFormat.MMMd(locale).format(next.toLocal()));
    final subtitle = [
      if (subjectTitle.isNotEmpty) subjectTitle,
      l.learnMistakeWrongCount(item.wrongCount),
      when,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(exam ? Icons.assignment_outlined : Icons.quiz_outlined, color: theme.colorScheme.primary),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: exam
            ? (item.attemptId == null
                ? null
                : TextButton(
                    onPressed: () => context.push(RoutePaths.examReviewFor(item.attemptId!)),
                    child: Text(l.learnMistakeOpenReview),
                  ))
            : PopupMenuButton<String>(
                tooltip: l.learnMore,
                onSelected: (v) => v == 'practice' ? onPractice() : onResolve(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'practice', child: Text(l.learnMistakePractice)),
                  PopupMenuItem(value: 'resolve', child: Text(l.learnMistakeResolve)),
                ],
              ),
        onTap: exam
            ? (item.attemptId == null ? null : () => context.push(RoutePaths.examReviewFor(item.attemptId!)))
            : onPractice,
      ),
    );
  }
}
