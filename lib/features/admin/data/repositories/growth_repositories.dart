import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../domain/achievements_config.dart';
import '../../domain/notification_draft.dart';
import '../../domain/promo_code.dart';
import '../admin_firebase.dart';

/// `notifications/{id}` — broadcast history written by
/// `adminSendNotification` (ARCHITECTURE.md §9.4). Read-only for the CMS.
class NotificationsRepository {
  NotificationsRepository(this._db);
  final FirebaseFirestore _db;

  /// Newest first, paginated (FB-17).
  Future<AdminPage<NotificationRecord>> page({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 20,
  }) =>
      fetchPage(
        _db.collection(Collections.notifications).orderBy('created_at', descending: true),
        after: after,
        pageSize: pageSize,
        map: (d) => NotificationRecord.fromMap(d.id, d.data() ?? const {}),
      );
}

/// `promo_codes/{CODE}` (§9.2). The CMS only reads; every write goes through
/// `adminUpsertPromoCode`, which logs to `admin_logs`.
class PromoCodesRepository {
  PromoCodesRepository(this._db);
  final FirebaseFirestore _db;

  /// Newest first, paginated (FB-17).
  Future<AdminPage<PromoCodeRecord>> page({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) =>
      fetchPage(
        _db.collection(AdminCollections.promoCodes).orderBy('created_at', descending: true),
        after: after,
        pageSize: pageSize,
        map: (d) => PromoCodeRecord.fromMap(d.id, d.data() ?? const {}),
      );

  Future<PromoCodeRecord?> get(String code) async {
    final d = await _db.collection(AdminCollections.promoCodes).doc(normalizePromoCode(code)).get();
    return d.exists ? PromoCodeRecord.fromMap(d.id, d.data() ?? const {}) : null;
  }
}

/// `config/achievements` (§9.4): read by everyone signed in, written directly
/// by `manage_achievements` roles.
class AchievementsConfigRepository {
  AchievementsConfigRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(AdminCollections.config).doc(AdminCollections.achievementsDoc);

  Future<AchievementsConfig> load() async {
    final d = await _doc.get();
    return d.exists ? AchievementsConfig.fromMap(d.data()) : AchievementsConfig.empty;
  }

  /// Full overwrite (no merge): the document then holds exactly
  /// [kAchievementsConfigKeys], as the rules require.
  Future<void> save(AchievementsConfig config) => _doc.set(config.toFirestore());
}
