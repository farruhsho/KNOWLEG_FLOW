import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/promo_code.dart';
import '../widgets/admin_widgets.dart';

String promoStatusLabel(AppLocalizations l, PromoStatus s) => switch (s) {
      PromoStatus.active => l.adminPromoStatusActive,
      PromoStatus.inactive => l.adminPromoStatusInactive,
      PromoStatus.expired => l.adminPromoStatusExpired,
      PromoStatus.exhausted => l.adminPromoStatusExhausted,
    };

AdminTone promoStatusTone(PromoStatus s) => switch (s) {
      PromoStatus.active => AdminTone.success,
      PromoStatus.inactive => AdminTone.neutral,
      PromoStatus.expired || PromoStatus.exhausted => AdminTone.warning,
    };

/// Expiry date as Kyrgyzstan sees it (codes expire at 23:59 Bishkek time).
String _formatDay(DateTime? d) {
  if (d == null) return '—';
  final x = promoBishkekDate(d);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${x.year}-${two(x.month)}-${two(x.day)}';
}

String _usage(AppLocalizations l, int redemptions, int? max) =>
    l.adminPromoUsage(redemptions, max == null ? '∞' : '$max');

/// Promo codes (§9.2): super_admin with `grant_credits`. Codes grant free
/// exam credits, so the page leads with a finance warning; every change goes
/// through `adminUpsertPromoCode`, which writes `admin_logs`.
class PromoCodesPage extends ConsumerWidget {
  const PromoCodesPage({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, PromoCodeDraft draft, {required bool isNew}) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: isNew ? l.adminPromoConfirmCreateTitle : l.adminPromoConfirmEditTitle,
      message: l.adminPromoConfirmBody(
        draft.normalizedCode,
        draft.credits,
        draft.maxRedemptions == null ? l.adminPromoUnlimited : '${draft.maxRedemptions}',
        draft.expiresAt == null ? l.adminPromoNoExpiry : _formatDay(draft.expiresAt),
        draft.active ? l.adminPromoStatusActive : l.adminPromoStatusInactive,
      ),
      confirmLabel: l.adminSave,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(adminFunctionsServiceProvider).upsertPromoCode(draft);
      if (!context.mounted) return;
      showAdminSnack(context, l.adminPromoSaved(draft.normalizedCode));
      await ref.read(promoCodesPageProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, [PromoCodeRecord? existing]) async {
    final draft = await showDialog<PromoCodeDraft>(
      context: context,
      builder: (_) => PromoCodeEditorDialog(existing: existing),
    );
    if (draft == null || !context.mounted) return;
    await _save(context, ref, draft, isNew: existing == null);
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, PromoCodeRecord r) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: l.adminPromoDeactivateTitle(r.code),
      message: l.adminPromoDeactivateBody,
      confirmLabel: l.adminPromoDeactivate,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(adminFunctionsServiceProvider).upsertPromoCode(r.toDraft(active: false));
      if (!context.mounted) return;
      showAdminSnack(context, l.adminPromoDeactivated(r.code));
      ref.read(promoCodesPageProvider.notifier).replaceWhere(
            (x) => x.code == r.code,
            (x) => PromoCodeRecord(
              code: x.code,
              credits: x.credits,
              maxRedemptions: x.maxRedemptions,
              redemptions: x.redemptions,
              expiresAt: x.expiresAt,
              active: false,
              note: x.note,
              createdBy: x.createdBy,
              createdAt: x.createdAt,
            ),
          );
    } catch (e) {
      if (context.mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(promoCodesPageProvider);
    final notifier = ref.read(promoCodesPageProvider.notifier);
    final now = DateTime.now();
    final g = AppSpacing.gutter(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(g, AppSpacing.md, g, 0),
          child: AdminBanner(
            icon: Icons.warning_amber_outlined,
            tone: AdminTone.warning,
            margin: EdgeInsets.zero,
            message: l.adminPromoWarning,
          ),
        ),
        AdminFilterBar(children: [
          FilledButton.icon(
            key: const ValueKey('promo_create'),
            onPressed: () => _openEditor(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l.adminPromoCreate),
          ),
        ]),
        Expanded(
          child: PagedListBody<PromoCodeRecord>(
            state: state,
            onLoadMore: notifier.loadMore,
            onRetry: notifier.retry,
            onRefresh: notifier.refresh,
            emptyMessage: l.adminPromoEmpty,
            itemBuilder: (context, r) {
              final status = r.status(now);
              return AdminListTile(
                title: r.code,
                subtitle: [
                  l.adminPromoCreditsValue(r.credits),
                  _usage(l, r.redemptions, r.maxRedemptions),
                  r.expiresAt == null ? l.adminPromoNoExpiry : l.adminPromoUntil(_formatDay(r.expiresAt)),
                  if (r.note.trim().isNotEmpty) r.note.trim(),
                ].join(' · '),
                leading: const Icon(Icons.confirmation_number_outlined),
                chips: [AdminPill(promoStatusLabel(l, status), tone: promoStatusTone(status))],
                trailing: r.active
                    ? IconButton(
                        tooltip: l.adminPromoDeactivate,
                        icon: const Icon(Icons.block),
                        onPressed: () => _deactivate(context, ref, r),
                      )
                    : null,
                onTap: () => _openEditor(context, ref, r),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Create / edit form. Pops a valid [PromoCodeDraft], or `null` on cancel.
/// The code (document id) cannot be changed once created.
class PromoCodeEditorDialog extends StatefulWidget {
  const PromoCodeEditorDialog({super.key, this.existing});
  final PromoCodeRecord? existing;

  @override
  State<PromoCodeEditorDialog> createState() => _PromoCodeEditorDialogState();
}

class _PromoCodeEditorDialogState extends State<PromoCodeEditorDialog> {
  late final PromoCodeDraft _initial = widget.existing?.toDraft() ??
      PromoCodeDraft(code: generatePromoCode(), credits: 1);
  late final _code = TextEditingController(text: _initial.code);
  late final _max = TextEditingController(text: _initial.maxRedemptions?.toString() ?? '');
  late final _note = TextEditingController(text: _initial.note);
  late int _credits = _initial.credits;
  late DateTime? _expiresAt = _initial.expiresAt;
  late bool _active = _initial.active;
  List<PromoIssue> _issues = const [];

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _code.dispose();
    _max.dispose();
    _note.dispose();
    super.dispose();
  }

  PromoCodeDraft get _draft => PromoCodeDraft(
        code: _code.text,
        credits: _credits,
        maxRedemptions: _max.text.trim().isEmpty ? null : int.tryParse(_max.text.trim()) ?? 0,
        expiresAt: _expiresAt,
        active: _active,
        note: _note.text,
      );

  Future<void> _pickExpiry() async {
    final today = promoBishkekDate(DateTime.now());
    final current = _expiresAt == null ? null : promoBishkekDate(_expiresAt!);
    final picked = await showDatePicker(
      context: context,
      // An expired code's date lies before firstDate: start from today then.
      initialDate: (current == null || current.isBefore(today))
          ? today.add(const Duration(days: 30))
          : current,
      firstDate: today,
      lastDate: DateTime(today.year + 3, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _expiresAt = promoExpiryEndOfDay(picked));
    }
  }

  void _submit() {
    final draft = _draft;
    final issues = draft.validate(now: DateTime.now(), redemptions: widget.existing?.redemptions ?? 0);
    if (issues.isNotEmpty) {
      setState(() => _issues = issues);
      return;
    }
    Navigator.pop(context, draft);
  }

  String? _error(AppLocalizations l, List<PromoIssue> kinds) {
    for (final i in _issues) {
      if (!kinds.contains(i)) continue;
      return switch (i) {
        PromoIssue.codeFormat => l.adminPromoErrCode(kPromoCodeMinLength, kPromoCodeMaxLength),
        PromoIssue.creditsRange => l.adminPromoErrCredits(kPromoCreditsMin, kPromoCreditsMax),
        PromoIssue.maxRedemptionsRange => l.adminPromoErrMax(kPromoMaxRedemptionsLimit),
        PromoIssue.maxBelowRedemptions => l.adminPromoErrMaxBelow(widget.existing?.redemptions ?? 0),
        PromoIssue.expiryInPast => l.adminPromoErrExpiry,
        PromoIssue.noteTooLong => l.adminTextTooLong(kPromoNoteMax),
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final existing = widget.existing;
    final expiryError = _error(l, const [PromoIssue.expiryInPast]);
    return AlertDialog(
      title: Text(_isNew ? l.adminPromoCreate : l.adminPromoEditTitle(existing!.code)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminBanner(
                icon: Icons.warning_amber_outlined,
                tone: AdminTone.warning,
                message: l.adminPromoDialogWarning,
              ),
              TextField(
                key: const ValueKey('promo_code_field'),
                controller: _code,
                enabled: _isNew,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(kPromoCodeMaxLength),
                  TextInputFormatter.withFunction(
                      (_, v) => v.copyWith(text: v.text.toUpperCase())),
                ],
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: l.adminPromoCode,
                  helperText: l.adminPromoCodeHelp(kPromoCodeMinLength, kPromoCodeMaxLength),
                  errorText: _error(l, const [PromoIssue.codeFormat]),
                  suffixIcon: _isNew
                      ? IconButton(
                          tooltip: l.adminPromoGenerate,
                          icon: const Icon(Icons.autorenew),
                          onPressed: () => setState(() => _code.text = generatePromoCode()),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AdminDropdown<int>(
                label: l.adminPromoCredits,
                value: _credits,
                width: double.infinity,
                items: {
                  for (var c = kPromoCreditsMin; c <= kPromoCreditsMax; c++) c: '$c',
                },
                onChanged: (v) => setState(() => _credits = v ?? _credits),
              ),
              if (_error(l, const [PromoIssue.creditsRange]) case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('promo_max_field'),
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: l.adminPromoMaxRedemptions,
                  helperText: existing == null
                      ? l.adminPromoMaxHelp
                      : '${l.adminPromoMaxHelp} ${_usage(l, existing.redemptions, existing.maxRedemptions)}',
                  helperMaxLines: 2,
                  errorText: _error(l, const [PromoIssue.maxRedemptionsRange, PromoIssue.maxBelowRedemptions]),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.adminPromoExpiry, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _expiresAt == null ? l.adminPromoNoExpiry : l.adminPromoUntil(_formatDay(_expiresAt)),
                    style: TextStyle(color: expiryError == null ? t.textSecondary : Theme.of(context).colorScheme.error),
                  ),
                  TextButton.icon(
                    onPressed: _pickExpiry,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(l.adminPromoPickDate),
                  ),
                  if (_expiresAt != null)
                    TextButton(
                      onPressed: () => setState(() => _expiresAt = null),
                      child: Text(l.adminPromoClearDate),
                    ),
                ],
              ),
              if (expiryError != null)
                Text(expiryError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              Text(l.adminPromoExpiryHelp, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary)),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l.adminPromoActive),
                subtitle: Text(l.adminPromoActiveHelp),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l.adminPromoNote,
                  helperText: l.adminPromoNoteHelp,
                  errorText: _error(l, const [PromoIssue.noteTooLong]),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.adminCancel)),
        FilledButton(
          key: const ValueKey('promo_submit'),
          onPressed: _submit,
          child: Text(l.adminSave),
        ),
      ],
    );
  }
}
