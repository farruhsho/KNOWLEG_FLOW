/// Promo codes — ARCHITECTURE.md §9.2. `promo_codes/{CODE}` is written only by
/// `adminUpsertPromoCode` (super_admin, `grant_credits`), which logs every
/// change in `admin_logs`. A code grants free exam credits, so it is a
/// finance operation.
///
/// Pure Dart so the format, credit and expiry rules are unit-tested; the
/// callable validates the same input again.
library;

import 'dart:math';

import 'exam_question.dart' show readDateTolerant;

const int kPromoCodeMinLength = 4;
const int kPromoCodeMaxLength = 20;
const int kPromoCreditsMin = 1;
const int kPromoCreditsMax = 10;

/// Upper bound the CMS accepts for `max_redemptions` (sanity limit).
const int kPromoMaxRedemptionsLimit = 100000;

/// Longest internal note, in code points.
const int kPromoNoteMax = 200;

final RegExp _codePattern = RegExp('^[A-Z0-9]{$kPromoCodeMinLength,$kPromoCodeMaxLength}\$');

/// Alphabet for generated codes: no 0/O/1/I to avoid misreading.
const String kPromoCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Document id form of a code: trimmed and upper-cased.
String normalizePromoCode(String raw) => raw.trim().toUpperCase();

/// `A-Z0-9`, 4–20 characters (after [normalizePromoCode]).
bool isValidPromoCode(String code) => _codePattern.hasMatch(code);

/// Random code from [kPromoCodeAlphabet].
String generatePromoCode({Random? random, int length = 8}) {
  final r = random ?? Random.secure();
  final n = length.clamp(kPromoCodeMinLength, kPromoCodeMaxLength);
  return String.fromCharCodes([
    for (var i = 0; i < n; i++) kPromoCodeAlphabet.codeUnitAt(r.nextInt(kPromoCodeAlphabet.length)),
  ]);
}

/// The last second (23:59:59) of [day]'s calendar date in Bishkek (UTC+6),
/// as an absolute instant. Expiry dates picked in the CMS mean "valid
/// through this day in Kyrgyzstan".
DateTime promoExpiryEndOfDay(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 23, 59, 59).subtract(const Duration(hours: 6));

/// Calendar date of the instant [t] in Bishkek (UTC+6), as a date-only
/// value — the inverse of [promoExpiryEndOfDay] for display and pickers.
DateTime promoBishkekDate(DateTime t) {
  final b = t.toUtc().add(const Duration(hours: 6));
  return DateTime(b.year, b.month, b.day);
}

enum PromoIssue {
  codeFormat,
  creditsRange,
  maxRedemptionsRange,
  maxBelowRedemptions,
  expiryInPast,
  noteTooLong,
}

/// Input of `adminUpsertPromoCode {code, credits, maxRedemptions?,
/// expiresAt? (ms), active, note}`.
class PromoCodeDraft {
  final String code;
  final int credits;

  /// `null` = unlimited.
  final int? maxRedemptions;

  /// `null` = never expires.
  final DateTime? expiresAt;
  final bool active;
  final String note;

  const PromoCodeDraft({
    required this.code,
    required this.credits,
    this.maxRedemptions,
    this.expiresAt,
    this.active = true,
    this.note = '',
  });

  String get normalizedCode => normalizePromoCode(code);

  /// [redemptions] is the current counter of an existing code (0 for a new
  /// one). Expiry and the redemption cap are only checked for an active
  /// code, so an expired or exhausted code can always be deactivated.
  List<PromoIssue> validate({required DateTime now, int redemptions = 0}) {
    final issues = <PromoIssue>[];
    if (!isValidPromoCode(normalizedCode)) issues.add(PromoIssue.codeFormat);
    if (credits < kPromoCreditsMin || credits > kPromoCreditsMax) {
      issues.add(PromoIssue.creditsRange);
    }
    final max = maxRedemptions;
    if (max != null && (max < 1 || max > kPromoMaxRedemptionsLimit)) {
      issues.add(PromoIssue.maxRedemptionsRange);
    } else if (active && max != null && max < redemptions) {
      issues.add(PromoIssue.maxBelowRedemptions);
    }
    if (active && expiresAt != null && !expiresAt!.isAfter(now)) {
      issues.add(PromoIssue.expiryInPast);
    }
    if (note.trim().runes.length > kPromoNoteMax) issues.add(PromoIssue.noteTooLong);
    return issues;
  }

  /// The callable payload. Optional fields are omitted when unset
  /// (unlimited / no expiry).
  Map<String, dynamic> toCallable() => {
        'code': normalizedCode,
        'credits': credits,
        if (maxRedemptions != null) 'maxRedemptions': maxRedemptions,
        if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
        'active': active,
        'note': note.trim(),
      };

  PromoCodeDraft copyWith({bool? active}) => PromoCodeDraft(
        code: code,
        credits: credits,
        maxRedemptions: maxRedemptions,
        expiresAt: expiresAt,
        active: active ?? this.active,
        note: note,
      );
}

enum PromoStatus { active, inactive, expired, exhausted }

int? _intOrNull(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v.trim()) : null);

String? _sn(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// `promo_codes/{CODE}`: `{credits, max_redemptions, redemptions,
/// expires_at, active, note, created_by, created_at}`.
class PromoCodeRecord {
  final String code;
  final int credits;
  final int? maxRedemptions;
  final int redemptions;
  final DateTime? expiresAt;
  final bool active;
  final String note;
  final String? createdBy;
  final DateTime? createdAt;

  const PromoCodeRecord({
    required this.code,
    required this.credits,
    this.maxRedemptions,
    this.redemptions = 0,
    this.expiresAt,
    this.active = false,
    this.note = '',
    this.createdBy,
    this.createdAt,
  });

  factory PromoCodeRecord.fromMap(String id, Map<String, dynamic> d) => PromoCodeRecord(
        code: id,
        credits: _intOrNull(d['credits']) ?? 0,
        maxRedemptions: _intOrNull(d['max_redemptions']),
        redemptions: _intOrNull(d['redemptions']) ?? 0,
        expiresAt: readDateTolerant(d['expires_at']),
        active: d['active'] == true,
        note: d['note']?.toString() ?? '',
        createdBy: _sn(d['created_by']),
        createdAt: readDateTolerant(d['created_at']),
      );

  /// What a student redeeming the code now would hit (the server decides).
  PromoStatus status(DateTime now) {
    if (!active) return PromoStatus.inactive;
    if (expiresAt != null && !expiresAt!.isAfter(now)) return PromoStatus.expired;
    if (maxRedemptions != null && redemptions >= maxRedemptions!) return PromoStatus.exhausted;
    return PromoStatus.active;
  }

  PromoCodeDraft toDraft({bool? active}) => PromoCodeDraft(
        code: code,
        credits: credits.clamp(kPromoCreditsMin, kPromoCreditsMax),
        maxRedemptions: maxRedemptions,
        expiresAt: expiresAt,
        active: active ?? this.active,
        note: note,
      );
}
