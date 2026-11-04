import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/models/practice_session_model.dart';
import '../../../../shared/models/user_progress_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/services/learning_activity_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../quiz/domain/practice_launch.dart';
import 'lesson_content_view.dart';

class _LessonData {
  final LessonModel lesson;
  final Set<String> completed;
  final List<LessonModel> siblings;
  const _LessonData(this.lesson, this.completed, this.siblings);
}

/// Full lesson experience shared by LessonPage and DailyLessonPage:
/// content, media, practice, completion (CMS-30) and the next lesson.
class LessonScreen extends StatefulWidget {
  final Future<LessonModel?> Function() loadLesson;
  final String? titleOverride;

  const LessonScreen({super.key, required this.loadLesson, this.titleOverride});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _data = FirebaseDataService();
  final _scroll = ScrollController();
  final _readProgress = ValueNotifier<double>(0);
  late Future<_LessonData?> _future;
  bool _completed = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _future = _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _readProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _readProgress.value = max <= 0 ? 1 : (_scroll.position.pixels / max).clamp(0.0, 1.0);
  }

  Future<_LessonData?> _load() async {
    final lesson = await widget.loadLesson();
    if (lesson == null) return null;
    final uid = _uid;
    final results = await Future.wait<Object?>([
      uid == null ? Future.value(null) : _data.getUserProgress(uid),
      lesson.subjectId.isEmpty
          ? Future.value(const <LessonModel>[])
          : _data.getLessonsBySubject(lesson.subjectId).catchError((Object _) => const <LessonModel>[]),
    ]);
    final progress = results[0] as UserProgressModel?;
    final completed = <String>{...?progress?.completedLessons};
    _completed = completed.contains(lesson.id);
    return _LessonData(lesson, completed, results[1] as List<LessonModel>);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<_LessonData?>(
      future: _future,
      builder: (context, snap) {
        final title = widget.titleOverride ?? l.learnLessonTitle;
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: Text(title)), body: LoadingView(message: l.learnLoadingLesson));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: ErrorView.forError(context, snap.error, onRetry: _retry),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: EmptyView(
              icon: Icons.menu_book_outlined,
              message: l.learnLessonNotFound,
              subtitle: l.learnLessonNotFoundBody,
            ),
          );
        }
        return _content(context, l, data);
      },
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, _LessonData d) {
    final lang = contentLanguageOf(context);
    final lesson = d.lesson;
    final theme = Theme.of(context);
    final t = context.tokens;
    final gutter = AppSpacing.gutter(context);
    final next = _nextLesson(d);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? lesson.getTitle(lang), maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: ValueListenableBuilder<double>(
            valueListenable: _readProgress,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: t.surfaceMuted),
          ),
        ),
      ),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
        children: [
          if (widget.titleOverride != null) ...[
            Text(lesson.getTitle(lang), style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (lesson.order > 0) _Pill(text: l.learnLessonNumber(lesson.order)),
              _Pill(icon: Icons.schedule, text: l.learnMinutes(lesson.estimatedTimeMinutes)),
              if (_completed) _Pill(icon: Icons.check_circle, text: l.learnLessonDone, color: t.success),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          LessonContentView(lesson: lesson),
          if (lesson.videoUrl != null || lesson.pdfUrl != null) ...[
            Text(l.learnLessonMaterials, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (lesson.videoUrl != null)
              _LinkTile(icon: Icons.play_circle_outline, label: l.learnLessonWatchVideo, url: lesson.videoUrl!),
            if (lesson.pdfUrl != null)
              _LinkTile(icon: Icons.picture_as_pdf_outlined, label: l.learnLessonOpenPdf, url: lesson.pdfUrl!),
            const SizedBox(height: AppSpacing.xl),
          ],
          _PracticeCard(lesson: lesson),
          const SizedBox(height: AppSpacing.lg),
          if (_completed)
            OutlinedButton.icon(
              onPressed: null,
              icon: Icon(Icons.check_circle, color: t.success),
              label: Text(l.learnLessonDone),
            )
          else
            FilledButton.icon(
              onPressed: () => _markCompleted(lesson),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTouch)),
              icon: const Icon(Icons.check),
              label: Text(l.learnLessonMarkDone),
            ),
          const SizedBox(height: AppSpacing.xl),
          if (next != null)
            _NextLessonCard(lesson: next, lang: lang)
          else if (d.siblings.length > 1 && _completed)
            Text(
              l.learnLessonAllDone,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  /// Next lesson in subject order, preferring ones not completed yet.
  LessonModel? _nextLesson(_LessonData d) {
    final list = d.siblings;
    final i = list.indexWhere((x) => x.id == d.lesson.id);
    final done = {...d.completed, if (_completed) d.lesson.id};
    for (var k = (i < 0 ? 0 : i + 1); k < list.length; k++) {
      if (!done.contains(list[k].id)) return list[k];
    }
    for (final x in list) {
      if (x.id != d.lesson.id && !done.contains(x.id)) return x;
    }
    return null;
  }

  void _markCompleted(LessonModel lesson) {
    final l = AppLocalizations.of(context)!;
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.learnSignInToSave)));
      return;
    }
    setState(() => _completed = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l.learnLessonCompletedToast)));
    // Non-blocking: progress is cached locally; XP comes from the server.
    unawaited(LearningActivityService.instance.recordLessonCompleted(uid, lesson.id).then((r) {
      if (r != null && r.xpAwarded > 0 && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l.learnXpAwarded(r.xpAwarded))));
      }
    }));
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color? color;
  const _Pill({this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: AppSpacing.xs)],
          Flexible(child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c))),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  const _LinkTile({required this.icon, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final uri = Uri.tryParse(url);
          var ok = false;
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
            try {
              ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              ok = false;
            }
          }
          if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.learnLinkFailed)));
        },
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final LessonModel lesson;
  const _PracticeCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ids = lesson.practiceQuestionIds;
    final canSubject = lesson.subjectId.isNotEmpty;
    if (ids.isEmpty && !canSubject) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.learnLessonPracticeTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ids.isNotEmpty ? l.learnLessonPracticeBody(ids.length) : l.learnLessonPracticeSubjectBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              final subject = lesson.subjectId.isNotEmpty ? lesson.subjectId : 'lesson';
              context.push(
                RoutePaths.quizById(subject),
                extra: ids.isNotEmpty
                    ? PracticeLaunch(
                        kind: PracticeKind.lesson,
                        subjectId: lesson.subjectId,
                        questionIds: ids,
                        refId: lesson.id,
                      )
                    : PracticeLaunch.subject(subject),
              );
            },
            icon: const Icon(Icons.quiz_outlined),
            label: Text(l.learnStartPractice),
          ),
        ],
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  final LessonModel lesson;
  final String lang;
  const _NextLessonCard({required this.lesson, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        leading: Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
        title: Text(l.learnNextLesson, style: theme.textTheme.labelMedium),
        subtitle: Text(lesson.getTitle(lang), style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => context.pushReplacement(RoutePaths.lessonById(lesson.id)),
      ),
    );
  }
}
