import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/billing_service.dart';
import '../data/web_payment_gateway.dart';
import '../domain/billing_records.dart';
import '../domain/entitlements.dart';
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

  /// [neutral]: `BILLING_MODE=external` wording, which never mentions buying.
  String billingLedgerReasonLabel(LedgerReason r, {bool neutral = false}) => switch (r) {
        LedgerReason.purchase => neutral ? billingReasonCreditsAdded : billingReasonPurchase,
        LedgerReason.examStart => billingReasonExamStart,
        LedgerReason.refund => billingReasonRefund,
        LedgerReason.adminGrant => billingReasonAdminGrant,
        LedgerReason.freeFirst => billingReasonFreeFirst,
        LedgerReason.other => billingReasonOther,
      };

  /// Free-exam status for the balance card (D14): remaining =
  /// `config/pricing.free_exams_per_user` − `free_exams_used_count`.
  /// Null when the account never had free exams (allowance 0, none used).
  String? billingFreeExamsLine(Entitlements e) {
    final left = e.freeExamsRemaining;
    if (left > 0) {
      return e.freeExamsAllowed == 1 ? billingFreeExamAvailable : billingFreeExamsLeft(left);
    }
    if (e.freeExamsUsedCount > 0) return billingFreeExamUsed;
    return null;
  }

  /// Site payment errors (§10.3).
  String billingWebIssueMessage(WebPaymentIssue issue) => switch (issue) {
        WebPaymentIssue.paymentsDisabled => billingWebPaymentsDisabled,
        WebPaymentIssue.productUnavailable => billingWebProductUnavailable,
        WebPaymentIssue.rateLimited => billingWebRateLimited,
        WebPaymentIssue.unauthenticated => billingErrorNotSignedIn,
        WebPaymentIssue.orderNotFound => payReturnNotFound,
        WebPaymentIssue.invalidCheckout ||
        WebPaymentIssue.network ||
        WebPaymentIssue.unknown =>
          billingWebOrderError,
      };

  /// Title of a web product: the `config/pricing` label override, else
  /// "1 тест" / "5 тестов" from its own credit count.
  String billingWebProductTitle(PricingConfig pricing, WebProduct product, String languageCode) =>
      pricing.labelFor(product.productId, languageCode) ??
      billingProductTests(product.credits);

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
