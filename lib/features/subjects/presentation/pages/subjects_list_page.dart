import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/subject_icon.dart';
import '../../../../shared/widgets/subject_search_delegate.dart';
import '../../../gamification/gamification_routes.dart';

/// Learn tab root: real subjects from Firestore plus practice shortcuts.
class SubjectsListPage extends StatefulWidget {
  const SubjectsListPage({super.key});

  @override
  State<SubjectsListPage> createState() => _SubjectsListPageState();
}

class _SubjectsListPageState extends State<SubjectsListPage> {
  late Future<List<SubjectModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseDataService().getSubjects();
  }

  Future<void> _reload() async {
    final f = FirebaseDataService().getSubjects();
    setState(() => _future = f);
    await f.catchError((Object _) => <SubjectModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.learnSubjectsTitle),
        actions: [
          FutureBuilder<List<SubjectModel>>(
            future: _future,
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.search),
              tooltip: l.learnSearchSubjects,
              onPressed: snap.hasData
                  ? () async {
                      final picked = await showSearch(
                        context: context,
                        delegate: SubjectSearchDelegate(subjects: snap.data!),
                      );
                      if (picked != null && context.mounted) {
                        context.push(RoutePaths.subject(picked.id));
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<SubjectModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return LoadingView(message: l.learnLoadingSubjects);
          }
          if (snap.hasError) return ErrorView.forError(context, snap.error, onRetry: _reload);
          final subjects = snap.data ?? const <SubjectModel>[];
          final gutter = AppSpacing.gutter(context);
          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.sm),
                  sliver: const SliverToBoxAdapter(child: _PracticeShortcuts()),
                ),
                if (subjects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.school_outlined,
                      message: l.learnNoSubjectsTitle,
                      subtitle: l.learnNoSubjectsBody,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xxxl),
                    sliver: SliverList.separated(
                      itemCount: subjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _SubjectTile(subject: subjects[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PracticeShortcuts extends StatelessWidget {
  const _PracticeShortcuts();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = [
      (Icons.bolt_outlined, l.learnQuickPracticeTitle, RoutePaths.quickTest),
      (Icons.replay_outlined, l.learnMistakesTitle, kMistakesPath),
      (Icons.today_outlined, l.learnDailyLessonTitle, RoutePaths.dailyLesson),
      (Icons.leaderboard_outlined, l.learnLeaderboardTitle, RoutePaths.leaderboard),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (icon, label, path) in items)
          ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: () => context.push(path),
          ),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  const _SubjectTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final theme = Theme.of(context);
    final t = context.tokens;
    final color = SubjectColors.of(subject.id);
    final description = subject.getDescription(lang);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RoutePaths.subject(subject.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadii.smAll),
                child: SubjectIcon(icon: subject.icon, subjectId: subject.id, size: 26, color: color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.getTitle(lang), style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(description, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    if (subject.totalLessons > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(l.learnLessonsCount(subject.totalLessons), style: theme.textTheme.labelSmall),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
