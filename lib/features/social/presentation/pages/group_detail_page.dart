import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../application/social_providers.dart';
import '../../domain/social_failure.dart';
import '../../domain/social_models.dart';
import '../social_messages.dart';
import '../widgets/assignment_editor.dart';
import '../widgets/league_entry_tile.dart';
import '../widgets/social_widgets.dart';

/// Where an assignment opens: the lesson, a practice (subject or quick) or
/// the exam variant's intro page.
String assignmentTargetPath(GroupAssignment a) => switch (a.kind) {
      AssignmentKind.lesson => RoutePaths.lessonById(a.refId),
      AssignmentKind.practice =>
        a.refId.isEmpty ? RoutePaths.quickTest : RoutePaths.quizById(a.refId),
      AssignmentKind.examVariant => RoutePaths.examIntroFor(a.refId),
    };

/// One group (RoutePaths.groupDetail): homework, members and the weekly group
/// league. The owner adds/deletes assignments, sees each member's status and
/// can remove members; a member marks their own assignment as done.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final group = ref.watch(groupProvider(groupId));
    final notAvailable = Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.group_off_outlined,
        message: l.socialGroupNotFound,
        action: FilledButton(
          onPressed: () => context.go(RoutePaths.groups),
          child: Text(l.socialGroupsTitle),
        ),
      ),
    );
    return group.when(
      skipLoadingOnReload: true,
      loading: () => Scaffold(appBar: AppBar(), body: LoadingView(message: l.loading)),
      // Removed from the group (or it was deleted): the rules deny the read.
      error: (e, _) => SocialFailure.from(e).kind == SocialFailureKind.permissionDenied
          ? notAvailable
          : Scaffold(
              appBar: AppBar(),
              body: ErrorView(
                message: l.socialErrorMessage(e, SocialAction.other),
                onRetry: () => ref.invalidate(groupProvider(groupId)),
              ),
            ),
      data: (g) => g == null ? notAvailable : _GroupScaffold(group: g),
    );
  }
}

class _GroupScaffold extends ConsumerWidget {
  const _GroupScaffold({required this.group});

  final StudyGroup group;

