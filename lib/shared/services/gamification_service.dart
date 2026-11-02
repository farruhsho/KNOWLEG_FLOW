import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/bishkek_time.dart';
import '../models/gamification_models.dart';
import '../models/user_stats_model.dart';

/// Gamification read model.
///
/// * XP, level, streak and achievements are **server-owned** and read from
///   `user_stats/{uid}` (ARCHITECTURE.md §1.7). Nothing here computes or
///   writes them (GAM-04); a failed read is surfaced as an error and is never
///   replaced by persisted defaults (GAM-01).
/// * Coins and daily quests are cosmetic and stay in the legacy owner-written
///   collections (`user_gamification`, `daily_quests`); they never affect
///   XP, levels or leaderboards. Mutations use increments / merges instead of
///   full-object rewrites, and day keys use Asia/Bishkek (GAM-05).
/// * No process-lifetime cache: callers get fresh data or a live stream
///   (GAM-20).
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _statsRef(String uid) =>
      _firestore.collection(Collections.userStats).doc(uid);

  // ========== Server-owned stats ==========

  /// Live server stats. A missing document means "no activity yet".
  Stream<UserStats> watchStats(String uid) => _statsRef(uid).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? UserStats.empty(uid) : UserStats.fromMap(uid, data);
      });

  /// One-off read of server stats. Throws on read errors.
  Future<UserStats> getStats(String uid) async {
    final doc = await _statsRef(uid).get();
    final data = doc.data();
    return data == null ? UserStats.empty(uid) : UserStats.fromMap(uid, data);
  }

  /// Level/XP/streak from `user_stats` plus cosmetic coins. Throws when the
  /// stats cannot be read — callers show a retry state; nothing is written.
  Future<UserGamification> getUserGamification(String userId) async {
    final stats = await getStats(userId);
    final coins = await _readCoins(userId);
    return UserGamification.fromStats(stats, coins: coins);
  }

  Future<int> _readCoins(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.collectionUserGamification).doc(userId).get();
      final c = doc.data()?['coins'];
      return c is num ? c.toInt() : 0;
    } catch (e, st) {
      reportError(e, st, reason: 'learn.gamification.coins');
      return 0;
    }
  }

  /// Streaks are computed by the server on every XP event (calendar days in
  /// Asia/Bishkek). Kept for existing callers: reads the current streak and
  /// writes nothing — opening a screen is not studying (GAM-06).
  Future<StreakUpdate> updateStreak(String userId) async {
    final stats = await getStats(userId);
    final streak = stats.liveStreak(DateTime.now());
    return StreakUpdate(
      newStreak: streak,
      streakIncreased: false,
      streakLost: streak == 0 && stats.currentStreak > 0,
      previousStreak: stats.currentStreak,
    );
  }

  // ========== Cosmetic daily quests ==========

  String _questDocId(String userId, DateTime now) => '${userId}_${BishkekTime.dayKey(now)}';

  /// Today's quests (Bishkek day). Created on first read of the day; when the
  /// read fails, fresh quests are returned but **not** persisted.
  Future<List<DailyQuest>> getDailyQuests(String userId) async {
    final now = DateTime.now();
    final ref = _firestore.collection(AppConstants.collectionDailyQuests).doc(_questDocId(userId, now));
    try {
      final doc = await ref.get();
      final data = doc.data();
      final raw = data?['quests'];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((q) => DailyQuest.fromJson(q.map((k, v) => MapEntry(k.toString(), v))))
            .toList();
      }
      final quests = generateDailyQuests(now);
      unawaited(ref.set({
        'userId': userId,
        'date': BishkekTime.dayKey(now),
        'quests': quests.map((q) => q.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((Object e, StackTrace st) => reportError(e, st, reason: 'learn.quests.create')));
      return quests;
    } catch (e, st) {
      reportError(e, st, reason: 'learn.quests.read');
      return generateDailyQuests(now);
    }
  }

  /// Applies a finished practice session to today's quests:
  /// answered questions, one completed set, best run of correct answers.
  /// Coins for newly completed quests are added with an increment.
  Future<void> recordPracticeQuests(
    String userId, {
    required int answered,
    required int bestCorrectRun,
  }) async {
    if (answered <= 0) return;
    final now = DateTime.now();
    final ref = _firestore.collection(AppConstants.collectionDailyQuests).doc(_questDocId(userId, now));
    final quests = await getDailyQuests(userId);
    var coins = 0;
    final updated = quests.map((q) {
      int value = q.currentValue;
      switch (q.type) {
        case QuestType.answerQuestions:
          value += answered;
          break;
        case QuestType.completeTest:
          value += 1;
          break;
        case QuestType.perfectAnswers:
          if (bestCorrectRun > value) value = bestCorrectRun;
          break;
        case QuestType.studyMinutes:
        case QuestType.specificTopic:
          break;
      }
      final next = q.copyWith(currentValue: value.clamp(0, q.targetValue));
      if (next.isCompleted && !q.isCompleted) coins += q.coinsReward;
      return next;
    }).toList();

    final batch = _firestore.batch();
    batch.set(ref, {
      'userId': userId,
      'date': BishkekTime.dayKey(now),
      'quests': updated.map((q) => q.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (coins > 0) {
      batch.set(
        _firestore.collection(AppConstants.collectionUserGamification).doc(userId),
        {'userId': userId, 'coins': FieldValue.increment(coins)},
        SetOptions(merge: true),
      );
    }
    unawaited(batch.commit().catchError((Object e, StackTrace st) {
      reportError(e, st, reason: 'learn.quests.commit');
    }));
  }

  /// Today's cosmetic quests. They reward coins only — XP is server-owned —
  /// and every quest can actually be completed in practice (GAM-18).
  static List<DailyQuest> generateDailyQuests(DateTime now) {
    final w = BishkekTime.wallClock(now);
    // Midnight of the next Bishkek day, as a real instant.
    final expiresAt = DateTime.utc(w.year, w.month, w.day + 1).subtract(BishkekTime.offset);
    final day = BishkekTime.dayKey(now);
    return [
      DailyQuest(
        id: 'answer_20_$day',
        title: 'Ответь на 20 вопросов',
        description: 'Решай задачи в практике',
        type: QuestType.answerQuestions,
        targetValue: 20,
        xpReward: 0,
        coinsReward: 50,
        expiresAt: expiresAt,
      ),
      DailyQuest(
        id: 'complete_set_$day',
        title: 'Заверши 1 тренировку',
        description: 'Пройди набор вопросов до конца',
        type: QuestType.completeTest,
        targetValue: 1,
        xpReward: 0,
        coinsReward: 30,
        expiresAt: expiresAt,
      ),
      DailyQuest(
        id: 'run_5_$day',
        title: '5 верных ответов подряд',
        description: 'Ответь правильно пять раз подряд',
        type: QuestType.perfectAnswers,
        targetValue: 5,
        xpReward: 0,
        coinsReward: 40,
        expiresAt: expiresAt,
      ),
    ];
  }
}
