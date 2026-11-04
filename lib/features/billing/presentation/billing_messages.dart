import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/billing_service.dart';
import '../domain/billing_records.dart';
import '../domain/pricing_config.dart';

/// Localised copy for billing states and issues.
extension BillingL10n on AppLocalizations {
  String billingIssueMessage(BillingIssue issue) => switch (issue) {
        BillingIssue.notSignedIn => billingErrorNotSignedIn,
        BillingIssue.storeUnavailable => billingErrorStoreUnavailable,
        BillingIssue.productUnavailable => billingErrorProductUnavailable,
        BillingIssue.launchFailed => billingErrorLaunch,
        BillingIssue.alreadyOwned => billingErrorAlreadyOwned,
        BillingIssue.storeError => billingErrorStore,
        BillingIssue.verificationDeferred => billingErrorVerifyDeferred,
        BillingIssue.invalid => billingErrorInvalid,
        BillingIssue.accountMismatch => billingErrorAccountMismatch,
      };

  /// Message for a one-off notice, or null when nothing should be shown.
  String? billingNoticeMessage(BillingNotice n) => switch (n.kind) {
        BillingNoticeKind.granted => billingStatusGranted,
        BillingNoticeKind.pending => billingStatusPending,
        BillingNoticeKind.canceled => billingStatusCanceled,
        BillingNoticeKind.restoreStarted => billingRestoreStarted,
        BillingNoticeKind.restoreFinished => billingRestoreDone,
        BillingNoticeKind.failed =>
          n.issue == null ? null : billingIssueMessage(n.issue!),
      };

  String billingPurchaseStateLabel(PurchaseRecordState s) => switch (s) {
        PurchaseRecordState.granted => billingStateGranted,
        PurchaseRecordState.pending => billingStatePending,
        PurchaseRecordState.refunded => billingStateRefunded,
        PurchaseRecordState.revoked => billingStateRevoked,
        PurchaseRecordState.invalid || PurchaseRecordState.unknown => billingStateInvalid,
      };

  String billingLedgerReasonLabel(LedgerReason r) => switch (r) {
        LedgerReason.purchase => billingReasonPurchase,
        LedgerReason.examStart => billingReasonExamStart,
        LedgerReason.refund => billingReasonRefund,
        LedgerReason.adminGrant => billingReasonAdminGrant,
        LedgerReason.freeFirst => billingReasonFreeFirst,
        LedgerReason.other => billingReasonOther,
      };

  /// "1 тест" / "5 тестов", or the `config/pricing` label override.
  String billingProductTitle(PricingConfig pricing, String productId, String languageCode) =>
      pricing.labelFor(productId, languageCode) ??
      billingProductTests(pricing.creditsFor(productId));
}

/// Medium date + time in the current locale, without depending on intl date
/// symbol data being initialised.
String formatBillingDate(BuildContext context, DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  final m = MaterialLocalizations.of(context);
  return '${m.formatMediumDate(local)}, '
      '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}
