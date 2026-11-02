import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/models/user_progress_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/subject_icon.dart';

class _SubjectData {
  final SubjectModel? subject;
  final List<LessonModel> lessons;
  final UserProgressModel? progress;
  const _SubjectData(this.subject, this.lessons, this.progress);
}

class SubjectDetailPage extends StatefulWidget {
  final String subjectId;

  const SubjectDetailPage({
    super.key,
    required this.subjectId,
  });

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  final _data = FirebaseDataService();
  late Future<_SubjectData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SubjectData> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final r = await Future.wait<Object?>([
      _data.getSubjectById(widget.subjectId),
      _data.getLessonsBySubject(widget.subjectId),
      uid == null ? Future.value(null) : _data.getUserProgress(uid),
    ]);
    return _SubjectData(r[0] as SubjectModel?, r[1] as List<LessonModel>, r[2] as UserProgressModel?);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<_SubjectData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(), body: LoadingView(message: l.learnLoadingSubject));
        }
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: ErrorView.forError(context, snap.error, onRetry: _retry));
        }
        final d = snap.data!;
        if (d.subject == null && d.lessons.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyView(
              icon: Icons.search_off,
              message: l.learnSubjectNotFound,
              subtitle: l.learnSubjectNotFoundBody,
            ),
          );
        }
        return _body(context, l, d);
      },
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, _SubjectData d) {
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final t = context.tokens;
    final gutter = AppSpacing.gutter(context);
    final subject = d.subject;
    final title = subject?.getTitle(lang) ?? widget.subjectId;
    final description = subject?.getDescription(lang) ?? '';
    final color = SubjectColors.of(widget.subjectId);
    final completed = {...?d.progress?.completedLessons};
    final doneCount = d.lessons.where((x) => completed.contains(x.id)).length;
    final tally = d.progress?.practiceBySubject[widget.subjectId];
    final acc = tally?.accuracy;

    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: () async {
          _retry();
          await _future.catchError((Object _) => const _SubjectData(null, [], null));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadii.mdAll),
                  child: SubjectIcon(icon: subject?.icon ?? '', subjectId: widget.subjectId, size: 30, color: color),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineSmall),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: _Stat(label: l.learnStatLessonsDone, value: '$doneCount/${d.lessons.length}')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Stat(
                    label: l.learnStatPracticeAccuracy,
                    value: acc == null ? '—' : '${(acc * 100).round()}%',
                    hint: tally == null || tally.answered == 0 ? null : l.learnAnswersCount(tally.answered),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.quizById(widget.subjectId)),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTouch)),
              icon: const Icon(Icons.quiz_outlined),
              label: Text(l.learnPracticeSubject),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(l.learnLessonsHeading, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (d.lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(l.learnNoLessonsYet, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
              )
            else
              for (var i = 0; i < d.lessons.length; i++)
                _LessonTile(index: i, lesson: d.lessons[i], done: completed.contains(d.lessons[i].id), lang: lang),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  const _Stat({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(borderRadius: AppRadii.mdAll, border: Border.all(color: context.tokens.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final int index;
  final LessonModel lesson;
  final bool done;
  final String lang;
  const _LessonTile({required this.index, required this.lesson, required this.done, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? t.successContainer : theme.colorScheme.primaryContainer,
          foregroundColor: done ? t.success : theme.colorScheme.onPrimaryContainer,
          child: done ? const Icon(Icons.check, size: 18) : Text('${index + 1}'),
        ),
        title: Text(lesson.getTitle(lang), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.learnMinutes(lesson.estimatedTimeMinutes)),
        trailing: Icon(Icons.chevron_right, color: t.textTertiary),
        onTap: () => context.push(RoutePaths.lessonById(lesson.id)),
      ),
    );
  }
}
