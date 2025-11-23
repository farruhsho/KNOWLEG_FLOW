import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification_models.dart';

/// Сервис управления геймификацией с персистентностью в Firebase
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Кэш для быстрого доступа
  final Map<String, UserGamification> _cache = {};
  final Map<String, List<UnlockedAchievement>> _achievementsCache = {};
  final Map<String, List<DailyQuest>> _questsCache = {};

  /// Получить геймификацию пользователя из Firestore
  Future<UserGamification> getUserGamification(String userId) async {
    // Проверяем кэш
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final doc = await _firestore
          .collection('user_gamification')
          .doc(userId)
          .get();

      UserGamification gamification;

      if (doc.exists) {
        gamification = UserGamification.fromJson(doc.data()!);
      } else {
        // Создаём начальную геймификацию для нового пользователя
        gamification = UserGamification(
          userId: userId,
          level: 1,
          xp: 0,
          xpToNextLevel: _calculateXPForLevel(2),
          coins: 0,
          streakDays: 0,
          lastActivityDate: DateTime.now(),
          statistics: {
            'testsCompleted': 0,
            'questionsAnswered': 0,
            'perfectScores': 0,
            'totalStudyMinutes': 0,
          },
        );

        // Сохраняем в Firebase
        await _saveUserGamification(gamification);
      }

      _cache[userId] = gamification;
      return gamification;
    } catch (e) {
      print('❌ Error loading user gamification: $e');
      // Возвращаем пустую геймификацию при ошибке
      return UserGamification(
        userId: userId,
        level: 1,
        xp: 0,
        xpToNextLevel: _calculateXPForLevel(2),
        coins: 0,
        streakDays: 0,
        lastActivityDate: DateTime.now(),
        statistics: {},
      );
    }
  }

  /// Сохранить геймификацию пользователя в Firestore
  Future<void> _saveUserGamification(UserGamification gamification) async {
    try {
      await _firestore
          .collection('user_gamification')
          .doc(gamification.userId)
          .set(gamification.toJson(), SetOptions(merge: true));

      _cache[gamification.userId] = gamification;
    } catch (e) {
      print('❌ Error saving user gamification: $e');
    }
  }

  /// Наградить пользователя XP
  Future<XPReward> awardXP(String userId, int amount, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final userGam = await getUserGamification(userId);

    int currentXP = userGam.xp;
    int currentLevel = userGam.level;
    int newXP = currentXP + amount;
    int newLevel = currentLevel;
    int bonusCoins = 0;

    // Проверка level up
    while (newXP >= _calculateXPForLevel(newLevel + 1)) {
      newXP -= _calculateXPForLevel(newLevel + 1);
      newLevel++;
      bonusCoins += 100; // Бонус за level up
    }

    final leveledUp = newLevel > currentLevel;

    final updatedGamification = userGam.copyWith(
      level: newLevel,
      xp: newXP,
      xpToNextLevel: _calculateXPForLevel(newLevel + 1),
      coins: userGam.coins + bonusCoins,
    );

    await _saveUserGamification(updatedGamification);

    return XPReward(
      xpGained: amount,
      newXP: newXP,
      levelUp: leveledUp,
      newLevel: newLevel,
      coinsGained: bonusCoins,
    );
  }

  /// Обновить статистику
  Future<void> updateStatistic(String userId, String key, int increment) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final userGam = await getUserGamification(userId);
    final stats = Map<String, int>.from(userGam.statistics);
    stats[key] = (stats[key] ?? 0) + increment;

    final updatedGamification = userGam.copyWith(statistics: stats);
    await _saveUserGamification(updatedGamification);

    // Проверить достижения после обновления статистики
    await _checkAchievements(userId);
  }

  /// Обновить streak
  Future<StreakUpdate> updateStreak(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final userGam = await getUserGamification(userId);
    final lastActivity = userGam.lastActivityDate;
    final currentStreak = userGam.streakDays;

    final now = DateTime.now();
    int newStreak = currentStreak;
    bool streakIncreased = false;
    bool streakLost = false;

    if (lastActivity == null) {
      newStreak = 1;
      streakIncreased = true;
    } else {
      final daysSinceLastActivity = now.difference(lastActivity).inDays;

      if (daysSinceLastActivity == 0) {
        // Сегодня уже был активен
        newStreak = currentStreak;
      } else if (daysSinceLastActivity == 1) {
        // Вчера был активен - продолжаем streak
        newStreak = currentStreak + 1;
        streakIncreased = true;
      } else {
        // Streak потерян
        newStreak = 1;
        streakLost = true;
      }
    }

    final updatedGamification = userGam.copyWith(
      streakDays: newStreak,
      lastActivityDate: now,
    );

    await _saveUserGamification(updatedGamification);

    // Проверить достижения по streak
    await _checkAchievements(userId);

    return StreakUpdate(
      newStreak: newStreak,
      streakIncreased: streakIncreased,
      streakLost: streakLost,
      previousStreak: currentStreak,
    );
  }

  /// Получить разблокированные достижения пользователя
  Future<List<UnlockedAchievement>> _getUnlockedAchievements(String userId) async {
    // Проверяем кэш
    if (_achievementsCache.containsKey(userId)) {
      return _achievementsCache[userId]!;
    }

    try {
      final doc = await _firestore
          .collection('user_achievements')
          .doc(userId)
          .get();

      List<UnlockedAchievement> unlocked = [];

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        unlocked = (data['achievements'] as List?)
            ?.map((a) => UnlockedAchievement.fromJson(a as Map<String, dynamic>))
            .toList() ?? [];
      }

      _achievementsCache[userId] = unlocked;
      return unlocked;
    } catch (e) {
      print('❌ Error loading unlocked achievements: $e');
      return [];
    }
  }

  /// Сохранить разблокированные достижения
  Future<void> _saveUnlockedAchievements(String userId, List<UnlockedAchievement> achievements) async {
    try {
      await _firestore
          .collection('user_achievements')
          .doc(userId)
          .set({
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _achievementsCache[userId] = achievements;
    } catch (e) {
      print('❌ Error saving unlocked achievements: $e');
    }
  }

  /// Получить все достижения
  Future<List<Achievement>> getAllAchievements() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _predefinedAchievements;
  }

  /// Получить прогресс достижений
  Future<List<AchievementProgress>> getAchievementsProgress(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final achievements = await getAllAchievements();
    final userGam = await getUserGamification(userId);
    final unlockedAchievements = await _getUnlockedAchievements(userId);

    return achievements.map((achievement) {
      final currentValue = _getCurrentValueForAchievement(achievement, userGam);
      final unlocked = unlockedAchievements.firstWhere(
        (ua) => ua.achievementId == achievement.id,
        orElse: () => UnlockedAchievement(
          achievementId: achievement.id,
          unlockedAt: DateTime.now(),
          currentValue: 0,
        ),
      );

      final isUnlocked = currentValue >= achievement.targetValue ||
          unlockedAchievements.any((ua) => ua.achievementId == achievement.id);

      return AchievementProgress(
        achievement: achievement,
        currentValue: currentValue,
        isUnlocked: isUnlocked,
        unlockedAt: isUnlocked ? unlocked.unlockedAt : null,
      );
    }).toList();
  }

  /// Получить ежедневные квесты из Firestore
  Future<List<DailyQuest>> getDailyQuests(String userId) async {
    // Проверяем кэш
    if (_questsCache.containsKey(userId)) {
      final cachedQuests = _questsCache[userId]!;
      if (cachedQuests.isNotEmpty && !cachedQuests.first.isExpired) {
        return cachedQuests;
      }
    }

    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      final doc = await _firestore
          .collection('daily_quests')
          .doc('${userId}_$todayKey')
          .get();

      List<DailyQuest> quests;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        quests = (data['quests'] as List)
            .map((q) => DailyQuest.fromJson(q as Map<String, dynamic>))
            .toList();
      } else {
        // Генерируем новые квесты
        quests = _generateDailyQuests(userId);
        await _saveDailyQuests(userId, quests);
      }

      _questsCache[userId] = quests;
      return quests;
    } catch (e) {
      print('❌ Error loading daily quests: $e');
      return _generateDailyQuests(userId);
    }
  }

  /// Сохранить ежедневные квесты в Firestore
  Future<void> _saveDailyQuests(String userId, List<DailyQuest> quests) async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      await _firestore
          .collection('daily_quests')
          .doc('${userId}_$todayKey')
          .set({
        'userId': userId,
        'date': todayKey,
        'quests': quests.map((q) => q.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving daily quests: $e');
    }
  }

  /// Обновить прогресс квеста
  Future<DailyQuest?> updateQuestProgress(
    String userId,
    String questId,
    int increment,
  ) async {
    final quests = await getDailyQuests(userId);
    final questIndex = quests.indexWhere((q) => q.id == questId);
    if (questIndex == -1) return null;

    final quest = quests[questIndex];
    final newValue = (quest.currentValue + increment).clamp(0, quest.targetValue);
    final updatedQuest = quest.copyWith(currentValue: newValue);

    quests[questIndex] = updatedQuest;
    await _saveDailyQuests(userId, quests);

    // Если квест завершён, дать награду
    if (updatedQuest.isCompleted && !quest.isCompleted) {
      await awardXP(userId, updatedQuest.xpReward, 'Daily quest completed');

      final userGam = await getUserGamification(userId);
      final updatedGamification = userGam.copyWith(
        coins: userGam.coins + updatedQuest.coinsReward,
      );
      await _saveUserGamification(updatedGamification);
    }

    return updatedQuest;
  }

  // ========== Приватные методы ==========

  /// Расчёт XP для уровня
  int _calculateXPForLevel(int level) {
    // Экспоненциальная формула: 100 * 1.5^(level-1)
    return (100 * pow(1.5, level - 1)).round();
  }

  /// Проверить и разблокировать достижения
  Future<List<Achievement>> _checkAchievements(String userId) async {
    final userGam = await getUserGamification(userId);
    final achievements = await getAllAchievements();
    final unlockedAchievements = await _getUnlockedAchievements(userId);
    final newlyUnlocked = <Achievement>[];

    for (final achievement in achievements) {
      // Пропустить уже разблокированные
      if (unlockedAchievements.any((ua) => ua.achievementId == achievement.id)) {
        continue;
      }

      final currentValue = _getCurrentValueForAchievement(achievement, userGam);

      if (currentValue >= achievement.targetValue) {
        unlockedAchievements.add(UnlockedAchievement(
          achievementId: achievement.id,
          unlockedAt: DateTime.now(),
          currentValue: currentValue,
        ));

        // Дать награду
        await awardXP(userId, achievement.xpReward, 'Achievement unlocked');

        final updatedGam = await getUserGamification(userId);
        final finalGamification = updatedGam.copyWith(
          coins: updatedGam.coins + achievement.coinsReward,
        );
        await _saveUserGamification(finalGamification);

        newlyUnlocked.add(achievement);
      }
    }

    // Сохраняем обновлённые достижения
    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlockedAchievements(userId, unlockedAchievements);
    }

    return newlyUnlocked;
  }

  /// Получить текущее значение для достижения
  int _getCurrentValueForAchievement(
    Achievement achievement,
    UserGamification userGam,
  ) {
    switch (achievement.type) {
      case AchievementType.testsCompleted:
        return userGam.statistics['testsCompleted'] ?? 0;
      case AchievementType.questionsAnswered:
        return userGam.statistics['questionsAnswered'] ?? 0;
      case AchievementType.perfectScore:
        return userGam.statistics['perfectScores'] ?? 0;
      case AchievementType.streakDays:
        return userGam.streakDays;
      case AchievementType.topicMastery:
        return userGam.statistics['topicsMastered'] ?? 0;
      case AchievementType.speedRun:
        return userGam.statistics['speedRuns'] ?? 0;
      case AchievementType.nightOwl:
        return userGam.statistics['nightTests'] ?? 0;
      case AchievementType.earlyBird:
        return userGam.statistics['morningTests'] ?? 0;
      case AchievementType.marathonCompleted:
        return userGam.statistics['marathonsCompleted'] ?? 0;
      case AchievementType.olympicsWinner:
        return userGam.statistics['olympicsWon'] ?? 0;
    }
  }

  /// Генерировать ежедневные квесты
  List<DailyQuest> _generateDailyQuests(String userId) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final expiresAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);

    return [
      DailyQuest(
        id: 'quest_1_${DateTime.now().day}',
        title: 'Ответь на 20 вопросов',
        description: 'Решай задачи, чтобы улучшить свои знания',
        type: QuestType.answerQuestions,
        targetValue: 20,
        xpReward: 100,
        coinsReward: 50,
        expiresAt: expiresAt,
      ),
      DailyQuest(
        id: 'quest_2_${DateTime.now().day}',
        title: 'Пройди 1 тест',
        description: 'Проверь свои знания в реальных условиях',
        type: QuestType.completeTest,
        targetValue: 1,
        xpReward: 150,
        coinsReward: 75,
        expiresAt: expiresAt,
      ),
      DailyQuest(
        id: 'quest_3_${DateTime.now().day}',
        title: 'Получи 5 правильных ответов подряд',
        description: 'Покажи свои знания без ошибок',
        type: QuestType.perfectAnswers,
        targetValue: 5,
        xpReward: 200,
        coinsReward: 100,
        expiresAt: expiresAt,
      ),
    ];
  }

  // ========== Предопределённые достижения ==========

  static final List<Achievement> _predefinedAchievements = [
    // Common achievements
    Achievement(
      id: 'first_test',
      title: 'Первый шаг',
      description: 'Пройди свой первый тест',
      iconName: 'check_circle',
      rarity: AchievementRarity.common,
      type: AchievementType.testsCompleted,
      targetValue: 1,
      xpReward: 50,
      coinsReward: 25,
    ),
    Achievement(
      id: 'beginner',
      title: 'Новичок',
      description: 'Ответь на 50 вопросов',
      iconName: 'star',
      rarity: AchievementRarity.common,
      type: AchievementType.questionsAnswered,
      targetValue: 50,
      xpReward: 100,
      coinsReward: 50,
    ),

    // Uncommon achievements
    Achievement(
      id: '7_day_streak',
      title: 'Неделя подряд',
      description: 'Занимайся 7 дней подряд',
      iconName: 'local_fire_department',
      rarity: AchievementRarity.uncommon,
      type: AchievementType.streakDays,
      targetValue: 7,
      xpReward: 200,
      coinsReward: 100,
    ),
    Achievement(
      id: '10_tests',
      title: 'Практикант',
      description: 'Пройди 10 тестов',
      iconName: 'quiz',
      rarity: AchievementRarity.uncommon,
      type: AchievementType.testsCompleted,
      targetValue: 10,
      xpReward: 250,
      coinsReward: 125,
    ),

    // Rare achievements
    Achievement(
      id: 'perfect_test',
      title: 'Идеальный результат',
      description: 'Получи 100% в тесте',
      iconName: 'emoji_events',
      rarity: AchievementRarity.rare,
      type: AchievementType.perfectScore,
      targetValue: 1,
      xpReward: 300,
      coinsReward: 150,
    ),
    Achievement(
      id: '30_day_streak',
      title: 'Месяц дисциплины',
      description: 'Занимайся 30 дней подряд',
      iconName: 'local_fire_department',
      rarity: AchievementRarity.rare,
      type: AchievementType.streakDays,
      targetValue: 30,
      xpReward: 500,
      coinsReward: 250,
    ),

    // Epic achievements
    Achievement(
      id: '100_tests',
      title: 'Эксперт',
      description: 'Пройди 100 тестов',
      iconName: 'military_tech',
      rarity: AchievementRarity.epic,
      type: AchievementType.testsCompleted,
      targetValue: 100,
      xpReward: 1000,
      coinsReward: 500,
    ),
    Achievement(
      id: 'marathon_hero',
      title: 'Герой марафона',
      description: 'Заверши 30-дневный марафон',
      iconName: 'emoji_events',
      rarity: AchievementRarity.epic,
      type: AchievementType.marathonCompleted,
      targetValue: 1,
      xpReward: 800,
      coinsReward: 400,
    ),

    // Legendary achievements
    Achievement(
      id: '100_day_streak',
      title: 'Легенда дисциплины',
      description: 'Занимайся 100 дней подряд',
      iconName: 'local_fire_department',
      rarity: AchievementRarity.legendary,
      type: AchievementType.streakDays,
      targetValue: 100,
      xpReward: 2000,
      coinsReward: 1000,
    ),
    Achievement(
      id: 'master',
      title: 'Мастер ОРТ',
      description: 'Достигни мастерства во всех темах',
      iconName: 'workspace_premium',
      rarity: AchievementRarity.legendary,
      type: AchievementType.topicMastery,
      targetValue: 10,
      xpReward: 3000,
      coinsReward: 1500,
    ),

    // Secret achievements
    Achievement(
      id: 'night_owl',
      title: 'Ночная сова',
      description: '???',
      iconName: 'nights_stay',
      rarity: AchievementRarity.secret,
      type: AchievementType.nightOwl,
      targetValue: 1,
      xpReward: 150,
      coinsReward: 75,
      isSecret: true,
    ),
    Achievement(
      id: 'early_bird',
      title: 'Ранняя птичка',
      description: '???',
      iconName: 'wb_sunny',
      rarity: AchievementRarity.secret,
      type: AchievementType.earlyBird,
      targetValue: 1,
      xpReward: 150,
      coinsReward: 75,
      isSecret: true,
    ),
  ];
}
