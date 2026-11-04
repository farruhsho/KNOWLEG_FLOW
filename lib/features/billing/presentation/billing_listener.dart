import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/billing_providers.dart';
import '../application/billing_service.dart';
import 'billing_messages.dart';

/// Sits under `MaterialApp.builder` for the whole app lifetime: starts the
/// billing service once (purchase stream + re-send of unfinished purchases)
/// and turns its notices into snackbars.
///
/// Background notices (start-up re-sends) are shown only when they carry
/// good news (credits granted); failures are shown only for purchases the
/// user is actively waiting for.
class BillingListener extends ConsumerStatefulWidget {
  const BillingListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BillingListener> createState() => _BillingListenerState();
}

class _BillingListenerState extends ConsumerState<BillingListener> {
  StreamSubscription<BillingNotice>? _sub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(billingServiceProvider);
    _sub = service.notices.listen(_show);
    unawaited(service.start());
  }

  void _show(BillingNotice notice) {
    if (!mounted) return;
    final visible = notice.userInitiated || notice.kind == BillingNoticeKind.granted;
    if (!visible) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (l10n == null || messenger == null) return;
    final text = l10n.billingNoticeMessage(notice);
    if (text == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
