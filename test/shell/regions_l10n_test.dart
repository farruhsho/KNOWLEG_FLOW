import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/onboarding/data/kg_regions_provider.dart';
import 'package:knowledge_flow/features/onboarding/presentation/widgets/region_picker.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/shared/models/region_model.dart';

/// UX-11: region names are shown in the UI language; the stored value stays
/// the canonical Russian name (server region_id).
void main() {
  final regions = parseKgRegions(File('assets/data/kg_regions.json').readAsStringSync());

  test('every oblast and district has an id and ru/ky/en names', () {
    expect(regions, hasLength(9));
    final ids = <String>{};
    for (final r in regions) {
      expect(r.id, isNotEmpty);
      expect(ids.add(r.id), isTrue, reason: 'duplicate ${r.id}');
      expect(r.title.keys, containsAll(['ru', 'ky', 'en']), reason: r.oblast);
      expect(r.title['ru'], r.oblast, reason: 'ru name is the stored value');
      for (final d in r.districts) {
        expect(ids.add(d.id), isTrue, reason: 'duplicate ${d.id}');
        expect(d.title.keys, containsAll(['ru', 'ky', 'en']), reason: d.name);
        expect(d.title['ru'], d.name);
      }
    }
  });

  test('stored values are unchanged and ky names are Kyrgyz', () {
    final chuy = regions.firstWhere((r) => r.oblast == 'Чуйская область');
    expect(chuy.label('ky'), 'Чүй облусу');
    expect(chuy.label('en'), 'Chüy Region');
    expect(chuy.label('ru'), 'Чуйская область');
    expect(regions.firstWhere((r) => r.oblast == 'Ысык-Кульская область').label('ky'), 'Ысык-Көл облусу');
    expect(regionDisplayName(regions, 'Бишкек', 'ky'), 'Бишкек шаары');
    // Unknown (legacy) value is shown as stored.
    expect(regionDisplayName(regions, 'Неизвестно', 'ky'), 'Неизвестно');
    // Old asset shape without titles still works.
    expect(const RegionData(oblast: 'X', districts: []).label('ky'), 'X');
  });

  testWidgets('picker shows Kyrgyz names and reports the stored value', (tester) async {
    String? picked;
    await tester.pumpWidget(ProviderScope(
      overrides: [kgRegionsProvider.overrideWith((ref) async => regions)],
      child: MaterialApp(
        locale: const Locale('ky'),
        supportedLocales: const [Locale('ru'), Locale('ky'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: RegionPicker(
            oblast: null,
            district: null,
            onChanged: (o, _) => picked = o,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Чуйская область'), findsNothing);
    await tester.tap(find.text('Чүй облусу').last);
    await tester.pumpAndSettle();
    expect(picked, 'Чуйская область');
  });
}
