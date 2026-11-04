import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/region_model.dart';

/// Parses `assets/data/kg_regions.json` (`{"regions": [{oblast, districts}]}`).
List<RegionData> parseKgRegions(String jsonString) {
  final decoded = json.decode(jsonString);
  final list = decoded is Map ? decoded['regions'] : null;
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((r) => RegionData.fromJson(Map<String, dynamic>.from(r)))
      .where((r) => r.oblast.isNotEmpty)
      .toList(growable: false);
}

/// Oblasts and districts of Kyrgyzstan, loaded once from the bundled asset.
final kgRegionsProvider = FutureProvider<List<RegionData>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/kg_regions.json');
  return parseKgRegions(raw);
});
