import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/utils/bishkek_time.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/leaderboard_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/services/leaderboard_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';

/// Leaderboards precomputed by the server (GAM-17): weekly (ISO week in
/// Asia/Bishkek), all time, and weekly per subject. Top 50 by XP plus the
/// viewer's own position.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.learnLeaderboardTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.learnLeaderboardWeekly),
              Tab(text: l.learnLeaderboardAllTime),
              Tab(text: l.learnLeaderboardBySubject),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BoardView(boardId: BishkekTime.weeklyBoardId(DateTime.now())),
            const _BoardView(boardId: BishkekTime.allTimeBoardId),
            const _SubjectBoards(),
          ],
        ),
      ),
    );
  }
}

class _BoardView extends StatefulWidget {
  final String boardId;
  final Widget? header;
  const _BoardView({super.key, required this.boardId, this.header});

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
              ? EmptyView(icon: Icons.leaderboard_outlined, message: l.learnLeaderboardEmpty, subtitle: l.learnLeaderboardEmptyBody)
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
                      child: Text(l.learnLeaderboardNotRanked, style: Theme.of(context).textTheme.bodySmall),
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

class _SubjectBoards extends StatefulWidget {
  const _SubjectBoards();

  @override
  State<_SubjectBoards> createState() => _SubjectBoardsState();
}

class _SubjectBoardsState extends State<_SubjectBoards> with AutomaticKeepAliveClientMixin {
  late Future<List<SubjectModel>> _subjects;
  String? _selected;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subjects = FirebaseDataService().getSubjects();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    return FutureBuilder<List<SubjectModel>>(
      future: _subjects,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return LoadingView(message: l.loading);
        if (snap.hasError) {
          return ErrorView.forError(context, snap.error, onRetry: () {
            setState(() => _subjects = FirebaseDataService().getSubjects());
          });
        }
        final subjects = snap.data ?? const <SubjectModel>[];
        if (subjects.isEmpty) return EmptyView(message: l.learnNoSubjectsTitle);
        final selected = _selected ?? subjects.first.id;
        final picker = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Row(
            children: [
              for (final s in subjects)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(s.getTitle(lang)),
                    selected: s.id == selected,
                    onSelected: (_) => setState(() => _selected = s.id),
                  ),
                ),
            ],
          ),
        );
        return _BoardView(
          key: ValueKey(selected),
          boardId: BishkekTime.subjectWeeklyBoardId(selected, DateTime.now()),
          header: picker,
        );
      },
    );
  }
}