  Future<void> _leave(BuildContext context, WidgetRef ref, bool isOwner) async {
    final l = AppLocalizations.of(context)!;
    if (isOwner && group.memberCount > 1) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l.socialGroupOwnerCannotLeave),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.socialDone))],
        ),
      );
      return;
    }
    final ok = await confirmSocialAction(
      context,
      message: l.socialGroupLeaveConfirm(group.name),
      confirmLabel: l.socialGroupLeave,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).groupLeave(group.id);
      if (!context.mounted) return;
      ref.invalidate(myGroupsProvider);
      showSocialSnack(context, l.socialGroupLeft);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RoutePaths.groups);
      }
    } catch (e) {
      if (context.mounted) showSocialSnack(context, l.socialErrorMessage(e, SocialAction.other));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isOwner = group.isOwner(ref.watch(socialUidProvider));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<String>(
              key: const ValueKey('group_menu'),
              tooltip: l.socialGroupMore,
              onSelected: (_) => _leave(context, ref, isOwner),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'leave', child: Text(l.socialGroupLeave)),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.socialGroupTabAssignments),
              Tab(text: l.socialGroupTabMembers),
              Tab(text: l.socialGroupTabRating),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (group.joinCode.isNotEmpty) _JoinCodeBar(code: group.joinCode),
            Expanded(
              child: TabBarView(
                children: [
                  _AssignmentsTab(group: group, isOwner: isOwner),
                  _MembersTab(group: group, isOwner: isOwner),
                  _RatingTab(groupId: group.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinCodeBar extends StatelessWidget {
  const _JoinCodeBar({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.surfaceMuted,
        border: Border(bottom: BorderSide(color: context.tokens.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.socialGroupJoinCode(code),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: l.socialInviteCopy,
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () => copyWithSnack(context, code, l.socialInviteCopied),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- assignments

class _AssignmentsTab extends ConsumerWidget {
  const _AssignmentsTab({required this.group, required this.isOwner});

  final StudyGroup group;
  final bool isOwner;

  Future<void> _add(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final created = await showAssignmentEditor(context, groupId: group.id);
    if (created == true && context.mounted) showSocialSnack(context, l.socialAssignmentCreated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    final assignments = ref.watch(groupAssignmentsProvider(group.id));
    final addButton = isOwner
        ? Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FilledButton.icon(
              key: const ValueKey('assignment_add'),
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.socialAssignmentAdd),
            ),
          )
        : null;
    return assignments.when(
      skipLoadingOnReload: true,
      loading: () => LoadingView(message: l.loading),
      error: (e, _) => ErrorView(
        message: l.socialErrorMessage(e, SocialAction.other),
        onRetry: () => ref.invalidate(groupAssignmentsProvider(group.id)),
      ),
      data: (list) => ListView(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
        children: [
          if (addButton != null) addButton,
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 40, color: context.tokens.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  Text(l.socialAssignmentsEmpty,
                      style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                  if (isOwner) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SocialMuted(l.socialAssignmentsEmptyOwner, textAlign: TextAlign.center),
                  ],
                ],
              ),
            )
          else
            for (final a in list) ...[
              _AssignmentCard(group: group, assignment: a, isOwner: isOwner),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

IconData _kindIcon(AssignmentKind k) => switch (k) {
      AssignmentKind.lesson => Icons.menu_book_outlined,
      AssignmentKind.practice => Icons.bolt_outlined,
      AssignmentKind.examVariant => Icons.assignment_outlined,
    };

String assignmentKindLabel(AppLocalizations l, AssignmentKind k) => switch (k) {
      AssignmentKind.lesson => l.socialAssignmentKindLesson,
      AssignmentKind.practice => l.socialAssignmentKindPractice,
      AssignmentKind.examVariant => l.socialAssignmentKindExam,
    };

class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({required this.group, required this.assignment, required this.isOwner});

  final StudyGroup group;
  final GroupAssignment assignment;
  final bool isOwner;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmSocialAction(
      context,
      message: l.socialAssignmentDeleteConfirm(assignment.title),
      confirmLabel: l.socialRemove,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).deleteAssignment(group.id, assignment.id);
      if (context.mounted) showSocialSnack(context, l.socialAssignmentDeleted);
    } catch (e) {
      if (context.mounted) showSocialSnack(context, l.socialErrorMessage(e, SocialAction.other));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final now = ref.watch(socialClockProvider)();
    final a = assignment;
    final due = a.dueAt == null ? null : l.socialAssignmentDue(socialDate(context, a.dueAt));
    return SocialCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Icon(_kindIcon(a.kind), color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      [assignmentKindLabel(l, a.kind), if (due != null) due].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  key: ValueKey('assignment_delete_${a.id}'),
                  tooltip: l.socialAssignmentDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context, ref),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (isOwner)
            _OwnerStatus(group: group, assignment: a, overdue: a.isOverdue(now))
          else
            _MemberStatus(group: group, assignment: a, overdue: a.isOverdue(now)),
        ],
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.assignment});

  final GroupAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: () => context.push(assignmentTargetPath(assignment)),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: Text(l.socialAssignmentOpen),
    );
  }
}

class _OverdueLabel extends StatelessWidget {
  const _OverdueLabel();

  @override
  Widget build(BuildContext context) => Text(
        AppLocalizations.of(context)!.socialAssignmentOverdue,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.tokens.danger),
      );
}

/// A member: open + "Отметить выполненным" (own submission only).
class _MemberStatus extends ConsumerStatefulWidget {
  const _MemberStatus({required this.group, required this.assignment, required this.overdue});

  final StudyGroup group;
  final GroupAssignment assignment;
  final bool overdue;

  @override
  ConsumerState<_MemberStatus> createState() => _MemberStatusState();
}

class _MemberStatusState extends ConsumerState<_MemberStatus> {
  bool _busy = false;

  AssignmentKey get _key => (groupId: widget.group.id, assignmentId: widget.assignment.id);

  Future<void> _markDone() async {
    final l = AppLocalizations.of(context)!;
    final uid = ref.read(socialUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialRepositoryProvider).markAssignmentDone(widget.group.id, widget.assignment.id, uid);
      if (mounted) showSocialSnack(context, l.socialAssignmentMarkedDone);
    } catch (e) {
      if (mounted) showSocialSnack(context, l.socialErrorMessage(e, SocialAction.other));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final mine = ref.watch(mySubmissionProvider(_key));
    // The document exists once marked (done_at may still be a pending
    // server timestamp locally).
    final done = mine.valueOrNull != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _OpenButton(assignment: widget.assignment),
        if (mine.isLoading && !mine.hasValue)
          const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: SocialButtonProgress())
        else if (done)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: t.success),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    mine.valueOrNull?.doneAt == null
                        ? l.socialAssignmentDone
                        : l.socialAssignmentDoneOn(socialDate(context, mine.valueOrNull!.doneAt)),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.success),
                  ),
                ),
              ],
            ),
          )
        else ...[
          OutlinedButton.icon(
            key: ValueKey('assignment_done_${widget.assignment.id}'),
            onPressed: _busy ? null : _markDone,
            icon: _busy ? const SocialButtonProgress() : const Icon(Icons.check_rounded, size: 18),
            label: Text(l.socialAssignmentMarkDone),
          ),
          if (widget.overdue)
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm), child: _OverdueLabel()),
        ],
      ],
    );
  }
}

/// The owner: "Выполнили: X из Y" and each member's status.
class _OwnerStatus extends ConsumerWidget {
  const _OwnerStatus({required this.group, required this.assignment, required this.overdue});

