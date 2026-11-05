import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routes/route_paths.dart';

/// Legal texts bundled with the app (drafts for the lawyer, §10.3). The
/// sources of truth are `docs/legal/OFFER_ru.md` and `docs/legal/REFUND_ru.md`;
/// the assets are verbatim copies (a test keeps them in sync).
enum LegalDocument {
  offer('assets/data/legal_offer_ru.md', RoutePaths.legalOffer),
  refund('assets/data/legal_refund_ru.md', RoutePaths.legalRefund);

  final String asset;
  final String route;

  const LegalDocument(this.asset, this.route);
}

/// Asset bundle the documents are read from. Overridden in tests.
final legalAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// Markdown text of a legal document, unwrapped for display.
final legalDocumentTextProvider =
    FutureProvider.family<String, LegalDocument>((ref, doc) async =>
        unwrapMarkdown(await ref.watch(legalAssetBundleProvider).loadString(doc.asset)));

final _blockStart = RegExp(r'^(#{1,6}\s|[-*•]\s|\d{1,3}[.)]\s)');

/// Joins hard-wrapped source lines into one line per paragraph or list item,
/// so text reflows on narrow screens (the documents are wrapped at ~80
/// columns for review in Git).
String unwrapMarkdown(String source) {
  final out = <String>[];
  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final t = raw.trim();
    final startsBlock = t.isEmpty || _blockStart.hasMatch(t);
    final prev = out.isEmpty ? '' : out.last.trim();
    if (!startsBlock && prev.isNotEmpty && !prev.startsWith('#')) {
      out[out.length - 1] = '${out.last.trimRight()} $t';
    } else {
      out.add(raw);
    }
  }
  return out.join('\n');
}
