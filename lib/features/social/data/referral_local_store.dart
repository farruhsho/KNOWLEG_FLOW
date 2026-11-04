import 'package:shared_preferences/shared_preferences.dart';

/// Device-local bits of the referral flow:
///
/// * a friend's code typed during onboarding, before the student has an
///   account (applied after sign-in from the home screen);
/// * the student's own code, cached per uid so the invite page does not call
///   `referralGetCode` on every visit.
class ReferralLocalStore {
  ReferralLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _pendingKey = 'social_pending_referral_code_v1';
  static const _myCodePrefix = 'social_my_referral_code_v1:';

  String? get pendingCode {
    final v = _prefs.getString(_pendingKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> savePendingCode(String code) => _prefs.setString(_pendingKey, code);

  Future<void> clearPendingCode() => _prefs.remove(_pendingKey);

  String? cachedCode(String uid) => _prefs.getString('$_myCodePrefix$uid');

  Future<void> cacheCode(String uid, String code) => _prefs.setString('$_myCodePrefix$uid', code);
}
