import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../data/models/admin_records.dart';
import '../../data/repositories/people_repositories.dart' show UsersRepository;
import '../../domain/admin_role.dart';
import '../shell/admin_shell.dart' show adminRoleLabel;
import '../widgets/admin_widgets.dart';

/// Users (FB-22: one manager over the real snake_case `users` fields).
/// Paginated, searchable by email prefix.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _search = TextEditingController();
  String _prefix = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _prefix = v.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(usersPageProvider(_prefix));
    final notifier = ref.read(usersPageProvider(_prefix).notifier);
    return Column(
      children: [
        AdminFilterBar(children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _search,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.adminUsersSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
        ]),
        Expanded(
          child: PagedListBody<AdminUserRecord>(
            state: state,
            onLoadMore: notifier.loadMore,
            onRetry: notifier.retry,
            onRefresh: notifier.refresh,
            emptyMessage: l.adminUsersEmpty,
            itemBuilder: (context, u) => AdminListTile(
              title: u.name.isEmpty ? (u.email.isEmpty ? u.uid : u.email) : u.name,
              subtitle: '${u.email} · ${formatAdminDate(u.createdAt)}',
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              chips: [
                if (u.isBanned) AdminPill(l.adminUsersBanned, tone: AdminTone.danger),
                if (u.isPremium) AdminPill(l.adminUsersPremium, tone: AdminTone.success),
                if (u.legacyRole == 'admin') AdminPill(l.adminUsersLegacyAdmin, tone: AdminTone.info),
              ],
              onTap: () async {
                await context.push('/admin/users/${u.uid}');
                if (mounted) notifier.refresh();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One user: profile, entitlements and ledger; moderation (`moderate_users`),
/// role assignment and credit grants (super_admin, via callables).
class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(adminUserProvider(uid));
    return Scaffold(
      appBar: AppBar(title: Text(l.adminUserTitle)),
      body: AsyncBody<AdminUserRecord?>(
        value: user,
        onRetry: () => ref.invalidate(adminUserProvider(uid)),
        data: (u) => u == null ? AdminEmptyView(message: l.adminErrNotFound) : _UserDetail(user: u),
      ),
    );
  }
}

class _UserDetail extends ConsumerStatefulWidget {
  const _UserDetail({required this.user});
  final AdminUserRecord user;

  @override
  ConsumerState<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends ConsumerState<_UserDetail> {
  bool _busy = false;

  String get _uid => widget.user.uid;

  Future<void> _run(Future<void> Function() action, String done) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(adminUserProvider(_uid));
      ref.invalidate(adminEntitlementProvider(_uid));
      ref.invalidate(adminLedgerProvider(_uid));
      showAdminSnack(context, done);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBan() async {
    final l = AppLocalizations.of(context)!;
    final ban = !widget.user.isBanned;
    final String reason;
    if (ban) {
      final picked = await showDialog<String>(
        context: context,
        builder: (_) => const BanReasonDialog(),
      );
      if (picked == null) return;
      reason = picked;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.adminUserUnbanTitle),
          content: Text(l.adminUserUnbanBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.adminCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.adminUserUnban),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = '';
    }
    if (!mounted) return;
    await _run(
      () => ref.read(usersRepoProvider).setBanned(_uid, ban, actor: ref.read(adminActorProvider), reason: reason),
      l.adminSaved,
    );
  }

  Future<void> _togglePremium() async {
    final l = AppLocalizations.of(context)!;
    final premium = !widget.user.isPremium;
    final ok = await confirmAdminAction(
      context,
      title: premium ? l.adminUserPremiumOnTitle : l.adminUserPremiumOffTitle,
      message: premium ? l.adminUserPremiumOnBody : l.adminUserPremiumOffBody,
      confirmLabel: premium ? l.adminUserPremiumOn : l.adminUserPremiumOff,
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(usersRepoProvider).setPremium(_uid, premium, actor: ref.read(adminActorProvider)),
      l.adminSaved,
    );
  }

  Future<void> _setRole() async {
    final l = AppLocalizations.of(context)!;
    String? selected;
    final picked = await showDialog<({String? role})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.adminUserRoleTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.adminUserRoleBody),
                const SizedBox(height: AppSpacing.md),
                AdminDropdown<String>(
                  label: l.adminUserRole,
                  value: selected,
                  width: double.infinity,
                  allLabel: l.adminUserRoleNone,
                  items: {for (final r in AdminRole.values) r.wire: adminRoleLabel(l, r)},
                  onChanged: (v) => setLocal(() => selected = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, (role: selected)), child: Text(l.adminApply)),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _run(
      () => ref.read(adminFunctionsServiceProvider).setRole(_uid, picked.role),
      l.adminUserRoleDone,
    );
  }

  Future<void> _grantCredits() async {
    final l = AppLocalizations.of(context)!;
    final delta = TextEditingController(text: '1');
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminUserGrantTitle),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: delta,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}'))],
                decoration: InputDecoration(labelText: l.adminUserGrantDelta, helperText: l.adminUserGrantDeltaHelp),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n == 0 || n.abs() > 100) ? l.adminUserGrantDeltaInvalid : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: reason,
                decoration: InputDecoration(labelText: l.adminReason),
                validator: (v) => (v == null || v.trim().length < 3) ? l.adminReasonRequired : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.adminCancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
            },
            child: Text(l.adminUserGrant),
          ),
        ],
      ),
    );
    final n = int.tryParse(delta.text) ?? 0;
    final why = reason.text.trim();
    delta.dispose();
    reason.dispose();
    if (ok != true || !mounted) return;
    await _run(
      () async {
        await ref.read(adminFunctionsServiceProvider).grantCredits(_uid, n, why);
      },
      l.adminUserGrantDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final u = widget.user;
    final role = ref.watch(adminRoleProvider);
    final canModerate = role?.can(AdminPermission.moderateUsers) ?? false;
    // Premium is not part of moderation: the rules let only super_admin
    // write `subscription` (D5).
    final canPremium = role?.canSetPremium ?? false;
    final canRoles = role?.can(AdminPermission.manageRoles) ?? false;
    final canGrant = role?.can(AdminPermission.grantCredits) ?? false;
    final ent = ref.watch(adminEntitlementProvider(u.uid));
    final ledger = ref.watch(adminLedgerProvider(u.uid));
    final stats = ref.watch(adminUserStatsProvider(u.uid));
    return AdminPageBody(
      maxWidth: 900,
      children: [
        AdminCard(
          title: u.name.isEmpty ? u.email : u.name,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AdminKeyValue('UID', u.uid),
            AdminKeyValue(l.adminLoginEmail, u.email.isEmpty ? '—' : u.email),
            AdminKeyValue(l.adminUserCreated, formatAdminDate(u.createdAt)),
            AdminKeyValue(l.adminUserLastActive, formatAdminDate(u.lastActive)),
            AdminKeyValue(l.adminUserLanguage, u.preferredLanguage),
            if (u.grade != null) AdminKeyValue(l.adminUserGrade, '${u.grade}'),
            if (u.school != null) AdminKeyValue(l.adminUserSchool, u.school!),
            AdminKeyValue(l.adminUserSubscription,
                '${u.subscriptionTier}${u.subscriptionExpiresAt == null ? '' : ' · ${formatAdminDate(u.subscriptionExpiresAt)}'}'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              if (u.isBanned) AdminPill(l.adminUsersBanned, tone: AdminTone.danger),
              if (u.isPremium) AdminPill(l.adminUsersPremium, tone: AdminTone.success),
              if (u.legacyRole == 'admin') AdminPill(l.adminUsersLegacyAdmin, tone: AdminTone.info),
            ]),
          ]),
        ),
        if (canModerate || canPremium || canRoles || canGrant)
          AdminCard(
            title: l.adminUserActions,
            child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              if (canModerate)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleBan,
                  icon: Icon(u.isBanned ? Icons.lock_open : Icons.block),
                  label: Text(u.isBanned ? l.adminUserUnban : l.adminUserBan),
                ),
              if (canPremium)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _togglePremium,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(u.isPremium ? l.adminUserPremiumOff : l.adminUserPremiumOn),
                ),
              if (canRoles)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _setRole,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(l.adminUserRoleTitle),
                ),
              if (canGrant)
                FilledButton.icon(
                  onPressed: _busy ? null : _grantCredits,
                  icon: const Icon(Icons.add_card_outlined),
                  label: Text(l.adminUserGrantTitle),
                ),
            ]),
          ),
        AdminCard(
          title: l.adminUserEntitlements,
          child: ent.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(adminErrorMessage(l, e), style: TextStyle(color: context.tokens.danger)),
            data: (e) => !e.exists
                ? Text(l.adminUserNoEntitlements)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AdminKeyValue(l.adminUserCredits, '${e.credits}'),
                    AdminKeyValue(l.adminUserFreeUsed, e.freeExamUsed ? l.adminYes : l.adminNo),
                    AdminKeyValue(l.adminUserLifetime, '${e.lifetimeCreditsPurchased}'),
                    AdminKeyValue(l.adminUpdated, formatAdminDate(e.updatedAt)),
                  ]),
          ),
        ),
        AdminCard(
          title: l.adminUserLedger,
          child: ledger.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(adminErrorMessage(l, e), style: TextStyle(color: context.tokens.danger)),
            data: (items) => items.isEmpty
                ? Text(l.adminListNoItems)
                : Column(children: [
                    for (final x in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Text(x.delta > 0 ? '+${x.delta}' : '${x.delta}',
                            style: TextStyle(color: x.delta > 0 ? context.tokens.success : context.tokens.danger)),
                        title: Text('${x.reason} · ${l.adminUserBalance(x.balanceAfter)}'),
                        subtitle: Text('${formatAdminDate(x.at)}${x.ref.isEmpty ? '' : ' · ${x.ref}'}'),
                      ),
                  ]),
          ),
        ),
        UserGrowthCard(user: u),
        AdminCard(
          title: l.adminUserStats,
          child: stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(adminErrorMessage(l, e), style: TextStyle(color: context.tokens.danger)),
            data: (s) => s == null
                ? Text(l.adminListNoItems)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final k in const ['xp', 'level', 'current_streak', 'best_streak', 'exams_completed', 'last_active_day'])
                      if (s[k] != null) AdminKeyValue(k, '${s[k]}'),
                  ]),
          ),
        ),
      ],
    );
  }
}

