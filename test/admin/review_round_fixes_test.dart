import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/data/repositories/people_repositories.dart';
import 'package:knowledge_flow/features/admin/domain/blueprint_spec.dart';
import 'package:knowledge_flow/features/admin/domain/exam_question.dart';
import 'package:knowledge_flow/features/admin/domain/pricing_config.dart';
import 'package:knowledge_flow/features/admin/presentation/pages/users_page.dart';
import 'package:knowledge_flow/features/billing/domain/pricing_config.dart' as student;
import 'package:knowledge_flow/l10n/app_localizations.dart';

/// Regression tests for the review round: ENT-FREE-01 (admin pricing range),
/// MOD-01 / F4 (ban reason length) and CP-06 (part_id of single-part
/// sections).
void main() {
  group('ENT-FREE-01: free_exams_per_user range matches adminUpdatePricing (0..5)', () {
    PricingConfig withFree(int n) => PricingConfig.defaults.copyWith(freeExamsPerUser: n);

    test('0..5 pass, anything else is rejected before calling the server', () {
      for (var n = 0; n <= 5; n++) {
        expect(withFree(n).validate(), isEmpty, reason: '$n');
      }
      for (final n in [-1, 6, 7, 10, 11]) {
        expect(withFree(n).validate(), contains(PricingIssue.freeRange), reason: '$n');
      }
    });

    test('one bound for the CMS and the student client', () {
      expect(kFreeExamsPerUserMin, 0);
      expect(kFreeExamsPerUserMax, student.PricingConfig.maxFreeExamsPerUser);
    });

    test('the error text names the real range in every locale', () async {
      for (final code in ['ru', 'en', 'ky']) {
        final l = await AppLocalizations.delegate.load(Locale(code));
        final msg = l.adminPricingIssueFree(kFreeExamsPerUserMin, kFreeExamsPerUserMax);
        expect(msg, contains('0'), reason: code);
        expect(msg, contains('5'), reason: code);
        expect(msg, isNot(contains('10')), reason: code);
      }
    });
  });

  group('MOD-01 / F4: moderator ban reason length', () {
    test('the limit is the one in firestore.rules validModeratorBan()', () {
      final rules = File('firestore.rules').readAsStringSync();
      final m = RegExp(r'function validModeratorBan\(\)[\s\S]*?ban_reason\.size\(\)\s*<=\s*(\d+)')
          .firstMatch(rules);
      expect(m, isNotNull, reason: 'validModeratorBan() must cap ban_reason');
      expect(UsersRepository.maxBanReasonLength, int.parse(m!.group(1)!));
    });

    test('banUpdate never sends a reason the rule rejects', () {
      final long = 'x' * 700;
      final ban = UsersRepository.banUpdate(true, actor: 'mod1', reason: long, now: 'TS');
      expect((ban['ban_reason'] as String).length, UsersRepository.maxBanReasonLength);
      final ok = 'y' * UsersRepository.maxBanReasonLength;
      expect(UsersRepository.banUpdate(true, actor: 'mod1', reason: ok, now: 'TS')['ban_reason'], ok);
      // Measured in code points like the rules; a surrogate pair is never split.
      final emoji = '\u{1F600}' * 501;
      final clipped = UsersRepository.clipBanReason(emoji);
      expect(UsersRepository.banReasonLength(clipped), 500);
      expect(clipped, '\u{1F600}' * 500);
    });

    Future<List<String?>> openDialog(WidgetTester tester) async {
      final results = <String?>[];
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(await showDialog<String>(
                context: context,
                builder: (_) => const BanReasonDialog(),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    FilledButton banButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('ban_confirm')));

    testWidgets('too long: counter, message, Ban disabled', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byKey(const ValueKey('ban_reason_field')), 'a' * 501);
      await tester.pump();
      expect(find.text('501 / 500'), findsOneWidget);
      expect(find.text('Причина — не длиннее 500 символов.'), findsOneWidget);
      expect(banButton(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('within the limit: Ban returns the trimmed reason', (tester) async {
      final results = await openDialog(tester);
      final reason = 'b' * 500;
      await tester.enterText(find.byKey(const ValueKey('ban_reason_field')), '  $reason  ');
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
      expect(find.text('Причина — не длиннее 500 символов.'), findsNothing);
      expect(banButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('ban_confirm')));
      await tester.pumpAndSettle();
      expect(results, [reason]);
    });

    testWidgets('cancel bans nobody', (tester) async {
      final results = await openDialog(tester);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  group('CP-06: single-part sections store their part id', () {
    late List<BlueprintSpec> blueprints;
    SectionSpec section(String bp, String id) =>
        blueprints.firstWhere((b) => b.id == bp).section(id)!;

    setUpAll(() {
      blueprints = BlueprintSpec.listFromJson(
          jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()));
    });

    test('storedPartId', () {
      final chemistry = section('ort_subject_chemistry_2026', 'chemistry');
      expect(chemistry.storedPartId(null), 'chemistry');
      expect(chemistry.storedPartId('math_problems'), 'chemistry', reason: 'stale id from another section');
      final reading = section('ort_main_2026', 'reading');
      expect(reading.storedPartId(null), 'reading');
      final math = section('ort_main_2026', 'math');
      expect(math.storedPartId(null), isNull, reason: 'multi-part: the editor asks for a part');
      expect(math.storedPartId('math_comparison'), 'math_comparison');
      expect(math.storedPartId('reading'), isNull, reason: 'not a part of this section');
    });

    test('every single-part section of the bundled blueprints gets its only part', () {
      for (final b in blueprints) {
        for (final s in b.sections.where((s) => s.parts.length == 1)) {
          expect(s.storedPartId(null), s.parts.single.id, reason: '${b.id}/${s.id}');
        }
      }
    });

    test('re-saving a legacy CMS item writes part_id without resetting its review', () {
      final chemistry = section('ort_subject_chemistry_2026', 'chemistry');
      const legacy = ExamQuestionDoc(
        id: 'q1',
        subjectId: 'chemistry',
        sectionId: 'chemistry',
        topicId: 'chemistry.acids',
        language: 'ru',
        stem: 'Что такое кислота?',
        options: [ExamOption('A', 'a'), ExamOption('B', 'b')],
      );
      expect(legacy.partId, isNull);
      final partId = chemistry.storedPartId(legacy.partId);
      final saved = legacy.copyWith(partId: partId, clearPart: partId == null);
      final fields = examQuestionWriteFields(saved, isNew: false, original: legacy);
      expect(fields, {'part_id': 'chemistry'});
      expect(saved.contentDiffers(legacy), isFalse, reason: 'part_id is not review-relevant');
      expect(examQuestionWriteFields(saved, isNew: true)['part_id'], 'chemistry');
    });
  });
}
