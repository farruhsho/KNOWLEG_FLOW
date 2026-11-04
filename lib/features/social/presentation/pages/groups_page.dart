import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../application/social_providers.dart';
import '../../domain/social_codes.dart';
import '../../domain/social_models.dart';
import '../social_messages.dart';
import '../widgets/code_entry_dialog.dart';
import '../widgets/social_widgets.dart';

/// Longest group name the client sends to `groupCreate`.
const int kGroupNameMaxLength = 60;

/// "Группы" (RoutePaths.groups, ARCHITECTURE §9.3): the student's groups
/// (`users/{uid}.group_ids`), join by code and create. Membership changes go
/// through the callables only.
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final signedIn = ref.watch(socialUidProvider) != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.socialGroupsTitle)),
      body: !signedIn
          ? EmptyView(
              icon: Icons.lock_outline,
              message: l.socialSignInRequired,
              action: FilledButton(onPressed: () => context.go(RoutePaths.login), child: Text(l.socialSignIn)),
            )
          : const _GroupsBody(),
    );
  }
}

class _GroupsBody extends ConsumerWidget {
  const _GroupsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final groups = ref.watch(myGroupsProvider);
    final uid = ref.watch(socialUidProvider);
    return groups.when(
      skipLoadingOnReload: true,
      loading: () => LoadingView(message: l.loading),
      error: (e, _) => ErrorView(
        message: l.socialErrorMessage(e, SocialAction.other),
        onRetry: () => ref.invalidate(myGroupsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyView(
            icon: Icons.groups_outlined,
            message: l.socialGroupsEmptyTitle,
            subtitle: l.socialGroupsEmptyBody,
            action: const _GroupActions(),
          );
        }
        final gutter = AppSpacing.gutter(context);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myGroupsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.huge),
            children: [
              for (final g in list) ...[
                _GroupTile(group: g, isOwner: g.isOwner(uid)),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _GroupActions(),
              const SizedBox(height: AppSpacing.md),
              SocialMuted(l.socialGroupsLimitNote, textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.isOwner});

  final StudyGroup group;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('group_${group.id}'),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.groups_outlined, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(group.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [l.socialGroupsMembers(group.memberCount), if (isOwner) l.socialGroupsOwnerBadge].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(RoutePaths.groupById(group.id)),
      ),
    );
  }
}

/// "Вступить по коду" and "Создать группу".
class _GroupActions extends ConsumerWidget {
  const _GroupActions();

  // This widget sits in the empty state and, once a group exists, in the list:
  // joining or creating the first group rebuilds the page (users.group_ids
  // changes while the dialog is still open) and unmounts this widget. So
  // everything used after an await is captured up front from objects that
  // outlive it (router, navigator, messenger, provider container); a
  // `context.mounted` check here would silently drop the navigation.
  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(socialRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final groupId = await showCodeEntryDialog<String>(
      context,
      title: l.socialGroupJoinTitle,
      hint: l.socialGroupJoinHint,
      actionLabel: l.socialJoin,
      action: SocialAction.groupJoin,
      maxLength: SocialCodes.groupMaxLength,
      fieldKey: const ValueKey('group_code_field'),
      actionKey: const ValueKey('group_join_submit'),
      validate: (c) => SocialCodes.isGroupCode(c) ? null : l.socialErrorGroupCodeFormat,
      submit: repo.groupJoin,
    );
    if (groupId == null) return;
    container.invalidate(myGroupsProvider);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.socialGroupJoined), behavior: SnackBarBehavior.floating));
    router.push(RoutePaths.groupById(groupId));
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final created = await showDialog<GroupCreated>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (created == null || !navigator.mounted) return;
    container.invalidate(myGroupsProvider);
    final open = await showDialog<bool>(
      context: navigator.context,
      builder: (_) => _GroupCreatedDialog(created: created),
    );
    if (open == true) router.push(RoutePaths.groupById(created.groupId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          key: const ValueKey('groups_join'),
          onPressed: () => _join(context, ref),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(l.socialGroupsJoin),
        ),
        OutlinedButton.icon(
          key: const ValueKey('groups_create'),
          onPressed: () => _create(context, ref),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l.socialGroupsCreate),
        ),
      ],
    );
  }
}

class _CreateGroupDialog extends ConsumerStatefulWidget {
  const _CreateGroupDialog();

  @override
  ConsumerState<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<_CreateGroupDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final name = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty || name.length > kGroupNameMaxLength) {
      setState(() => _error = l.socialGroupNameInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref.read(socialRepositoryProvider).groupCreate(name);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.socialErrorMessage(e, SocialAction.groupCreate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.socialGroupCreateTitle),
      scrollable: true,
      content: TextField(
        key: const ValueKey('group_name_field'),
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        maxLength: kGroupNameMaxLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l.socialGroupNameLabel,
          hintText: l.socialGroupNameHint,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.socialCancel)),
        FilledButton(
          key: const ValueKey('group_create_submit'),
          onPressed: _busy ? null : _submit,
          child: _busy ? const SocialButtonProgress() : Text(l.socialCreate),
        ),
      ],
    );
  }
}

class _GroupCreatedDialog extends StatelessWidget {
  const _GroupCreatedDialog({required this.created});

  final GroupCreated created;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.check_circle_outline, color: context.tokens.success),
      title: Text(l.socialGroupCreatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.socialGroupCreatedBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            created.joinCode,
            key: const ValueKey('created_join_code'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton.icon(
              onPressed: () => copyWithSnack(context, created.joinCode, l.socialInviteCopied),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l.socialInviteCopy),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.socialDone)),
        FilledButton(
          key: const ValueKey('group_created_open'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.socialGroupOpen),
        ),
      ],
    );
  }
}
