import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/billing_providers.dart';
import '../../application/billing_service.dart';
import '../../domain/entitlements.dart';
import '../../domain/pricing_config.dart';
import '../billing_messages.dart';
import '../widgets/billing_state_views.dart';

/// Exam access store (RoutePaths.store).
///
/// * `play` builds: balance, Google Play products with the Play price string,
///   restore, honest copy.
/// * `external` builds: balance and one neutral sentence — no prices, no
///   purchase buttons, no links (Play payments policy).
///
/// Nothing on this page unlocks content: the balance comes from the
/// server-written `entitlements/{uid}` document.
class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  BillingService? _service;

  @override
  void initState() {
    super.initState();
    if (ref.read(billingModeProvider).sellsInApp) {
      _service = ref.read(billingServiceProvider);
      // Normally already started by the app-level billing listener; this is
      // a no-op then, and a safety net if the listener is not wired.
      WidgetsBinding.instance.addPostFrameCallback((_) => _service?.start());
    }
  }

  @override
  void dispose() {
    _service?.acknowledgeStatus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sellsInApp = ref.watch(canSellProvider);
    // Play Billing (and so purchase verification) exists only on Android.
    final playPlatform = ref.watch(playBillingPlatformProvider);
    final gutter = AppSpacing.gutter(context);
    final signedIn = ref.watch(billingUidProvider.select((u) => u.valueOrNull != null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billingStoreTitle),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: sellsInApp ? l10n.billingHistoryTooltip : l10n.billingCreditHistoryTitle,
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.push(RoutePaths.transactions),
            ),
        ],
      ),
      // The purchase status sits outside the scroll view so it stays visible
      // wherever the user had scrolled to before tapping a product.
      bottomNavigationBar: sellsInApp && playPlatform ? const _PurchaseStatus() : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xxxl),
        children: [
          const _BalanceSection(),
          const SizedBox(height: AppSpacing.xl),
          if (sellsInApp && playPlatform) ...const [
            _ProductsSection(),
            SizedBox(height: AppSpacing.sm),
            _RestoreButton(),
            SizedBox(height: AppSpacing.lg),
            _HonestCopy(),
          ] else if (sellsInApp) ...[
            // Web / desktop / iOS: no Google Play Billing on this platform.
            BillingMessage(
              icon: Icons.phone_android_outlined,
              title: l10n.billingUnsupportedPlatformTitle,
              message: l10n.billingUnsupportedPlatformBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _HonestCopy(),
          ] else
            const _ExternalInfo(),
        ],
      ),
    );
  }
}

class _BalanceSection extends ConsumerWidget {
  const _BalanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(billingUidProvider);
    if (uid.hasValue && uid.value == null) {
      return BillingMessage(
        icon: Icons.person_outline,
        message: l10n.billingSignInRequired,
      );
    }
    final ent = ref.watch(entitlementsProvider);
    return ent.when(
      skipLoadingOnReload: true,
      loading: () => BillingStatusLine(text: l10n.billingBalanceTitle, busy: true),
      error: (_, __) => BillingMessage(
        icon: Icons.error_outline,
        tone: BillingTone.danger,
        message: l10n.billingBalanceError,
        actionLabel: l10n.billingRetry,
        onAction: () => ref.invalidate(entitlementsProvider),
      ),
      data: (e) => _BalanceCard(entitlements: e),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.entitlements});

  final Entitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final free = entitlements.hasFreeExam;
    final freeLine = l10n.billingFreeExamsLine(entitlements);
    return BillingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.billingBalanceTitle,
              style: theme.textTheme.labelLarge?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.billingCreditsCount(entitlements.credits),
            style: theme.textTheme.headlineMedium,
          ),
          if (freeLine != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  free ? Icons.card_giftcard_outlined : Icons.check_circle_outline,
                  size: 20,
                  color: free ? tokens.success : tokens.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(freeLine, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.billingCreditRule, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PurchaseStatus extends ConsumerWidget {
  const _PurchaseStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.watch(billingServiceProvider);
    return ValueListenableBuilder<PurchaseFlowState>(
      valueListenable: service.flow,
      builder: (context, s, _) {
        final Widget? line = switch (s.phase) {
          PurchasePhase.idle => null,
          PurchasePhase.launching => BillingStatusLine(text: l10n.billingStatusLaunching, busy: true),
          PurchasePhase.verifying => BillingStatusLine(text: l10n.billingStatusVerifying, busy: true),
          PurchasePhase.restoring => BillingStatusLine(text: l10n.billingRestoreStarted, busy: true),
          PurchasePhase.pendingPayment => BillingStatusLine(
              text: l10n.billingStatusPending,
              icon: Icons.schedule,
              tone: BillingTone.warning,
            ),
          PurchasePhase.granted => BillingStatusLine(
              text: l10n.billingStatusGranted,
              icon: Icons.check_circle_outline,
              tone: BillingTone.success,
            ),
          PurchasePhase.canceled => BillingStatusLine(text: l10n.billingStatusCanceled),
          PurchasePhase.failed => BillingStatusLine(
              text: s.issue == null ? l10n.billingErrorStore : l10n.billingIssueMessage(s.issue!),
              icon: Icons.error_outline,
              tone: BillingTone.danger,
            ),
        };
        if (line == null) return const SizedBox.shrink();
        final gutter = AppSpacing.gutter(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: context.tokens.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.sm),
              child: line,
            ),
          ),
        );
      },
    );
  }
}

