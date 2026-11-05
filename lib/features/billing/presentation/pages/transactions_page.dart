import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/billing_providers.dart';
import '../../application/paged_list_controller.dart';
import '../../domain/billing_records.dart';
import '../../domain/pricing_config.dart';
import '../billing_messages.dart';
import '../widgets/billing_state_views.dart';

/// Purchase history + credits ledger (RoutePaths.transactions). Read-only,
/// server-written data; paginated 20 rows at a time.
///
/// In `BILLING_MODE=external` builds there are no in-app purchases: the page
/// is a neutral credit history (ledger only, no purchase wording or prices).
class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(billingUidProvider);
    final mode = ref.watch(billingModeProvider);
    final sellsInApp = mode.sellsInApp;
    if (!sellsInApp) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.billingCreditHistoryTitle)),
        body: _body(context, ref, uid, sellsInApp: false),
      );
    }
    if (!mode.usesPlayBilling) {
      // Web build: there are no Google Play purchases to list; the ledger
      // shows every credit (site payments included).
      return Scaffold(
        appBar: AppBar(title: Text(l10n.billingTransactionsTitle)),
        body: _body(context, ref, uid, sellsInApp: true, tabs: false),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.billingTransactionsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.billingTabPurchases),
              Tab(text: l10n.billingTabLedger),
            ],
          ),
        ),
        body: _body(context, ref, uid, sellsInApp: true),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AsyncValue<String?> uid,
      {required bool sellsInApp, bool tabs = true}) {
    final l10n = AppLocalizations.of(context)!;
    return uid.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _Padded(
        child: BillingMessage(
          icon: Icons.error_outline,
          tone: BillingTone.danger,
          message: l10n.billingHistoryError,
          actionLabel: l10n.billingRetry,
          onAction: () => ref.invalidate(billingUidProvider),
        ),
      ),
      data: (uid) {
        if (uid == null) {
          return _Padded(
            child: BillingMessage(icon: Icons.person_outline, message: l10n.billingSignInRequired),
          );
        }
        final repo = ref.watch(billingHistoryRepositoryProvider);
        final ledger = _PagedList<LedgerEntry>(
          key: ValueKey('ledger_$uid'),
          fetch: (cursor) => repo.ledger(uid, cursor),
          emptyText: l10n.billingLedgerEmpty,
          itemBuilder: (context, e) => _LedgerTile(entry: e, neutral: !sellsInApp),
        );
        if (!sellsInApp || !tabs) return ledger;
        return TabBarView(
          children: [
            _PagedList<PurchaseRecord>(
              key: ValueKey('purchases_$uid'),
              fetch: (cursor) => repo.purchases(uid, cursor),
              emptyText: l10n.billingPurchasesEmpty,
              itemBuilder: (context, p) => _PurchaseTile(record: p),
            ),
            ledger,
          ],
        );
      },
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = AppSpacing.gutter(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(g, AppSpacing.lg, g, AppSpacing.lg),
      children: [child],
    );
  }
}

class _PagedList<T> extends StatefulWidget {
  const _PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyText,
  });

  final PageFetcher<T> fetch;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyText;

  @override
  State<_PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<_PagedList<T>> {
  late final PagedListController<T> _controller = PagedListController<T>(widget.fetch);

  @override
  void initState() {
    super.initState();
    _controller.refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 400 && _controller.error == null) {
      _controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = AppSpacing.gutter(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        if (!c.loadedOnce && c.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.items.isEmpty && c.error != null) {
          return _Padded(
            child: BillingMessage(
              icon: Icons.error_outline,
              tone: BillingTone.danger,
              message: l10n.billingHistoryError,
              actionLabel: l10n.billingRetry,
              onAction: c.refresh,
            ),
          );
        }
        if (c.isEmpty) {
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: _Padded(child: BillingMessage(icon: Icons.history, message: widget.emptyText)),
          );
        }
        final items = c.items;
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(g, AppSpacing.md, g, AppSpacing.xxxl),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                if (i < items.length) return widget.itemBuilder(context, items[i]);
                return _Footer(controller: c);
              },
            ),
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final PagedListController<Object?> controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: BillingMessage(
          icon: Icons.error_outline,
          tone: BillingTone.danger,
          message: l10n.billingHistoryError,
          actionLabel: l10n.billingRetry,
          onAction: controller.loadMore,
        ),
      );
    }
    if (!controller.hasMore) return const SizedBox(height: AppSpacing.lg);
    return Center(
      child: TextButton(onPressed: controller.loadMore, child: Text(l10n.billingLoadMore)),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final PurchaseRecordState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (state) {
      PurchaseRecordState.granted => (t.success, t.successContainer),
      PurchaseRecordState.pending => (t.warning, t.warningContainer),
      PurchaseRecordState.revoked => (t.danger, t.dangerContainer),
      PurchaseRecordState.refunded ||
      PurchaseRecordState.invalid ||
      PurchaseRecordState.unknown =>
        (scheme.onSurfaceVariant, t.surfaceMuted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        child: Text(
          l10n.billingPurchaseStateLabel(state),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
        ),
      ),
    );
  }
}

class _PurchaseTile extends ConsumerWidget {
  const _PurchaseTile({required this.record});
  final PurchaseRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pricing = ref.watch(pricingConfigProvider).valueOrNull ?? PricingConfig.defaults;
    // External (consumption-only) builds never show prices.
    final showPrice = ref.watch(billingModeProvider.select((m) => m.sellsInApp));
    final details = <String>[
      formatBillingDate(context, record.createdAt),
      if (showPrice && record.priceDisplay != null) record.priceDisplay!,
    ].where((s) => s.isNotEmpty).join(' · ');

    return BillingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  record.productId.isEmpty
                      ? l10n.billingReasonPurchase
                      : l10n.billingProductTitle(pricing, record.productId, lang),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StateBadge(state: record.state),
            ],
          ),
          if (record.creditsGranted > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('+${l10n.billingCreditsCount(record.creditsGranted)}',
                style: theme.textTheme.bodyMedium),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(details, style: theme.textTheme.bodySmall),
          ],
          if (record.orderId != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            SelectableText(l10n.billingOrderId(record.orderId!), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, this.neutral = false});
  final LedgerEntry entry;

  /// External builds: no purchase wording in reason labels.
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final positive = entry.delta > 0;
    final deltaText = entry.delta == 0
        ? '0'
        : positive
            ? '+${entry.delta}'
            : '−${entry.delta.abs()}';
    final sub = <String>[
      formatBillingDate(context, entry.at),
      if (entry.balanceAfter != null) l10n.billingBalanceAfter(entry.balanceAfter!),
    ].where((s) => s.isNotEmpty).join(' · ');

    return BillingCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.billingLedgerReasonLabel(entry.reason, neutral: neutral),
                    style: theme.textTheme.titleSmall),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(sub, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            deltaText,
            style: theme.textTheme.titleMedium?.copyWith(
              color: entry.delta == 0
                  ? theme.colorScheme.onSurfaceVariant
                  : positive
                      ? t.success
                      : t.danger,
            ),
          ),
        ],
      ),
    );
  }
}
