import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/navigation/nav_helpers.dart';
import '../../../core/routes/route_paths.dart';
import '../../../l10n/app_localizations.dart';
import '../../billing/application/billing_providers.dart';
import '../../tutor/presentation/widgets/tutor_markdown.dart';
import '../legal_documents.dart';

/// A bundled legal text (public offer, refund policy) as a readable page.
///
/// Offered only where the build takes payments on the site
/// (`BILLING_MODE=web`); a consumption-only Android build never links here,
/// and if it is opened anyway it shows nothing about payments.
class LegalDocumentPage extends ConsumerWidget {
  final LegalDocument document;

  const LegalDocumentPage({super.key, required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final title = switch (document) {
      LegalDocument.offer => l.billingLegalOffer,
      LegalDocument.refund => l.billingLegalRefund,
    };
    final gutter = AppSpacing.gutter(context);
    if (!ref.watch(billingModeProvider).sellsOnWeb) {
      // External / Play builds: no route to payment terms (Play policy).
      return Scaffold(
        appBar: AppBar(leading: const SafeBackButton(fallback: RoutePaths.profile)),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: Text(l.shellNotFoundTitle, style: theme.textTheme.titleMedium),
          ),
        ),
      );
    }
    final text = ref.watch(legalDocumentTextProvider(document));
    final ruOnly = Localizations.localeOf(context).languageCode != 'ru';
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallback: RoutePaths.store),
        title: Text(title),
      ),
      body: text.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.billingLegalLoadError, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(legalDocumentTextProvider(document)),
                  child: Text(l.billingRetry),
                ),
              ],
            ),
          ),
        ),
        data: (md) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, AppSpacing.xxxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('legal_draft_note'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: Text(
                      ruOnly
                          ? '${l.billingLegalDraftNote} ${l.billingLegalRuOnly}'
                          : l.billingLegalDraftNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SelectionArea(child: TutorMarkdown(md, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Публичная оферта» · «Правила возврата» — next to the web pay button.
class LegalDocumentLinks extends StatelessWidget {
  const LegalDocumentLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        TextButton.icon(
          key: const ValueKey('legal_offer_link'),
          onPressed: () => context.push(LegalDocument.offer.route),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: Text(l.billingLegalOffer),
        ),
        TextButton.icon(
          key: const ValueKey('legal_refund_link'),
          onPressed: () => context.push(LegalDocument.refund.route),
          icon: const Icon(Icons.assignment_return_outlined, size: 18),
          label: Text(l.billingLegalRefund),
        ),
      ],
    );
  }
}
