import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/billing_providers.dart';
import '../../data/web_payment_gateway.dart';
import '../../domain/entitlements.dart';

/// What the return page currently knows about the order.
enum PayReturnPhase {
  checking,
  paid,
  failed,
  expired,
  refunded,

  /// Still `created` / `pending` after the polling window.
  stillPending,
  notFound,

  /// No order id in the URL nor saved on this device.
  noOrder,

  /// The status could not be read (connection).
  error,

  /// This build cannot call `paymentGetOrder` at all (web without the App
  /// Check site key, decision D7): said at once instead of polling.
  unavailable,
}

/// Where the payment provider sends the student back (RoutePaths.payReturn,
/// `BILLING_MODE=web`, ARCHITECTURE §10.3). Polls `paymentGetOrder` for up
/// to [maxWait] and shows paid / failed / expired / still pending, the new
/// balance and «Начать пробный». Credits are only ever granted by the
/// server's webhook — this page just reports what the server says.
class PayReturnPage extends ConsumerStatefulWidget {
  /// `?order=` of the route (may be missing — see [_resolveOrderId]).
  final String? orderId;
  final Duration pollInterval;
  final Duration maxWait;

  const PayReturnPage({
    super.key,
    this.orderId,
    this.pollInterval = const Duration(seconds: 3),
    this.maxWait = const Duration(minutes: 2),
  });

  @override
  ConsumerState<PayReturnPage> createState() => _PayReturnPageState();
}

class _PayReturnPageState extends ConsumerState<PayReturnPage> {
  PayReturnPhase _phase = PayReturnPhase.checking;
  String? _orderId;
  WebOrderState? _order;
  Timer? _timer;
  int _polls = 0;
  bool _disposed = false;

  int get _maxPolls {
    final interval = widget.pollInterval.inMilliseconds;
    if (interval <= 0) return 1;
    return (widget.maxWait.inMilliseconds / interval).ceil().clamp(1, 1000);
  }

