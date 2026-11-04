import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/content/topic_names.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/utils/bishkek_time.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/leaderboard_model.dart';
import '../../../../shared/models/region_model.dart';
import '../../../../shared/services/leaderboard_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../onboarding/data/kg_regions_provider.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/domain/league_boards.dart';
import '../../../social/presentation/widgets/friends_league.dart';
import '../../domain/subject_boards.dart';

/// Leaderboards precomputed by the server (GAM-17): weekly (ISO week in
/// Asia/Bishkek), all time, the student's region this week, friends this
/// week, and weekly per subject. Top 50 by XP plus the viewer's own
/// position.
///
/// What counts (D10): weekly, all-time, region and friends boards get all
/// server-awarded XP (mock exams plus the capped lesson/practice XP); subject
/// boards get mock exam XP only, keyed by the blueprint subject id
/// ([SubjectBoards]). Region boards (`region_{id}_weekly_*`, ARCHITECTURE
/// §9.3) exist for students with `users/{uid}.region`; the friends league is
/// assembled on the client from the friends' weekly entries.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.learnLeaderboardTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.learnLeaderboardWeekly),
              Tab(text: l.learnLeaderboardAllTime),
              Tab(text: l.socialLeagueRegion),
              Tab(text: l.socialLeagueFriends),
              Tab(text: l.learnLeaderboardBySubject),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BoardView(boardId: BishkekTime.weeklyBoardId(DateTime.now())),
            const _BoardView(boardId: BishkekTime.allTimeBoardId),
            const _RegionBoard(),
            const _KeepAlive(child: FriendsLeagueView()),
            const _SubjectBoards(),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab's state (and its loaded data) while switching tabs.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// This week's board of the student's oblast, or an explanation of how to
/// set a region.
class _RegionBoard extends ConsumerWidget {
  const _RegionBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profile = ref.watch(socialProfileProvider);
    final regions = ref.watch(kgRegionsProvider);
    if ((profile.isLoading && !profile.hasValue) || (regions.isLoading && !regions.hasValue)) {
      return LoadingView(message: l.loading);
    }
    if (profile.hasError && !profile.hasValue) {
      return ErrorView.forError(context, profile.error, onRetry: () => ref.invalidate(socialProfileProvider));
    }
    final list = regions.valueOrNull ?? const <RegionData>[];
    final stored = profile.valueOrNull?.regionOblast;
    final regionId = LeagueBoards.regionIdFor(stored, list);
    if (regionId == null) {
      return EmptyView(
        icon: Icons.place_outlined,
        message: l.socialRegionEmptyTitle,
        subtitle: l.socialRegionEmptyBody,
        action: OutlinedButton(
          onPressed: () => context.go(RoutePaths.profile),
          child: Text(l.socialRegionOpenProfile),
        ),
      );
    }
    final name = list.firstWhere((r) => r.id == regionId).label(contentLanguageOf(context));
    return _BoardView(
      key: ValueKey('region-$regionId'),
      boardId: LeagueBoards.regionWeeklyBoardId(regionId, DateTime.now()),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: Text(
          l.socialRegionHint(name),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
        ),
      ),
    );
  }
}

class _BoardView extends StatefulWidget {
  final String boardId;
  final Widget? header;

  /// Subject boards count mock-exam XP only, so their hints differ.
  final bool examOnly;
  const _BoardView({super.key, required this.boardId, this.header, this.examOnly = false});

  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> with AutomaticKeepAliveClientMixin {
  late Future<LeaderboardSnapshot> _future;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = LeaderboardService.instance.load(widget.boardId, uid: _uid);
  }

  @override
  void didUpdateWidget(covariant _BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _future = LeaderboardService.instance.load(widget.boardId, uid: _uid);
    }
  }

  Future<void> _reload() async {
    final f = LeaderboardService.instance.load(widget.boardId, uid: _uid);
    setState(() => _future = f);
    await f.catchError((Object _) => LeaderboardSnapshot(boardId: widget.boardId, top: const []));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<LeaderboardSnapshot>(
      future: _future,
      builder: (context, snap) {
        Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = LoadingView(message: l.loading);
        } else if (snap.hasError) {
          body = ErrorView.forError(context, snap.error, onRetry: _reload);
        } else {
          final page = snap.data!;
          body = page.top.isEmpty
              ? EmptyView(
                  icon: Icons.leaderboard_outlined,
                  message: l.learnLeaderboardEmpty,
                  subtitle: widget.examOnly ? l.learnLeaderboardSubjectEmptyBody : l.learnLeaderboardEmptyBody,
                )
              : _list(context, l, page);
        }
        if (widget.header == null) return body;
        return Column(children: [widget.header!, Expanded(child: body)]);
      },
    );
  }

  Widget _list(BuildContext context, AppLocalizations l, LeaderboardSnapshot page) {
    final uid = _uid;
    final mineInTop = page.top.any((e) => e.uid == uid);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: page.top.length,
              itemBuilder: (context, i) => _EntryTile(rank: i + 1, entry: page.top[i], isMe: page.top[i].uid == uid),
            ),
          ),
        ),
        if (!mineInTop)
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tokens.border))),
              child: page.mine == null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        widget.examOnly ? l.learnLeaderboardSubjectNotRanked : l.learnLeaderboardNotRanked,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : _EntryTile(rank: page.myRank, entry: page.mine!, isMe: true),
            ),
          ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final int? rank;
  final LeaderboardEntry entry;
  final bool isMe;
  const _EntryTile({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final name = entry.displayName.trim().isEmpty ? l.learnLeaderboardAnonymous : entry.displayName;
    return ListTile(
      tileColor: isMe ? theme.colorScheme.primaryContainer : null,
      leading: SizedBox(
        width: 40,
        child: Text(
          rank == null ? '—' : '$rank',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: (rank ?? 99) <= 3 ? t.xp : null),
        ),
      ),
      title: Text(isMe ? l.learnLeaderboardYou(name) : name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(l.learnXpShort(entry.xp), style: theme.textTheme.labelLarge),
    );
  }
}

class _SubjectBoards extends ConsumerStatefulWidget {
  const _SubjectBoards();

  @override
  ConsumerState<_SubjectBoards> createState() => _SubjectBoardsState();
}

class _SubjectBoardsState extends ConsumerState<_SubjectBoards> with AutomaticKeepAliveClientMixin {
  String _selected = SubjectBoards.ids.first;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final names = ref.watch(topicNamesProvider).valueOrNull ?? TopicNames.empty;
    final theme = Theme.of(context);
    final picker = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Row(
            children: [
              for (final id in SubjectBoards.ids)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    key: ValueKey('subject-board-$id'),
                    label: Text(SubjectBoards.label(id, names: names, lang: lang, mainTestLabel: l.examCatalogMainTitle)),
                    selected: id == _selected,
                    onSelected: (_) => setState(() => _selected = id),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
          child: Text(
            l.learnLeaderboardSubjectHint,
            style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
          ),
        ),
      ],
    );
    return _BoardView(
      key: ValueKey(_selected),
      boardId: SubjectBoards.weeklyBoardId(_selected, DateTime.now()),
      header: picker,
      examOnly: true,
    );
  }
}
