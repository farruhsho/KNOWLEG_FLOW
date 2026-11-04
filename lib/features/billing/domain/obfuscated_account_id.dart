import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The value passed to Google Play as `applicationUserName`
/// (→ `obfuscatedAccountId`): lowercase hex SHA-256 of the Firebase uid.
///
/// The backend recomputes the same hash and rejects a purchase whose
/// `obfuscatedExternalAccountId` does not match the caller
/// (`PURCHASE_ACCOUNT_MISMATCH`). The raw uid never reaches Google, and the
/// 64-character result fits Play's 64-character limit exactly.
String obfuscatedAccountId(String uid) {
  if (uid.isEmpty) {
    throw ArgumentError.value(uid, 'uid', 'must not be empty');
  }
  return sha256.convert(utf8.encode(uid)).toString();
}