  @override
  void initState() {
    super.initState();
    if (!ref.read(billingModeProvider).sellsOnWeb) return;
    if (!ref.read(webPaymentsAvailableProvider)) {
      // Every poll would fail the same way for two minutes.
      _phase = PayReturnPhase.unavailable;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  static bool _usable(String? id) =>
      id != null && id.trim().isNotEmpty && !id.contains('{');

  /// The route's `?order=`, else a `?order=` the provider put before the
  /// `#` of the page URL, else the order saved before the redirect.
  Future<String?> _resolveOrderId() async {
    if (_usable(widget.orderId)) return widget.orderId!.trim();
    final fromPage = ref.read(webPageUriProvider).queryParameters['order'];
    if (_usable(fromPage)) return fromPage!.trim();
    try {
      final saved = await ref.read(pendingWebOrderStoreProvider).read();
      if (_usable(saved)) return saved!.trim();
    } catch (_) {}
    return null;
  }

  Future<void> _begin() async {
    final id = _orderId ?? await _resolveOrderId();
    if (_disposed) return;
    if (id == null) {
      setState(() => _phase = PayReturnPhase.noOrder);
      return;
    }
    _orderId = id;
    _polls = 0;
    setState(() => _phase = PayReturnPhase.checking);
    await _poll();
  }

  Future<void> _poll() async {
    final id = _orderId;
    if (id == null || _disposed) return;
    _polls++;
    try {
      final order = await ref.read(webPaymentGatewayProvider).getOrder(id);
      if (_disposed) return;
      _order = order;
      final terminal = switch (order.status) {
        PaymentOrderStatuses.paid => PayReturnPhase.paid,
        PaymentOrderStatuses.failed => PayReturnPhase.failed,
        PaymentOrderStatuses.expired => PayReturnPhase.expired,
        PaymentOrderStatuses.refunded => PayReturnPhase.refunded,
        _ => null,
      };
      if (terminal != null) {
        unawaited(_clearPending(id));
        setState(() => _phase = terminal);
        return;
      }
      _scheduleOrStop(PayReturnPhase.stillPending);
    } on WebPaymentException catch (e) {
      if (_disposed) return;
      if (e.issue == WebPaymentIssue.orderNotFound) {
        unawaited(_clearPending(id));
        setState(() => _phase = PayReturnPhase.notFound);
        return;
      }
      // Connection hiccups while polling are retried within the window.
      _scheduleOrStop(PayReturnPhase.error);
    } catch (_) {
      if (_disposed) return;
      _scheduleOrStop(PayReturnPhase.error);
    }
  }

  void _scheduleOrStop(PayReturnPhase whenDone) {
    if (_polls >= _maxPolls) {
      setState(() => _phase = whenDone);
      return;
    }
    if (_phase != PayReturnPhase.checking) {
      setState(() => _phase = PayReturnPhase.checking);
    }
    _timer?.cancel();
    _timer = Timer(widget.pollInterval, _poll);
  }

  Future<void> _clearPending(String id) async {
    try {
      final store = ref.read(pendingWebOrderStoreProvider);
      if (await store.read() == id) await store.clear();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    if (!ref.watch(billingModeProvider).sellsOnWeb) {
      // Play / external builds have no site payments (and must not talk
      // about them): a neutral dead end.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: Text(l.shellNotFoundTitle,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.payReturnTitle), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(gutter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _body(context, l),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    final ent = ref.watch(entitlementsProvider).valueOrNull;
    final balance = _order?.balance ?? ent?.credits;
    void toStore() => context.go(RoutePaths.store);
    switch (_phase) {
      case PayReturnPhase.checking:
        return _Status(
          key: const ValueKey('pay_return_checking'),
          busy: true,
          title: l.payReturnChecking,
        );
      case PayReturnPhase.paid:
        return _Status(
          key: const ValueKey('pay_return_paid'),
          icon: Icons.check_circle_rounded,
          tone: _Tone.success,
          title: l.payReturnPaidTitle,
          lines: [
            l.payReturnPaidBody(_order?.credits ?? 0),
            if (balance != null) l.payReturnBalance(l.billingCreditsCount(balance)),
          ],
          primary: (
            key: const ValueKey('pay_return_start_exam'),
            label: l.payReturnStartExam,
            onPressed: () => context.go(RoutePaths.exams),
          ),
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.failed:
        return _Status(
          key: const ValueKey('pay_return_failed'),
          icon: Icons.error_outline_rounded,
          tone: _Tone.danger,
          title: l.payReturnFailedTitle,
          lines: [l.payReturnFailedBody],
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.expired:
        return _Status(
          key: const ValueKey('pay_return_expired'),
          icon: Icons.timer_off_outlined,
          tone: _Tone.warning,
          title: l.payReturnExpiredTitle,
          lines: [l.payReturnExpiredBody],
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.refunded:
        return _Status(
          key: const ValueKey('pay_return_refunded'),
          icon: Icons.undo_rounded,
          tone: _Tone.warning,
          title: l.payReturnRefundedTitle,
          lines: [
            l.payReturnRefundedBody,
            if (balance != null) l.payReturnBalance(l.billingCreditsCount(balance)),
          ],
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.stillPending:
        return _Status(
          key: const ValueKey('pay_return_pending'),
          icon: Icons.schedule_rounded,
          tone: _Tone.warning,
          title: l.payReturnPendingTitle,
          lines: [l.payReturnPendingBody],
          primary: (
            key: const ValueKey('pay_return_check_again'),
            label: l.payReturnCheckAgain,
            onPressed: _begin,
          ),
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.notFound:
        return _Status(
          key: const ValueKey('pay_return_not_found'),
          icon: Icons.search_off_rounded,
          tone: _Tone.danger,
          title: l.payReturnNotFound,
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.noOrder:
        return _Status(
          key: const ValueKey('pay_return_no_order'),
          icon: Icons.help_outline_rounded,
          tone: _Tone.warning,
          title: l.payReturnNoOrder,
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.unavailable:
        return _Status(
          key: const ValueKey('pay_return_unavailable'),
          icon: Icons.cloud_off_rounded,
          tone: _Tone.warning,
          title: l.payReturnUnavailableTitle,
          lines: [
            l.payReturnUnavailableBody,
            if (balance != null) l.payReturnBalance(l.billingCreditsCount(balance)),
          ],
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
      case PayReturnPhase.error:
        return _Status(
          key: const ValueKey('pay_return_error'),
          icon: Icons.wifi_off_rounded,
          tone: _Tone.danger,
          title: l.payReturnNetworkError,
          primary: (
            key: const ValueKey('pay_return_check_again'),
            label: l.payReturnCheckAgain,
            onPressed: _begin,
          ),
          secondary: (label: l.payReturnToStore, onPressed: toStore),
        );
    }
  }
}

enum _Tone { neutral, success, warning, danger }

typedef _Action = ({String label, VoidCallback onPressed});
typedef _KeyedAction = ({Key key, String label, VoidCallback onPressed});

class _Status extends StatelessWidget {
  final IconData? icon;
  final bool busy;
  final _Tone tone;
  final String title;
  final List<String> lines;
  final _KeyedAction? primary;
  final _Action? secondary;

  const _Status({
    super.key,
    required this.title,
    this.icon,
    this.busy = false,
    this.tone = _Tone.neutral,
    this.lines = const [],
    this.primary,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = switch (tone) {
      _Tone.success => tokens.success,
      _Tone.warning => tokens.warning,
      _Tone.danger => tokens.danger,
      _Tone.neutral => tokens.textSecondary,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: busy
              ? const SizedBox.square(
                  dimension: 36, child: CircularProgressIndicator(strokeWidth: 3))
              : Icon(icon, size: 48, color: color),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        for (final line in lines) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(line, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ],
        if (primary != null) ...[
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: primary!.key,
            onPressed: primary!.onPressed,
            child: Text(primary!.label),
          ),
        ],
        if (secondary != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: secondary!.onPressed, child: Text(secondary!.label)),
        ],
      ],
    );
  }
}
