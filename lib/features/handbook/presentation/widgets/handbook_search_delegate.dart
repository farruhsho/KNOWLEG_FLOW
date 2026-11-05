import 'package:flutter/material.dart';

import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/handbook_data.dart';

class HandbookSearchResult {
  final String categoryId;
  final String categoryTitle;
  final String sectionTitle;
  final String snippet;
  const HandbookSearchResult(this.categoryId, this.categoryTitle, this.sectionTitle, this.snippet);
}

/// Searches handbook titles and text in the content language. Returns the
/// chosen category id; the caller navigates.
class HandbookSearchDelegate extends SearchDelegate<String?> {
  final String lang;

  HandbookSearchDelegate({required this.lang, String? hint}) : super(searchFieldLabel: hint);

  static List<HandbookSearchResult> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final out = <HandbookSearchResult>[];
    for (final c in HandbookData.categories) {
      final cTitle = pickLocalized(c.title, lang);
      for (final s in c.sections) {
        final sTitle = pickLocalized(s.title, lang);
        final body = pickLocalized(s.body, lang);
        final hay = '$cTitle\n$sTitle\n$body'.toLowerCase();
        final idx = hay.indexOf(q);
        if (idx < 0) continue;
        final plain = body.replaceAll(RegExp(r'[*$#>`]'), '');
        final at = plain.toLowerCase().indexOf(q);
        final start = at < 0 ? 0 : (at - 40).clamp(0, plain.length);
        final end = (start + 120).clamp(0, plain.length);
        out.add(HandbookSearchResult(c.id, cTitle, sTitle, plain.substring(start, end).replaceAll('\n', ' ').trim()));
      }
    }
    return out;
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final results = search(query, lang);
    if (query.trim().length < 2) {
      return ListView(
        children: [
          for (final c in HandbookData.categories)
            ListTile(
              leading: Icon(c.icon),
              title: Text(pickLocalized(c.title, lang)),
              onTap: () => close(context, c.id),
            ),
        ],
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.learnNoSearchResults, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        return ListTile(
          title: Text(r.sectionTitle),
          subtitle: Text('${r.categoryTitle} · ${r.snippet}', maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => close(context, r.categoryId),
        );
      },
    );
  }
}
