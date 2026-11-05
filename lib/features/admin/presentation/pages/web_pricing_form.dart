import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/pricing_config.dart';
import '../widgets/admin_widgets.dart';

/// `config/pricing.web_products` editor (§10.3, super_admin) via
/// `adminUpdatePricing({webProducts})`: credits, price in som and whether a
/// product is on sale. `exam_single` always grants 1 credit; moving it away
/// from [kBasePriceSom] needs the owner's consent and a typed confirmation.
class WebPricingForm extends ConsumerStatefulWidget {
  const WebPricingForm({super.key, required this.initial});
  final PricingConfig initial;

  @override
  ConsumerState<WebPricingForm> createState() => _WebPricingFormState();
}

class _WebPricingFormState extends ConsumerState<WebPricingForm> with AutomaticKeepAliveClientMixin {
  late List<String> _ids;
  final Map<String, TextEditingController> _credits = {};
  final Map<String, TextEditingController> _amount = {};
  final Map<String, bool> _enabled = {};
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  /// Stored products plus the §10.3 defaults for known ids that are missing.
  Map<String, WebProductConfig> get _source => {
        ...kDefaultWebProducts,
        ...widget.initial.webProducts,
      };

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(WebPricingForm old) {
    super.didUpdateWidget(old);
    if (!sameWebProducts(old.initial.webProducts, widget.initial.webProducts) ||
        old.initial.webProductsExist != widget.initial.webProductsExist) {
      // The fields still hold the old controllers until the next build.
      final stale = [..._credits.values, ..._amount.values];
      _credits.clear();
      _amount.clear();
      _enabled.clear();
      _reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in stale) {
          c.dispose();
        }
      });
    }
  }

  void _reset() {
    final source = _source;
    _ids = orderedWebProductIds(source.keys, source);
    for (final id in _ids) {
      final p = source[id]!;
      _credits[id] = TextEditingController(text: '${id == kBaseWebProductId ? 1 : p.credits}');
      _amount[id] = TextEditingController(text: '${p.amountSom}');
      _enabled[id] = p.enabled;
    }
  }

  void _disposeControllers() {
    for (final c in [..._credits.values, ..._amount.values]) {
      c.dispose();
    }
    _credits.clear();
    _amount.clear();
    _enabled.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Map<String, WebProductConfig> _current() => {
        for (final id in _ids)
          id: WebProductConfig(
            credits: id == kBaseWebProductId ? 1 : int.tryParse(_credits[id]!.text.trim()) ?? 0,
            amountSom: int.tryParse(_amount[id]!.text.trim()) ?? 0,
            enabled: _enabled[id] ?? false,
          ),
      };

  String _issue(AppLocalizations l, String code) => switch (code) {
        WebPricingIssue.creditsRange => l.adminWebPricingIssueCredits(kWebCreditsMin, kWebCreditsMax),
        WebPricingIssue.amountRange => l.adminWebPricingIssueAmount(kWebAmountMin, kWebAmountMax),
        WebPricingIssue.baseMissing => l.adminWebPricingIssueBase,
        WebPricingIssue.baseCredits => l.adminPricingIssueSingle,
        WebPricingIssue.invalidId => l.adminPricingIssueProduct,
        _ => code,
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final products = _current();
    final issues = validateWebProducts(products);
    if (issues.isNotEmpty) {
      showAdminSnack(context, issues.map((c) => _issue(l, c)).join('\n'), error: true);
      return;
    }
    if (widget.initial.webProductsExist && sameWebProducts(products, widget.initial.webProducts)) {
      showAdminSnack(context, l.adminWebPricingNoChanges);
      return;
    }
    final noneOnSale = products.values.every((p) => !p.enabled);
    final bool ok;
    if (basePriceChanged(products)) {
      ok = await showDialog<bool>(
            context: context,
            builder: (_) => BasePriceConfirmDialog(amountSom: products[kBaseWebProductId]!.amountSom),
          ) ??
          false;
    } else {
      ok = await confirmAdminAction(
        context,
        title: l.adminWebPricingConfirmTitle,
        message: [
          l.adminWebPricingConfirmBody,
          if (noneOnSale) l.adminWebPricingNoneEnabled,
        ].join('\n\n'),
        confirmLabel: l.adminSave,
      );
    }
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminFunctionsServiceProvider).updateWebPricing(products);
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
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final noneOnSale = _ids.every((id) => !(_enabled[id] ?? false));
    return AdminPageBody(
      maxWidth: 720,
      children: [
        AdminBanner(message: l.adminWebPricingWarning, icon: Icons.storefront_outlined, tone: AdminTone.info),
        if (!widget.initial.webProductsExist)
          AdminCard(child: Text(l.adminWebPricingDefaults, style: TextStyle(color: t.textSecondary))),
        if (noneOnSale)
          AdminBanner(message: l.adminWebPricingNoneEnabled, icon: Icons.block, tone: AdminTone.warning),
        for (final id in _ids) _productCard(l, id),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey('web_pricing_save'),
            onPressed: _saving ? null : _save,
            child: Text(l.adminSave),
          ),
        ),
      ],
    );
  }

  Widget _productCard(AppLocalizations l, String id) {
    final t = context.tokens;
    final isBase = id == kBaseWebProductId;
    final amount = int.tryParse(_amount[id]!.text.trim());
    final credits = isBase ? 1 : int.tryParse(_credits[id]!.text.trim());
    final perCredit = (amount != null && credits != null && credits > 1) ? (amount / credits).round() : null;
    return AdminCard(
      key: ValueKey('web_product_$id'),
      title: id,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.adminWebProductEnabled, style: TextStyle(color: t.textSecondary)),
          Switch(
            key: ValueKey('web_enabled_$id'),
            value: _enabled[id] ?? false,
            onChanged: _saving ? null : (v) => setState(() => _enabled[id] = v),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 132,
                child: TextField(
                  key: ValueKey('web_credits_$id'),
                  controller: _credits[id],
                  enabled: !isBase && !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l.adminWebProductCredits),
                ),
              ),
              SizedBox(
                width: 132,
                child: TextField(
                  key: ValueKey('web_amount_$id'),
                  controller: _amount[id],
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l.adminWebProductAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isBase ? l.adminWebProductSingleHelp : (perCredit == null ? '' : l.adminWebProductPerCredit(perCredit)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
          ),
          if (isBase && amount != null && amount != kBasePriceSom) ...[
            const SizedBox(height: AppSpacing.sm),
            AdminBanner(
              key: const ValueKey('web_base_changed'),
              margin: EdgeInsets.zero,
              icon: Icons.warning_amber_outlined,
              tone: AdminTone.warning,
              message: l.adminWebPricingBaseChanged(kBasePriceSom, amount),
            ),
          ],
        ],
      ),
    );
  }
}

/// Typed confirmation for a base price other than [kBasePriceSom]: the
/// super_admin repeats the new price; the server also requires
/// `confirmBasePriceChange: true`.
class BasePriceConfirmDialog extends StatefulWidget {
  const BasePriceConfirmDialog({super.key, required this.amountSom});
  final int amountSom;

  @override
  State<BasePriceConfirmDialog> createState() => _BasePriceConfirmDialogState();
}

class _BasePriceConfirmDialogState extends State<BasePriceConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final matches = basePriceConfirmationMatches(_typed.text, widget.amountSom);
    return AlertDialog(
      title: Text(l.adminWebPricingBaseTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminBanner(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                icon: Icons.warning_amber_outlined,
                tone: AdminTone.warning,
                message: l.adminWebPricingBaseChanged(kBasePriceSom, widget.amountSom),
              ),
              Text(l.adminWebPricingConfirmBody),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('base_price_confirm'),
                controller: _typed,
                autofocus: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.adminWebPricingConfirmType(widget.amountSom)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.adminCancel)),
        FilledButton(
          key: const ValueKey('base_price_confirm_button'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: Text(l.adminWebPricingBaseApply),
        ),
      ],
    );
  }
}
