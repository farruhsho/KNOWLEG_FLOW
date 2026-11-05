import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../data/json_safe.dart';
import '../../data/models/admin_records.dart';
import '../../domain/pricing_config.dart';
import '../widgets/admin_widgets.dart';
import 'web_payments_page.dart';
import 'web_pricing_form.dart';

String purchaseStateLabel(AppLocalizations l, String s) => switch (s) {
      'pending' => l.adminPurchasePending,
      'granted' => l.adminPurchaseGranted,
      'refunded' => l.adminPurchaseRefunded,
      'revoked' => l.adminPurchaseRevoked,
      'invalid' => l.adminPurchaseInvalid,
      _ => s,
    };

AdminTone purchaseStateTone(String s) => switch (s) {
      'granted' => AdminTone.success,
      'pending' => AdminTone.info,
      'refunded' || 'revoked' => AdminTone.warning,
      'invalid' => AdminTone.danger,
      _ => AdminTone.neutral,
    };

/// «Платежи» (support and super_admin): website orders (`payment_orders`,
/// ARCHITECTURE.md §10.3) with refunds for super_admin, the revenue per
/// Bishkek day, and the read-only Google Play purchases (`purchases`, §1.6).
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.adminPaymentsTabWeb),
                Tab(text: l.adminPaymentsTabRevenue),
                Tab(text: l.adminPaymentsTabPlay),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [WebOrdersTab(), RevenueTab(), PlayPurchasesTab()]),
          ),
        ],
      ),
    );
  }
}

/// Read-only Google Play purchases (`purchases`, ARCHITECTURE.md §1.6).
/// Refunds and grants are server-side only.
class PlayPurchasesTab extends ConsumerStatefulWidget {
  const PlayPurchasesTab({super.key});

  @override
  ConsumerState<PlayPurchasesTab> createState() => _PlayPurchasesTabState();
}

