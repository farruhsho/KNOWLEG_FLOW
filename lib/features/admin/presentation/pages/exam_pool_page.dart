import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/exam_pool.dart';
import '../widgets/admin_widgets.dart';

String minReviewStatusLabel(AppLocalizations l, MinReviewStatus s) => switch (s) {
      MinReviewStatus.methodologistApproved => l.adminPoolStatusApproved,
      MinReviewStatus.aiVerified => l.adminPoolStatusAi,
    };

/// «Пул заданий» (ARCHITECTURE §10.1): the fresh-variant settings in
/// `config/exam_pool` (super_admin edits them via `adminUpdateExamPool`) and
/// `adminExamPoolHealth` for a chosen blueprint × language (super_admin,
/// content_manager, methodologist).
class ExamPoolPage extends ConsumerStatefulWidget {
  const ExamPoolPage({super.key});

  @override
  ConsumerState<ExamPoolPage> createState() => _ExamPoolPageState();
}

class _ExamPoolPageState extends ConsumerState<ExamPoolPage> {
  String? _blueprintId;
  String? _language;

  /// The blueprint × language whose health was requested ("Проверить пул").
  ({String blueprintId, String language})? _requested;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final role = ref.watch(adminRoleProvider);
    final blueprints = ref.watch(adminBlueprintsProvider);
    return AdminPageBody(
      maxWidth: 960,
      children: [
        _PoolSettingsCard(canEdit: role?.canManageExamPool ?? false),
        AdminCard(
          title: l.adminPoolHealthTitle,
          child: blueprints.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AdminErrorView(error: e, onRetry: () => ref.invalidate(adminBlueprintsProvider)),
            data: (list) => _selector(l, list),
          ),
        ),
        if (_requested != null)
          _PoolHealthView(
            key: ValueKey('health:${_requested!.blueprintId}:${_requested!.language}'),
            request: _requested!,
            blueprint: blueprints.valueOrNull?.where((b) => b.id == _requested!.blueprintId).firstOrNull,
          ),
      ],
    );
  }

  Widget _selector(AppLocalizations l, List<BlueprintSpec> list) {
    final locale = Localizations.localeOf(context).languageCode;
    final usable = list.where((b) => b.status == 'active').toList();
    if (usable.isEmpty) return Text(l.adminPoolNoBlueprints, style: TextStyle(color: context.tokens.textSecondary));
    final bp = usable.where((b) => b.id == _blueprintId).firstOrNull ?? usable.first;
    final language = bp.languages.contains(_language) ? _language! : bp.languages.first;
    final key = (blueprintId: bp.id, language: language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.adminPoolHealthBody, style: TextStyle(color: context.tokens.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminDropdown<String>(
              key: const ValueKey('pool_blueprint'),
              label: l.adminFieldBlueprint,
              value: bp.id,
              width: 300,
              items: {for (final b in usable) b.id: pickLocalized(b.title, locale).isEmpty ? b.id : pickLocalized(b.title, locale)},
              onChanged: (v) => setState(() {
                _blueprintId = v;
                _language = null;
              }),
            ),
            AdminDropdown<String>(
              key: const ValueKey('pool_language'),
              label: l.adminFieldLanguage,
              value: language,
              width: 160,
              items: {for (final code in bp.languages) code: languageLabel(l, code)},
              onChanged: (v) => setState(() => _language = v),
            ),
            FilledButton.icon(
              key: const ValueKey('pool_check'),
              onPressed: () {
                if (_requested == key) {
                  ref.invalidate(examPoolHealthProvider(key));
                } else {
                  setState(() => _requested = key);
                }
              },
              icon: Icon(_requested == key ? Icons.refresh : Icons.analytics_outlined),
              label: Text(_requested == key ? l.adminPoolRecheck : l.adminPoolCheck),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Settings (config/exam_pool) -------------------------------------------

class _PoolSettingsCard extends ConsumerStatefulWidget {
  const _PoolSettingsCard({required this.canEdit});
  final bool canEdit;

  @override
  ConsumerState<_PoolSettingsCard> createState() => _PoolSettingsCardState();
}

class _PoolSettingsCardState extends ConsumerState<_PoolSettingsCard> {
  bool _saving = false;

  Future<void> _apply(ExamPoolConfig current, {bool? fresh, MinReviewStatus? status}) async {
    final l = AppLocalizations.of(context)!;
    final update = examPoolUpdatePayload(current, freshEnabled: fresh, minReviewStatus: status);
    if (update.isEmpty) return;
    final bool ok;
    if (status == MinReviewStatus.aiVerified) {
      ok = await showDialog<bool>(context: context, builder: (_) => const AiVerifiedConfirmDialog()) ?? false;
    } else {
      ok = await confirmAdminAction(
        context,
        title: fresh != null
            ? (fresh ? l.adminPoolConfirmFreshOnTitle : l.adminPoolConfirmFreshOffTitle)
            : l.adminPoolConfirmStatusTitle,
        message: fresh != null
            ? (fresh ? l.adminPoolConfirmFreshOnBody : l.adminPoolConfirmFreshOffBody)
            : l.adminPoolConfirmApprovedBody,
        confirmLabel: l.adminApply,
      );
    }
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminFunctionsServiceProvider).updateExamPool(update);
      if (!mounted) return;
      ref.invalidate(examPoolConfigProvider);
      ref.invalidate(examPoolHealthProvider);
      showAdminSnack(context, l.adminPoolSaved);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final config = ref.watch(examPoolConfigProvider);
    return AdminCard(
      title: l.adminPoolSettingsTitle,
      child: config.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => isAdminAccessDenied(e)
            ? AdminBanner(message: l.adminPoolConfigDenied, icon: Icons.lock_outline, tone: AdminTone.warning)
            : AdminErrorView(error: e, onRetry: () => ref.invalidate(examPoolConfigProvider)),
        data: (c) => _form(l, c),
      ),
    );
  }

  Widget _form(AppLocalizations l, ExamPoolConfig c) {
    final t = context.tokens;
    final editable = widget.canEdit && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.adminPoolSettingsBody, style: TextStyle(color: t.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        if (!widget.canEdit)
          AdminBanner(message: l.adminPoolReadOnly, icon: Icons.visibility_outlined, tone: AdminTone.neutral),
        if (!c.exists) AdminBanner(message: l.adminPoolNotCreated, tone: AdminTone.neutral),
        SwitchListTile(
          key: const ValueKey('pool_fresh_switch'),
          contentPadding: EdgeInsets.zero,
          value: c.freshEnabled,
          onChanged: editable ? (v) => _apply(c, fresh: v) : null,
          title: Text(l.adminPoolFreshEnabled),
          subtitle: Text(c.freshEnabled ? l.adminPoolFreshOnHelp : l.adminPoolFreshOffHelp),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(l.adminPoolMinStatus, style: Theme.of(context).textTheme.titleSmall),
        ),
        RadioGroup<MinReviewStatus>(
          groupValue: c.minReviewStatus,
          onChanged: (v) {
            if (editable && v != null) _apply(c, status: v);
          },
          child: Column(
            children: [
              for (final s in MinReviewStatus.values)
                RadioListTile<MinReviewStatus>(
                  key: ValueKey('pool_status_${s.wire}'),
                  contentPadding: EdgeInsets.zero,
                  value: s,
                  enabled: editable,
                  title: Text(minReviewStatusLabel(l, s)),
                  subtitle: Text(s == MinReviewStatus.methodologistApproved
                      ? l.adminPoolStatusApprovedHelp
                      : l.adminPoolStatusAiHelp),
                ),
            ],
          ),
        ),
        if (c.minReviewStatus == MinReviewStatus.aiVerified)
          AdminBanner(
            key: const ValueKey('pool_ai_active'),
            message: l.adminPoolAiActive,
            icon: Icons.warning_amber_outlined,
            tone: AdminTone.warning,
          ),
        if (c.updatedAt != null)
          Text(
            l.adminPoolUpdated(formatAdminDate(c.updatedAt), c.updatedBy ?? '—'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
          ),
        if (_saving) const LinearProgressIndicator(),
      ],
    );
  }
}

/// Confirmation for `min_review_status: ai_verified`: states plainly that such
/// questions were checked by an independent AI solver, not by a
/// methodologist, and needs an explicit acknowledgement.
class AiVerifiedConfirmDialog extends StatefulWidget {
  const AiVerifiedConfirmDialog({super.key});

  @override
  State<AiVerifiedConfirmDialog> createState() => _AiVerifiedConfirmDialogState();
}

class _AiVerifiedConfirmDialogState extends State<AiVerifiedConfirmDialog> {
  bool _ack = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.adminPoolConfirmStatusTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminBanner(
                message: l.adminPoolAiWarning,
                icon: Icons.warning_amber_outlined,
                tone: AdminTone.warning,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
              ),
              Text(l.adminPoolConfirmAiBody),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const ValueKey('pool_ai_ack'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _ack,
                onChanged: (v) => setState(() => _ack = v ?? false),
                title: Text(l.adminPoolAiAcknowledge),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.adminCancel)),
        FilledButton(
          key: const ValueKey('pool_ai_confirm'),
          onPressed: _ack ? () => Navigator.pop(context, true) : null,
          child: Text(l.adminApply),
        ),
      ],
    );
  }
}