/// Read-only phase-3 data of a user (ARCHITECTURE.md §9.1, §9.3): referral
/// code, inviter, number of invited people (`count()` over
/// `referrals/{uid}/items`) and group memberships (`group_ids` → names).
/// All of it is written by the server only.
///
/// `canViewUsers()` roles may read `referrals/{uid}`, its items and
/// `groups/{gid}` (§9.7). Under older deployed rules those reads are
/// `permission-denied`: the count then shows "—", a group shows its id, and
/// one note under the card says the rules need an update — the rest of the
/// card (from `users/{uid}`) is unaffected.
class UserGrowthCard extends ConsumerWidget {
  const UserGrowthCard({super.key, required this.user});
  final AdminUserRecord user;

  static bool _denied(AsyncValue<Object?> v) => v.hasError && isAdminPermissionDenied(v.error!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final referrals = ref.watch(adminReferralsCountProvider(user.uid));
    final groups = [for (final gid in user.groupIds) ref.watch(adminGroupNameProvider(gid))];
    final rulesOutdated = _denied(referrals) || groups.any(_denied);
    final referredBy = user.referredBy;
    return AdminCard(
      title: l.adminUserGrowth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminKeyValue(l.adminUserReferralCode, user.referralCode ?? '—'),
          if (referredBy == null)
            AdminKeyValue(l.adminUserReferredBy, '—')
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                AdminKeyValue(l.adminUserReferredBy, referredBy),
                TextButton(
                  onPressed: () => context.push('/admin/users/$referredBy'),
                  child: Text(l.adminUserOpenProfile),
                ),
              ],
            ),
          AdminKeyValue(
            l.adminUserReferralsCount,
            referrals.when(
              loading: () => '…',
              error: (e, _) => isAdminPermissionDenied(e) ? '—' : adminErrorMessage(l, e),
              data: (n) => '$n',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l.adminUserGroups(user.groupIds.length), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (user.groupIds.isEmpty)
            Text(l.adminUserNoGroups, style: TextStyle(color: t.textSecondary))
          else
            for (final gid in user.groupIds) _GroupMembershipRow(groupId: gid),
          if (rulesOutdated) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.adminUserGrowthNoAccess,
              key: const ValueKey('growth_no_access'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupMembershipRow extends ConsumerWidget {
  const _GroupMembershipRow({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final name = ref.watch(adminGroupNameProvider(groupId));
    final (String title, String? note, Color? noteColor) = name.when(
      loading: () => (groupId, null, null),
      // Older rules: no name, just the id (the card explains once).
      error: (e, _) => isAdminPermissionDenied(e) ? (groupId, null, null) : (groupId, adminErrorMessage(l, e), t.danger),
      data: (n) => n == null
          ? (groupId, l.adminUserGroupMissing, t.warning)
          : (n.isEmpty ? groupId : n, n.isEmpty ? null : groupId, t.textTertiary),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.groups_outlined),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: note == null
          ? null
          : Text(note, style: TextStyle(color: noteColor), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: name.isLoading
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }
}

/// Ban confirmation with the reason field (MOD-01). firestore.rules rejects a
/// moderator's `ban_reason` longer than [UsersRepository.maxBanReasonLength]
/// characters, so the field shows a counter and the Ban button stays
/// disabled with a message while the reason is too long. Pops the trimmed
/// reason to ban, or null when cancelled.
class BanReasonDialog extends StatefulWidget {
  const BanReasonDialog({super.key});

  @override
  State<BanReasonDialog> createState() => _BanReasonDialogState();
}

class _BanReasonDialogState extends State<BanReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const max = UsersRepository.maxBanReasonLength;
    // The stored value is the trimmed text, measured like the rules do.
    final text = _reason.text.trim();
    final length = UsersRepository.banReasonLength(text);
    final tooLong = length > max;
    return AlertDialog(
      title: Text(l.adminUserBanTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          key: const ValueKey('ban_reason_field'),
          controller: _reason,
          onChanged: (_) => setState(() {}),
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          // Typing past the limit is allowed so a pasted text is not cut
          // silently; the counter and the message say what to shorten.
          maxLength: max,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          decoration: InputDecoration(
            labelText: l.adminReason,
            counterText: '$length / $max',
            errorText: tooLong ? l.adminBanReasonTooLong(max) : null,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.adminCancel)),
        FilledButton(
          key: const ValueKey('ban_confirm'),
          onPressed: tooLong ? null : () => Navigator.pop(context, text),
          child: Text(l.adminUserBan),
        ),
      ],
    );
  }
}
