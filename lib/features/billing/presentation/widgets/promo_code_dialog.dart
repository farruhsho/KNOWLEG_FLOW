import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/domain/social_codes.dart';
import '../../../social/domain/social_models.dart';
import '../../../social/presentation/social_messages.dart';
import '../../../social/presentation/widgets/social_widgets.dart';

/// Opens the promo code dialog (ARCHITECTURE §9.2). Resolves to the server's
/// answer when a code was redeemed, null otherwise. A promo code is not a
/// payment, so this works in both `BILLING_MODE`s.
Future<PromoRedeemResult?> showPromoCodeDialog(BuildContext context) =>
    showDialog<PromoRedeemResult>(context: context, builder: (_) => const PromoCodeDialog());

/// Enter a code → `promoRedeem` → "+N credits". Credits are granted only by
/// the server; the balance on the store page updates from
/// `entitlements/{uid}`.
class PromoCodeDialog extends ConsumerStatefulWidget {
  const PromoCodeDialog({super.key});

  @override
  ConsumerState<PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends ConsumerState<PromoCodeDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  PromoRedeemResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final code = SocialCodes.normalize(_controller.text);
    if (!SocialCodes.isPromoCode(code)) {
      setState(() => _error = l.socialErrorPromoFormat);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(socialRepositoryProvider).promoRedeem(code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.socialErrorMessage(e, SocialAction.promo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final result = _result;
    if (result != null) {
      final t = context.tokens;
      return AlertDialog(
        key: const ValueKey('promo_success'),
        icon: Icon(Icons.check_circle_outline, color: t.success),
        title: Text(l.socialPromoSuccess(result.credits)),
        content: result.balance == null
            ? null
            : Text(
                l.socialPromoBalance(result.balance!),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(result),
            child: Text(l.socialDone),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.socialPromoTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SocialMuted(l.socialPromoBody),
          const SizedBox(height: AppSpacing.md),
          SocialCodeField(
            key: const ValueKey('promo_code_field'),
            controller: _controller,
            maxLength: SocialCodes.promoMaxLength,
            label: l.socialPromoAction,
            errorText: _error,
            enabled: !_busy,
            autofocus: true,
            onSubmitted: (_) => _redeem(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.socialCancel),
        ),
        FilledButton(
          key: const ValueKey('promo_redeem'),
          onPressed: _busy ? null : _redeem,
          child: _busy ? const SocialButtonProgress() : Text(l.socialPromoRedeem),
        ),
      ],
    );
  }
}