// --- Health (adminExamPoolHealth) ------------------------------------------

class _PoolHealthView extends ConsumerWidget {
  const _PoolHealthView({super.key, required this.request, required this.blueprint});
  final ({String blueprintId, String language}) request;
  final BlueprintSpec? blueprint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final health = ref.watch(examPoolHealthProvider(request));
    // «Пересчитать» shows the progress instead of the stale report.
    return health.when(
      skipLoadingOnRefresh: false,
      loading: () => AdminCard(child: AdminLoadingView(label: l.adminPoolChecking)),
      error: (e, _) => AdminCard(
        child: isAdminAccessDenied(e)
            ? AdminAccessDeniedView(message: l.adminPoolHealthDenied)
            : AdminErrorView(error: e, onRetry: () => ref.invalidate(examPoolHealthProvider(request))),
      ),
      data: (h) => PoolHealthReport(health: h, blueprint: blueprint),
    );
  }
}

/// The `adminExamPoolHealth` report: summary, every section / part, and the
/// shortfalls of the next variant grouped by topic.
class PoolHealthReport extends StatelessWidget {
  const PoolHealthReport({super.key, required this.health, this.blueprint});
  final PoolHealth health;
  final BlueprintSpec? blueprint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final h = health;

    String sectionLabel(String id) {
      final s = blueprint?.section(id);
      final title = s == null ? '' : pickLocalized(s.title, locale);
      return title.isEmpty ? id : title;
    }

