import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/admin_role.dart';
import '../../domain/payment_order.dart';
import '../widgets/admin_widgets.dart';

String orderStatusLabel(AppLocalizations l, String s) => switch (s) {
      'created' => l.adminOrderStatusCreated,
      'pending' => l.adminOrderStatusPending,
      'paid' => l.adminOrderStatusPaid,
      'failed' => l.adminOrderStatusFailed,
      'expired' => l.adminOrderStatusExpired,
      'refunded' => l.adminOrderStatusRefunded,
      _ => s,
    };

AdminTone orderStatusTone(String s) => switch (s) {
      'paid' => AdminTone.success,
      'created' || 'pending' => AdminTone.info,
      'refunded' || 'expired' => AdminTone.warning,
      'failed' => AdminTone.danger,
      _ => AdminTone.neutral,
    };

/// `amount_som` with its currency (`KGS` is shown as «сом»).
String orderAmountLabel(AppLocalizations l, PaymentOrder o) =>
    o.currency.toUpperCase() == 'KGS' ? l.adminSom(o.amountSom) : '${o.amountSom} ${o.currency}';

String _refundSourceLabel(AppLocalizations l, String source) => switch (source) {
      'admin' => l.adminOrderRefundSourceAdmin,
      'provider' => l.adminOrderRefundSourceProvider,
      _ => source,
    };

/// `adminRefundOrder` gave no answer in time ([AdminFunctions.refundOrderTimeout]):
/// the server may still have refunded, so the outcome is unknown — never
/// suggest simply trying again.
bool isRefundOutcomeUnknown(Object error) =>
    error is FirebaseFunctionsException && error.code == 'deadline-exceeded';

/// Message for a failed `adminRefundOrder` call.
String refundOrderErrorMessage(AppLocalizations l, Object error) =>
    isRefundOutcomeUnknown(error) ? l.adminOrderRefundUnknown : adminErrorMessage(l, error);

/// Website orders (`payment_orders`, §10.3): status filter, pagination,
/// order card and — for super_admin — «Вернуть платёж» via
/// `adminRefundOrder`. Support reads only.
class WebOrdersTab extends ConsumerStatefulWidget {
  const WebOrdersTab({super.key});

  @override
  ConsumerState<WebOrdersTab> createState() => _WebOrdersTabState();
}

class _WebOrdersTabState extends ConsumerState<WebOrdersTab> {
  String? _status;

