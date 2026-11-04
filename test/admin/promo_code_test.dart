import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/domain/promo_code.dart';

final _now = DateTime.utc(2026, 11, 4, 12);

PromoCodeDraft _draft({
  String code = 'ORT2026',
  int credits = 2,
  int? max,
  DateTime? expiresAt,
  bool active = true,
  String note = '',
}) =>
    PromoCodeDraft(
      code: code,
      credits: credits,
      maxRedemptions: max,
      expiresAt: expiresAt,
      active: active,
      note: note,
    );

void main() {
  group('code format (§9.2: A-Z0-9, 4–20)', () {
    test('normalised to the upper-case document id', () {
      expect(normalizePromoCode('  ort2026 '), 'ORT2026');
      expect(_draft(code: 'school5').toCallable()['code'], 'SCHOOL5');
      expect(_draft(code: 'school5').validate(now: _now), isEmpty);
    });

    test('valid and invalid codes', () {
      for (final ok in ['ABCD', 'A1B2C3', '2026', 'X' * 20]) {
        expect(isValidPromoCode(ok), isTrue, reason: ok);
      }
      for (final bad in ['ABC', 'X' * 21, 'ORT-2026', 'ORT 26', 'ОРТ2026', 'abcd', '']) {
        expect(isValidPromoCode(bad), isFalse, reason: bad);
      }
      expect(_draft(code: 'AB-12').validate(now: _now), [PromoIssue.codeFormat]);
    });

    test('generated codes are valid and avoid ambiguous characters', () {
      final r = Random(42);
      for (var i = 0; i < 50; i++) {
        final c = generatePromoCode(random: r);
        expect(isValidPromoCode(c), isTrue, reason: c);
        expect(c.length, 8);
        expect(c, isNot(matches(RegExp('[01IO]'))));
      }
      expect(generatePromoCode(random: r, length: 2).length, kPromoCodeMinLength);
      expect(generatePromoCode(random: r, length: 99).length, kPromoCodeMaxLength);
    });
  });

  group('credits, redemptions, expiry', () {
    test('credits 1..10', () {
      expect(_draft(credits: 1).validate(now: _now), isEmpty);
      expect(_draft(credits: 10).validate(now: _now), isEmpty);
      expect(_draft(credits: 0).validate(now: _now), [PromoIssue.creditsRange]);
      expect(_draft(credits: 11).validate(now: _now), [PromoIssue.creditsRange]);
    });

    test('max redemptions optional, ≥ 1, not below the current counter', () {
      expect(_draft(max: null).validate(now: _now), isEmpty);
      expect(_draft(max: 1).validate(now: _now), isEmpty);
      expect(_draft(max: 0).validate(now: _now), [PromoIssue.maxRedemptionsRange]);
      expect(_draft(max: kPromoMaxRedemptionsLimit + 1).validate(now: _now),
          [PromoIssue.maxRedemptionsRange]);
      expect(_draft(max: 5).validate(now: _now, redemptions: 7), [PromoIssue.maxBelowRedemptions]);
      expect(_draft(max: 7).validate(now: _now, redemptions: 7), isEmpty);
    });

    test('expiry optional, in the future for an active code', () {
      expect(_draft(expiresAt: _now.add(const Duration(minutes: 1))).validate(now: _now), isEmpty);
      expect(_draft(expiresAt: _now).validate(now: _now), [PromoIssue.expiryInPast]);
      expect(_draft(expiresAt: DateTime.utc(2026, 1, 1)).validate(now: _now), [PromoIssue.expiryInPast]);
    });

    test('an expired or exhausted code can still be deactivated', () {
      final d = _draft(expiresAt: DateTime.utc(2026, 1, 1), max: 3, active: false);
      expect(d.validate(now: _now, redemptions: 9), isEmpty);
    });

    test('note length', () {
      expect(_draft(note: 'n' * kPromoNoteMax).validate(now: _now), isEmpty);
      expect(_draft(note: 'n' * (kPromoNoteMax + 1)).validate(now: _now), [PromoIssue.noteTooLong]);
    });

    test('expiry date = end of that day in Bishkek', () {
      final e = promoExpiryEndOfDay(DateTime(2026, 12, 31));
      expect(e.isUtc, isTrue);
      expect(e, DateTime.utc(2026, 12, 31, 17, 59, 59));
      expect(promoBishkekDate(e), DateTime(2026, 12, 31));
      // 18:00 UTC is already the next day in Bishkek.
      expect(promoBishkekDate(DateTime.utc(2026, 12, 31, 18)), DateTime(2027, 1, 1));
    });
  });

  group('adminUpsertPromoCode payload', () {
    test('all fields, expiry in epoch ms', () {
      final exp = DateTime.utc(2026, 12, 31, 17, 59, 59);
      expect(
        _draft(code: 'ort2026', credits: 3, max: 100, expiresAt: exp, note: ' школа №5 ').toCallable(),
        {
          'code': 'ORT2026',
          'credits': 3,
          'maxRedemptions': 100,
          'expiresAt': exp.millisecondsSinceEpoch,
          'active': true,
          'note': 'школа №5',
        },
      );
    });

    test('unlimited and never-expiring codes omit the optional fields', () {
      final m = _draft().toCallable();
      expect(m.keys.toSet(), {'code', 'credits', 'active', 'note'});
    });
  });

  group('promo_codes documents', () {
    test('parsed tolerantly; status as a student would hit it', () {
      final r = PromoCodeRecord.fromMap('ORT2026', {
        'credits': 2,
        'max_redemptions': 10,
        'redemptions': 3,
        'expires_at': DateTime.utc(2026, 12, 1),
        'active': true,
        'note': 'Telegram',
        'created_by': 'root',
      });
      expect([r.code, r.credits, r.maxRedemptions, r.redemptions, r.note], ['ORT2026', 2, 10, 3, 'Telegram']);
      expect(r.status(_now), PromoStatus.active);
      expect(r.status(DateTime.utc(2026, 12, 2)), PromoStatus.expired);
      expect(PromoCodeRecord.fromMap('X', {'active': true, 'credits': 1, 'max_redemptions': 3, 'redemptions': 3})
          .status(_now), PromoStatus.exhausted);
      expect(PromoCodeRecord.fromMap('X', {'credits': 1}).status(_now), PromoStatus.inactive);
    });

    test('deactivation keeps every other field', () {
      final r = PromoCodeRecord.fromMap('ORT2026', {
        'credits': 4,
        'max_redemptions': 10,
        'redemptions': 10,
        'expires_at': DateTime.utc(2026, 1, 1),
        'active': true,
        'note': 'n',
      });
      final d = r.toDraft(active: false);
      expect(d.validate(now: _now, redemptions: r.redemptions), isEmpty);
      expect(d.toCallable(), {
        'code': 'ORT2026',
        'credits': 4,
        'maxRedemptions': 10,
        'expiresAt': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'active': false,
        'note': 'n',
      });
    });
  });
}