class _PlayPurchasesTabState extends ConsumerState<PlayPurchasesTab> {
  String? _state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(purchasesPageProvider(_state));
    final notifier = ref.read(purchasesPageProvider(_state).notifier);
    return Column(
      children: [
        AdminFilterBar(children: [
          AdminDropdown<String>(
            label: l.adminFieldStatus,
            value: _state,
            allLabel: l.adminAll,
            items: {for (final s in PurchaseRecord.states) s: purchaseStateLabel(l, s)},
            onChanged: (v) => setState(() => _state = v),
          ),
          Text(l.adminPaymentsReadOnly, style: TextStyle(color: context.tokens.textSecondary)),
        ]),
        Expanded(
          child: PagedListBody<PurchaseRecord>(
            state: state,
            onLoadMore: notifier.loadMore,
            onRetry: notifier.retry,
            onRefresh: notifier.refresh,
            emptyMessage: l.adminPaymentsEmpty,
            itemBuilder: (context, p) => AdminListTile(
              title: '${p.productId} · ${l.adminPaymentsCredits(p.creditsGranted)}',
              subtitle: [
                if (p.orderId.isNotEmpty) p.orderId,
                'uid ${p.uid}',
                formatAdminDate(p.purchaseTime ?? p.createdAt),
                if (p.priceDisplay.isNotEmpty) p.priceDisplay,
              ].join(' · '),
              chips: [
                AdminPill(purchaseStateLabel(l, p.state), tone: purchaseStateTone(p.state)),
                if (p.refund != null) AdminPill(l.adminPaymentsRefund, tone: AdminTone.warning),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// `config/pricing` editor (super_admin) via `adminUpdatePricing`: the
/// website products and prices (`web_products`, §10.3) and the Google Play
/// product → credits map with the free exams per account.
class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final pricing = ref.watch(pricingProvider);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: [
              Tab(text: l.adminPricingTabWeb),
              Tab(text: l.adminPricingTabPlay),
            ]),
          ),
          Expanded(
            child: AsyncBody<PricingConfig>(
              value: pricing,
              onRetry: () => ref.invalidate(pricingProvider),
              data: (p) => TabBarView(children: [
                WebPricingForm(initial: p),
                _PricingForm(initial: p),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingForm extends ConsumerStatefulWidget {
  const _PricingForm({required this.initial});
  final PricingConfig initial;

  @override
  ConsumerState<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends ConsumerState<_PricingForm> {
  late final Map<String, TextEditingController> _credits = {
    for (final id in BillingProducts.all)
      id: TextEditingController(text: '${widget.initial.products[id] ?? kDefaultProductCredits[id] ?? 1}'),
  };
  late final _free = TextEditingController(text: '${widget.initial.freeExamsPerUser}');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _credits.values) {
      c.dispose();
    }
    _free.dispose();
    super.dispose();
  }

  String _issue(AppLocalizations l, String code) => switch (code) {
        PricingIssue.creditsRange => l.adminPricingIssueCredits,
        PricingIssue.freeRange => l.adminPricingIssueFree(kFreeExamsPerUserMin, kFreeExamsPerUserMax),
        PricingIssue.unknownProduct => l.adminPricingIssueProduct,
        PricingIssue.singleMustBeOne => l.adminPricingIssueSingle,
        _ => code,
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final config = PricingConfig(
      products: {for (final e in _credits.entries) e.key: int.tryParse(e.value.text.trim()) ?? 0},
      freeExamsPerUser: int.tryParse(_free.text.trim()) ?? -1,
    );
    final issues = config.validate(knownProducts: BillingProducts.all);
    if (issues.isNotEmpty) {
      showAdminSnack(context, issues.map((c) => _issue(l, c)).join('\n'), error: true);
      return;
    }
    final ok = await confirmAdminAction(
      context,
      title: l.adminPricingConfirmTitle,
      message: l.adminPricingConfirmBody,
      confirmLabel: l.adminSave,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminFunctionsServiceProvider).updatePricing(config.products, config.freeExamsPerUser);
      if (!mounted) return;
      ref.invalidate(pricingProvider);
      showAdminSnack(context, l.adminSaved);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    return AdminPageBody(
      maxWidth: 720,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: t.warningContainer, borderRadius: AppRadii.mdAll),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_outlined, color: t.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l.adminPricingWarning, style: TextStyle(color: t.warning))),
          ]),
        ),
        if (!widget.initial.exists)
          AdminCard(child: Text(l.adminPricingDefaults, style: TextStyle(color: t.textSecondary))),
        AdminCard(
          title: l.adminPricingProducts,
          child: Column(children: [
            for (final id in BillingProducts.all)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: TextField(
                  controller: _credits[id],
                  enabled: id != BillingProducts.examSingle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l.adminPricingCreditsFor(id),
                    helperText: id == BillingProducts.examSingle ? l.adminPricingSingleHelp : null,
                  ),
                ),
              ),
          ]),
        ),
        AdminCard(
          title: l.adminPricingFree,
          child: TextField(
            controller: _free,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l.adminPricingFreeLabel, helperText: l.adminPricingFreeHelp),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _saving ? null : _save, child: Text(l.adminSave)),
        ),
      ],
    );
  }
}

/// `admin_logs` (super_admin, support), newest first.
class AdminLogsPage extends ConsumerWidget {
  const AdminLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(adminLogsPageProvider);
    final notifier = ref.read(adminLogsPageProvider.notifier);
    return PagedListBody<AdminLogRecord>(
      state: state,
      onLoadMore: notifier.loadMore,
      onRetry: notifier.retry,
      onRefresh: notifier.refresh,
      emptyMessage: l.adminLogsEmpty,
      itemBuilder: (context, r) => AdminListTile(
        title: r.action.isEmpty ? r.id : r.action,
        subtitle: [
          formatAdminDate(r.at),
          if (r.actorUid != null) l.adminLogsActor(r.actorUid!),
          if (r.targetUid != null) l.adminLogsTarget(r.targetUid!),
        ].join(' · '),
        onTap: r.details.isEmpty
            ? null
            : () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(r.action),
                    content: SizedBox(
                      width: 560,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(jsonSafe(r.details)),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminClose))],
                  ),
                ),
      ),
    );
  }
}