  /// Orders whose `adminRefundOrder` call has not answered yet: no second
  /// refund can be started for them meanwhile.
  final Set<String> _refunding = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final role = ref.watch(adminRoleProvider);
    final canRefund = role?.canRefundOrders ?? false;
    final state = ref.watch(paymentOrdersPageProvider(_status));
    final notifier = ref.read(paymentOrdersPageProvider(_status).notifier);
    final denied = state.items.isEmpty && state.error != null && isAdminAccessDenied(state.error!);
    return Column(
      children: [
        AdminFilterBar(children: [
          AdminDropdown<String>(
            key: const ValueKey('orders_status'),
            label: l.adminFieldStatus,
            value: _status,
            allLabel: l.adminAll,
            items: {for (final s in kPaymentOrderStatuses) s: orderStatusLabel(l, s)},
            onChanged: (v) => setState(() => _status = v),
          ),
          if (!canRefund)
            Text(l.adminOrdersReadOnly, style: TextStyle(color: context.tokens.textSecondary)),
        ]),
        Expanded(
          child: denied
              ? AdminAccessDeniedView(message: l.adminOrdersDenied, onRetry: notifier.refresh)
              : PagedListBody<PaymentOrder>(
                  state: state,
                  onLoadMore: notifier.loadMore,
                  onRetry: notifier.retry,
                  onRefresh: notifier.refresh,
                  emptyMessage: l.adminOrdersEmpty,
                  itemBuilder: (context, o) => AdminListTile(
                    key: ValueKey('order_${o.id}'),
                    title: '${o.productId} · ${orderAmountLabel(l, o)}',
                    subtitle: [
                      formatAdminDate(o.createdAt),
                      'uid ${o.uid}',
                      if (o.provider.isNotEmpty) o.provider,
                    ].join(' · '),
                    chips: [
                      AdminPill(orderStatusLabel(l, o.status), tone: orderStatusTone(o.status)),
                      AdminPill(l.adminPaymentsCredits(o.credits)),
                      if (o.refundPending) AdminPill(l.adminOrderRefundPendingPill, tone: AdminTone.warning),
                      if (_refunding.contains(o.id)) AdminPill(l.adminOrderRefundBusy, tone: AdminTone.info),
                    ],
                    onTap: () => _open(o, role),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _open(PaymentOrder order, AdminRole? role) async {
    final action = await showDialog<_OrderAction>(
      context: context,
      builder: (_) => OrderDetailsDialog(
        order: order,
        canRefund: (role?.canRefundOrders ?? false) && order.canRefund,
        refundInFlight: _refunding.contains(order.id),
        canOpenUser: (role?.can(AdminPermission.viewUsers) ?? false) && order.uid.isNotEmpty,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _OrderAction.openUser:
        await context.push('/admin/users/${order.uid}');
      case _OrderAction.refund:
        await _refund(order);
    }
  }

  Future<void> _refund(PaymentOrder order) async {
    final l = AppLocalizations.of(context)!;
    if (_refunding.contains(order.id)) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => RefundOrderDialog(order: order),
    );
    if (reason == null || !mounted || !_refunding.add(order.id)) return;
    setState(() {});
    try {
      final r = await ref.read(adminFunctionsServiceProvider).refundOrder(order.id, reason);
      if (!mounted) return;
      showAdminSnack(
        context,
        r.refunded ? l.adminOrderRefundDone(r.creditsClawedBack) : l.adminOrderRefundPending,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, refundOrderErrorMessage(l, e), error: true);
      // No answer in time: the refund may have gone through — show what
      // the order says now instead of inviting a blind retry.
      if (isRefundOutcomeUnknown(e)) await _reload();
    } finally {
      _refunding.remove(order.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reload() async {
    await ref.read(paymentOrdersPageProvider(_status).notifier).refresh();
    ref.invalidate(revenueProvider);
  }
}

enum _OrderAction { openUser, refund }

/// Every field of one `payment_orders` document, plus the actions the role
/// may take (open the user, refund).
class OrderDetailsDialog extends StatelessWidget {
  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.canRefund,
    required this.canOpenUser,
    this.refundInFlight = false,
  });

  final PaymentOrder order;
  final bool canRefund;
  final bool canOpenUser;

  /// A refund of this order was sent and has not answered yet: the refund
  /// button is shown disabled.
  final bool refundInFlight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final o = order;
    final refund = o.refund;
    final requested = o.refundRequested;
    return AlertDialog(
      title: Text(l.adminOrderTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AdminPill(orderStatusLabel(l, o.status), tone: orderStatusTone(o.status)),
              ),
              const SizedBox(height: AppSpacing.sm),
              AdminKeyValue(l.adminOrderId, o.id),
              AdminKeyValue(l.adminOrderUser, o.uid.isEmpty ? '—' : o.uid),
              AdminKeyValue(l.adminOrderProduct, o.productId),
              AdminKeyValue(l.adminOrderCredits, '${o.credits}'),
              AdminKeyValue(l.adminOrderAmount, orderAmountLabel(l, o)),
              AdminKeyValue(l.adminOrderProvider, o.provider.isEmpty ? '—' : o.provider),
              AdminKeyValue(l.adminOrderProviderRef, o.providerRef ?? '—'),
              AdminKeyValue(l.adminOrderGranted, o.granted ? l.adminYes : l.adminNo),
              AdminKeyValue(l.adminOrderCreated, formatAdminDate(o.createdAt)),
              AdminKeyValue(l.adminOrderPaid, formatAdminDate(o.paidAt)),
              if (o.expiresAt != null && (o.status == 'created' || o.status == 'pending' || o.status == 'expired'))
                AdminKeyValue(l.adminOrderExpires, formatAdminDate(o.expiresAt)),
              AdminKeyValue(l.adminOrderUpdated, formatAdminDate(o.updatedAt)),
              if (o.failureCode != null) AdminKeyValue(l.adminOrderFailure, o.failureCode!),
              if (o.paidWithoutCredits) ...[
                const SizedBox(height: AppSpacing.sm),
                AdminBanner(
                  key: const ValueKey('order_no_credits'),
                  icon: Icons.info_outline,
                  tone: AdminTone.info,
                  margin: EdgeInsets.zero,
                  // The refund hint only next to a refund button this viewer can use.
                  message: canRefund ? l.adminOrderNoCreditsNote : l.adminOrderNoCreditsFact,
                ),
              ],
              if (refund != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AdminBanner(
                  icon: Icons.undo,
                  tone: AdminTone.warning,
                  margin: EdgeInsets.zero,
                  message: [
                    l.adminOrderRefundInfo(
                      formatAdminDate(refund.at),
                      _refundSourceLabel(l, refund.source),
                      refund.creditsClawedBack,
                    ),
                    if (refund.debtAdded > 0) l.adminOrderRefundDebt(refund.debtAdded),
                  ].join(' '),
                ),
              ],
              if (o.refundPending && requested != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AdminBanner(
                  icon: Icons.hourglass_top,
                  tone: AdminTone.info,
                  margin: EdgeInsets.zero,
                  message: l.adminOrderRefundRequested(
                    formatAdminDate(requested.at),
                    requested.reason.isEmpty ? '—' : requested.reason,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (canOpenUser)
          TextButton(
            key: const ValueKey('order_open_user'),
            onPressed: () => Navigator.pop(context, _OrderAction.openUser),
            child: Text(l.adminOrderOpenUser),
          ),
        if (canRefund)
          TextButton(
            key: const ValueKey('order_refund'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: refundInFlight ? null : () => Navigator.pop(context, _OrderAction.refund),
            child: Text(refundInFlight ? l.adminOrderRefundBusy : l.adminOrderRefundAction),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.adminClose)),
      ],
    );
  }
}

/// Confirmation for `adminRefundOrder`: what happens (money back, credits
/// clawed back, debt if spent) and a required reason (3–200 characters).
/// Pops the trimmed reason, or `null` when cancelled.
class RefundOrderDialog extends StatefulWidget {
  const RefundOrderDialog({super.key, required this.order});
  final PaymentOrder order;

  @override
  State<RefundOrderDialog> createState() => _RefundOrderDialogState();
}

class _RefundOrderDialogState extends State<RefundOrderDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final o = widget.order;
    final valid = validRefundReason(_reason.text);
    final length = _reason.text.trim().length;
    return AlertDialog(
      title: Text(l.adminOrderRefundTitle),
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
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                // Paid for a deleted account: money back only, no clawback.
                message: o.paidWithoutCredits
                    ? l.adminOrderRefundBodyNoCredits(orderAmountLabel(l, o))
                    : l.adminOrderRefundBody(orderAmountLabel(l, o), o.credits),
              ),
              AdminKeyValue(l.adminOrderId, o.id),
              AdminKeyValue(l.adminOrderUser, o.uid),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('refund_reason'),
                controller: _reason,
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 4,
                maxLength: kRefundReasonMax,
                decoration: InputDecoration(
                  labelText: l.adminReason,
                  helperText: l.adminOrderRefundReasonHelp(kRefundReasonMin, kRefundReasonMax),
                  counterText: '$length / $kRefundReasonMax',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.adminCancel)),
        FilledButton(
          key: const ValueKey('refund_confirm'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: valid == null ? null : () => Navigator.pop(context, valid),
          child: Text(l.adminOrderRefundAction),
        ),
      ],
    );
  }
}

/// Paid website orders per Bishkek day for the last 30 days, with the total.
class RevenueTab extends ConsumerWidget {
  const RevenueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final revenue = ref.watch(revenueProvider);
    return revenue.when(
      loading: () => const AdminLoadingView(),
      error: (e, _) => isAdminAccessDenied(e)
          ? AdminAccessDeniedView(message: l.adminOrdersDenied, onRetry: () => ref.invalidate(revenueProvider))
          : AdminErrorView(error: e, onRetry: () => ref.invalidate(revenueProvider)),
      data: (s) => RefreshIndicator(
        onRefresh: () => ref.refresh(revenueProvider.future),
        child: RevenueSummaryView(summary: s),
      ),
    );
  }
}

class RevenueSummaryView extends StatelessWidget {
  const RevenueSummaryView({super.key, required this.summary});
  final RevenueSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = summary;
    final max = s.maxDaySom;
    return AdminPageBody(
      maxWidth: 720,
      children: [
        AdminCard(
          key: const ValueKey('revenue_total'),
          title: l.adminRevenueTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.adminSom(s.totalSom), style: text.headlineMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(l.adminRevenueOrders(s.totalOrders), style: TextStyle(color: t.textSecondary)),
              if (s.refundedOrders > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(l.adminRevenueRefunded(l.adminSom(s.refundedSom), s.refundedOrders),
                    style: TextStyle(color: t.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(l.adminRevenueNote, style: text.bodySmall?.copyWith(color: t.textTertiary)),
            ],
          ),
        ),
        if (s.truncated)
          AdminBanner(
            message: l.adminRevenueTruncated(s.totalOrders + s.refundedOrders),
            icon: Icons.warning_amber_outlined,
            tone: AdminTone.warning,
          ),
        AdminCard(
          title: l.adminRevenueByDay,
          child: s.totalOrders == 0
              ? Text(l.adminRevenueEmpty, style: TextStyle(color: t.textSecondary))
              : Column(
                  children: [
                    for (final d in s.days) _RevenueDayRow(day: d, max: max),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One day: date, order count and amount as text, plus a thin bar
/// proportional to the day's amount (the numbers carry the value; the bar
/// only helps to scan).
class _RevenueDayRow extends StatelessWidget {
  const _RevenueDayRow({required this.day, required this.max});
  final RevenueDay day;
  final int max;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final empty = day.amountSom == 0;
    final ratio = max <= 0 ? 0.0 : day.amountSom / max;
    return Semantics(
      label: '${day.day}: ${l.adminSom(day.amountSom)}, ${l.adminRevenueOrders(day.orders)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(day.day,
                      style: text.bodyMedium?.copyWith(color: empty ? t.textTertiary : null)),
                ),
                if (!empty)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(l.adminRevenueOrders(day.orders),
                        style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ),
                Text(l.adminSom(day.amountSom),
                    style: text.bodyMedium?.copyWith(
                      color: empty ? t.textTertiary : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
            if (!empty) ...[
              const SizedBox(height: AppSpacing.xxs),
              LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 6,
                    width: (c.maxWidth * ratio).clamp(4.0, c.maxWidth),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