    String partLabel(String sectionId, String partId) {
      final p = blueprint?.section(sectionId)?.part(partId);
      final title = p == null ? '' : pickLocalized(p.title, locale);
      return title.isEmpty ? l.adminPoolPart(partId) : title;
    }

    final topics = h.topicShortfalls;
    final passages = h.passageShortfalls;
    final bpTitle = blueprint == null ? '' : pickLocalized(blueprint!.title, locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCard(
          key: const ValueKey('pool_summary'),
          title: '${bpTitle.isEmpty ? h.blueprintId : bpTitle} · ${languageLabel(l, h.language)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                h.capped ? l.adminPoolDisjointCapped(h.disjointVariants) : l.adminPoolDisjoint(h.disjointVariants),
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l.adminPoolDisjointHelp, style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              if (h.disjointVariants == 0)
                AdminBanner(message: l.adminPoolDisjointZero, icon: Icons.error_outline, tone: AdminTone.danger),
              if (h.freshEnabled == false)
                AdminBanner(message: l.adminPoolFreshOff, icon: Icons.pause_circle_outline, tone: AdminTone.warning),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AdminPill(l.adminPoolTotals(h.needed, h.eligible)),
                  if (h.minReviewStatus != null)
                    AdminPill(
                      l.adminPoolFloorNow(minReviewStatusLabel(l, h.minReviewStatus!)),
                      tone: h.minReviewStatus == MinReviewStatus.aiVerified ? AdminTone.warning : AdminTone.success,
                    ),
                ],
              ),
            ],
          ),
        ),
        for (final s in h.sections)
          AdminCard(
            title: sectionLabel(s.sectionId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in s.parts) _PartHealthRow(label: partLabel(s.sectionId, p.partId), part: p),
              ],
            ),
          ),
        AdminCard(
          key: const ValueKey('pool_shortfalls'),
          title: l.adminPoolShortfallsTitle,
          child: topics.isEmpty && passages.isEmpty
              ? Text(l.adminPoolShortfallsEmpty, style: TextStyle(color: t.textSecondary))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.adminPoolShortfallsHelp, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final g in topics)
                      _ShortfallTile(
                        title: g.topicId,
                        subtitle: '${sectionLabel(g.sectionId)} · ${partLabel(g.sectionId, g.partId)}',
                        detail: g.cells
                            .map((c) => l.adminPoolShortfallCell(c.difficulty ?? 0, c.needed, c.available))
                            .join(' · '),
                        missing: g.missing,
                      ),
                    for (final p in passages)
                      _ShortfallTile(
                        title: p.layout == 'paired' ? l.adminPoolPassagesPaired : l.adminPoolPassagesStandalone,
                        subtitle: '${sectionLabel(p.sectionId)} · ${partLabel(p.sectionId, p.partId)}',
                        detail: l.adminPoolShortfallPassages(p.needed, p.available),
                        missing: p.missing,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PartHealthRow extends StatelessWidget {
  const _PartHealthRow({required this.label, required this.part});
  final String label;
  final PoolPartHealth part;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final p = part;
    final ratio = p.needed <= 0 ? 1.0 : (p.eligible / p.needed).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: text.titleSmall),
              AdminPill(
                p.covered ? l.adminPoolPartVariants(p.disjointVariants) : l.adminPoolPartNotCovered,
                tone: p.covered ? AdminTone.success : AdminTone.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.missing > 0
                ? l.adminPoolPartMissing(p.needed, p.eligible, p.missing)
                : l.adminPoolPartCounts(p.needed, p.eligible),
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: t.surfaceMuted,
              color: p.covered ? t.success : t.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AdminPill(l.adminPoolByApproved(p.byStatus.methodologistApproved), tone: AdminTone.success),
              AdminPill(l.adminPoolByAi(p.byStatus.aiVerified), tone: AdminTone.info),
              AdminPill(l.adminPoolByDraft(p.byStatus.draft)),
              if (p.passages.total > 0)
                AdminPill(l.adminPoolPassages(p.passages.standalone, p.passages.paired)),
              if (p.passages.unknown > 0) AdminPill(l.adminPoolPassagesUnknown(p.passages.unknown)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortfallTile extends StatelessWidget {
  const _ShortfallTile({required this.title, required this.subtitle, required this.detail, required this.missing});
  final String title;
  final String subtitle;
  final String detail;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(borderRadius: AppRadii.smAll, border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(title, style: text.titleSmall),
              AdminPill(l.adminPoolMissing(missing), tone: AdminTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: text.bodySmall?.copyWith(color: t.textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(detail, style: text.bodySmall),
        ],
      ),
    );
  }
}