class _ProductsSection extends ConsumerWidget {
  const _ProductsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final catalog = ref.watch(storeCatalogProvider);
    final pricing = ref.watch(pricingConfigProvider).valueOrNull ?? PricingConfig.defaults;
    void retry() => ref.invalidate(storeCatalogProvider);

    final Widget content = catalog.when(
      loading: () => BillingStatusLine(text: l10n.billingLoadingProducts, busy: true),
      error: (_, __) => BillingMessage(
        icon: Icons.cloud_off_outlined,
        tone: BillingTone.danger,
        message: l10n.billingProductsError,
        actionLabel: l10n.billingRetry,
        onAction: retry,
      ),
      data: (c) {
        if (!c.available) {
          return BillingMessage(
            icon: Icons.shopping_bag_outlined,
            tone: BillingTone.warning,
            title: l10n.billingUnavailableTitle,
            message: l10n.billingUnavailableBody,
            actionLabel: l10n.billingRetry,
            onAction: retry,
          );
        }
        if (c.isEmpty) {
          return BillingMessage(
            icon: Icons.inventory_2_outlined,
            message: l10n.billingProductsEmpty,
            actionLabel: l10n.billingRetry,
            onAction: retry,
          );
        }
        final products = [...c.products]
          ..sort((a, b) => pricing.orderFor(a.id).compareTo(pricing.orderFor(b.id)));
        return Column(
          children: [
            for (final p in products)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ProductCard(product: p, pricing: pricing),
              ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.billingProductsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        content,
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.pricing});

  final ProductDetails product;
  final PricingConfig pricing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final service = ref.watch(billingServiceProvider);
    final credits = pricing.creditsFor(product.id);
    final title = l10n.billingProductTitle(pricing, product.id, lang);

    return BillingCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(l10n.billingProductSubtitle(credits), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ValueListenableBuilder<PurchaseFlowState>(
            valueListenable: service.flow,
            builder: (context, s, _) {
              final busyHere = s.isBusy && s.productId == product.id;
              return Semantics(
                button: true,
                label: l10n.billingBuySemantics(title, product.price),
                excludeSemantics: true,
                child: FilledButton(
                  key: ValueKey('buy_${product.id}'),
                  onPressed: s.isBusy ? null : () => service.buy(product),
                  child: busyHere
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Text(product.price),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.watch(billingServiceProvider);
    return ValueListenableBuilder<PurchaseFlowState>(
      valueListenable: service.flow,
      builder: (context, s, _) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: s.isBusy ? null : service.restore,
          icon: const Icon(Icons.restore),
          label: Text(l10n.billingRestore),
        ),
      ),
    );
  }
}

class _HonestCopy extends StatelessWidget {
  const _HonestCopy();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(icon: Icons.verified_user_outlined, text: l10n.billingHonestServer),
        _InfoRow(icon: Icons.school_outlined, text: l10n.billingHonestNoGuarantee),
        _InfoRow(icon: Icons.payments_outlined, text: l10n.billingHonestPayment),
      ],
    );
  }
}

class _ExternalInfo extends StatelessWidget {
  const _ExternalInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillingMessage(icon: Icons.info_outline, message: l10n.billingExternalInfo),
        const SizedBox(height: AppSpacing.md),
        _InfoRow(icon: Icons.sync, text: l10n.billingExternalNote),
        _InfoRow(icon: Icons.school_outlined, text: l10n.billingHonestNoGuarantee),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.tokens.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
