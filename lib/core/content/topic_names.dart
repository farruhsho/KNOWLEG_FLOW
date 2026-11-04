import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Human-readable names of curriculum subjects, topics and subtopics
/// (`math.quadratic_equations` → «Квадратные уравнения»), so students never
/// see raw ids. Data: assets/data/topic_names.json, generated from
/// content/curriculum/topics.json by tools/content_pipeline/gen_topic_names.js.
class TopicNames {
  final Map<String, Map<String, String>> _names;

  const TopicNames(this._names);

  static const empty = TopicNames({});

  factory TopicNames.fromJson(Map<String, dynamic> json) {
    final raw = json['names'];
    final out = <String, Map<String, String>>{};
    if (raw is Map) {
      raw.forEach((id, v) {
        if (v is Map) {
          out[id.toString()] = {
            for (final e in v.entries)
              if (e.value is String && (e.value as String).isNotEmpty)
                e.key.toString(): e.value as String,
          };
        }
      });
    }
    return TopicNames(out);
  }

  /// Name of [id] in [lang] ('ru' | 'ky' | 'en'). Unknown ids fall back to the
  /// nearest known parent (`math.algebra.x` → «Алгебра»), then to a humanized
  /// last segment, never to the raw dotted id.
  String label(String id, String lang) {
    var key = id;
    while (key.isNotEmpty) {
      final n = _names[key];
      if (n != null) {
        final v = n[lang] ?? n['ru'] ?? n['en'];
        if (v != null) return v;
      }
      final dot = key.lastIndexOf('.');
      if (dot <= 0) break;
      key = key.substring(0, dot);
    }
    final last = id.split('.').last.replaceAll('_', ' ').trim();
    if (last.isEmpty) return id;
    return last[0].toUpperCase() + last.substring(1);
  }

  bool contains(String id) => _names.containsKey(id);
}

/// Loaded once from the bundled asset; resolves to [TopicNames.empty] if the
/// asset is missing so callers always get a usable (humanizing) instance.
final topicNamesProvider = FutureProvider<TopicNames>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/topic_names.json');
    return TopicNames.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return TopicNames.empty;
  }
});