  final StudyGroup group;
  final GroupAssignment assignment;
  final bool overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final key = (groupId: group.id, assignmentId: assignment.id);
    final subs = ref.watch(assignmentSubmissionsProvider(key));
    final members = ref.watch(groupMembersProvider(group.id));
    final students = (members.valueOrNull ?? const <GroupMember>[])
        .where((m) => m.role != GroupRole.owner)
        .toList();
    final byUid = {for (final s in subs.valueOrNull ?? const <AssignmentSubmission>[]) s.uid: s};
    final done = students.where((m) => byUid.containsKey(m.uid)).length;
    final loading = (subs.isLoading && !subs.hasValue) || (members.isLoading && !members.hasValue);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('assignment_status_${assignment.id}'),
        tilePadding: const EdgeInsets.only(right: AppSpacing.sm),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            _OpenButton(assignment: assignment),
            if (loading)
              const SocialButtonProgress()
            else if (subs.hasError || members.hasError)
              Text(l.socialErrorGeneric, style: theme.textTheme.bodySmall?.copyWith(color: t.danger))
            else
              Text(l.socialAssignmentProgress(done, students.length), style: theme.textTheme.labelLarge),
            if (overdue && done < students.length) const _OverdueLabel(),
          ],
        ),
        children: [
          if (students.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SocialMuted(l.socialGroupRatingEmpty),
            )
          else
            for (final m in students)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  byUid.containsKey(m.uid) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: byUid.containsKey(m.uid) ? t.success : t.textTertiary,
                ),
                title: Text(
                  m.displayName.trim().isEmpty ? l.socialAnonymousStudent : m.displayName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  byUid[m.uid] == null
                      ? l.socialAssignmentNotDone
                      : (byUid[m.uid]!.doneAt == null
                          ? l.socialAssignmentDone
                          : socialDate(context, byUid[m.uid]!.doneAt)),
                  style: theme.textTheme.labelSmall,
                ),
              ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- members

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.group, required this.isOwner});

  final StudyGroup group;
  final bool isOwner;

  Future<void> _remove(BuildContext context, WidgetRef ref, GroupMember m, String name) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmSocialAction(
      context,
      message: l.socialMemberRemoveConfirm(name),
      confirmLabel: l.socialRemove,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).groupRemoveMember(group.id, m.uid);
      if (context.mounted) showSocialSnack(context, l.socialMemberRemoved);
    } catch (e) {
      if (context.mounted) showSocialSnack(context, l.socialErrorMessage(e, SocialAction.other));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final members = ref.watch(groupMembersProvider(group.id));
    final myUid = ref.watch(socialUidProvider);
    return members.when(
      skipLoadingOnReload: true,
      loading: () => LoadingView(message: l.loading),
      error: (e, _) => ErrorView(
        message: l.socialErrorMessage(e, SocialAction.other),
        onRetry: () => ref.invalidate(groupMembersProvider(group.id)),
      ),
      data: (list) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final m = list[i];
          final name = m.displayName.trim().isEmpty ? l.socialAnonymousStudent : m.displayName.trim();
          final isMe = m.uid == myUid;
          return ListTile(
            key: ValueKey('member_${m.uid}'),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                name.characters.first.toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            title: Text(isMe ? l.learnLeaderboardYou(name) : name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: m.role == GroupRole.owner ? Text(l.socialGroupsOwnerBadge) : null,
            trailing: isOwner && m.role != GroupRole.owner && !isMe
                ? IconButton(
                    key: ValueKey('member_remove_${m.uid}'),
                    tooltip: l.socialMemberRemove,
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () => _remove(context, ref, m, name),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ rating

class _RatingTab extends ConsumerWidget {
  const _RatingTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final board = ref.watch(groupLeaderboardProvider(groupId));
    final uid = ref.watch(socialUidProvider);
    final gutter = AppSpacing.gutter(context);
    Future<void> refresh() async {
      ref.invalidate(groupLeaderboardProvider(groupId));
      try {
        await ref.read(groupLeaderboardProvider(groupId).future);
      } catch (_) {}
    }

    return board.when(
      skipLoadingOnReload: true,
      loading: () => LoadingView(message: l.loading),
      error: (e, _) => ErrorView(message: l.socialErrorMessage(e, SocialAction.other), onRetry: refresh),
      data: (page) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.sm),
              child: SocialMuted(l.socialGroupRatingHint),
            ),
            if (page.top.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter, vertical: AppSpacing.xxl),
                child: Text(l.socialGroupRatingEmpty,
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              )
            else
              for (var i = 0; i < page.top.length; i++)
                LeagueEntryTile(rank: i + 1, entry: page.top[i], isMe: page.top[i].uid == uid),
            if (page.top.isNotEmpty && !page.top.any((e) => e.uid == uid))
              page.mine == null
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 0),
                      child: SocialMuted(l.socialGroupRatingNotRanked),
                    )
                  : LeagueEntryTile(rank: page.myRank, entry: page.mine!, isMe: true),
          ],
        ),
      ),
    );
  }
}
