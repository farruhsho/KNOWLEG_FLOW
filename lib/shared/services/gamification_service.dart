import 'dart:math';
import '../models/gamification_models.dart';

/// Сервис управления геймификацией
/// Пока использует in-memory хранилище (mock)
/// TODO: Интегрировать с Firebase после настройки backend
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  // Mock хранилище (заменится на Firebase)
  UserGamification? _currentUserGamification;
  final List<UnlockedAchievement> _unlockedAchievements = [];
  final List<DailyQuest> _dailyQuests = [];

  /// Получить текущую геймификацию пользователя
  Future<UserGamification> getUserGamification(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network

    _currentUserGamification ??= UserGamification(
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

    return _currentUserGamification!;
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

    _currentUserGamification = userGam.copyWith(
      level: newLevel,
      xp: newXP,
      xpToNextLevel: _calculateXPForLevel(newLevel + 1),
      coins: userGam.coins + bonusCoins,
    );

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

    _currentUserGamification = userGam.copyWith(statistics: stats);

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

    _currentUserGamification = userGam.copyWith(
      streakDays: newStreak,
      lastActivityDate: now,
    );

    // Проверить достижения по streak
    await _checkAchievements(userId);

    return StreakUpdate(
      newStreak: newStreak,
      streakIncreased: streakIncreased,
      streakLost: streakLost,
      previousStreak: currentStreak,
    );
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

    return achievements.map((achievement) {
      final currentValue = _getCurrentValueForAchievement(achievement, userGam);
      final unlocked = _unlockedAchievements.firstWhere(
        (ua) => ua.achievementId == achievement.id,
        orElse: () => UnlockedAchievement(
          achievementId: achievement.id,
          unlockedAt: DateTime.now(),
          currentValue: 0,
        ),
      );

      final isUnlocked = currentValue >= achievement.targetValue ||
          _unlockedAchievements.any((ua) => ua.achievementId == achievement.id);

      return AchievementProgress(
        achievement: achievement,
        currentValue: currentValue,
        isUnlocked: isUnlocked,
        unlockedAt: isUnlocked ? unlocked.unlockedAt : null,
      );
    }).toList();
  }

  /// Получить ежедневные квесты
  Future<List<DailyQuest>> getDailyQuests(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Если квестов нет или они истекли, генерируем новые
    if (_dailyQuests.isEmpty || _dailyQuests.first.isExpired) {
      _generateDailyQuests(userId);
    }

    return _dailyQuests;
  }

  /// Обновить прогресс квеста
  Future<DailyQuest?> updateQuestProgress(
    String userId,
    String questId,
    int increment,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final questIndex = _dailyQuests.indexWhere((q) => q.id == questId);
    if (questIndex == -1) return null;

    final quest = _dailyQuests[questIndex];
    final newValue = (quest.currentValue + increment).clamp(0, quest.targetValue);
    final updatedQuest = quest.copyWith(currentValue: newValue);

    _dailyQuests[questIndex] = updatedQuest;

    // Если квест завершён, дать награду
    if (updatedQuest.isCompleted && !quest.isCompleted) {
      await awardXP(userId, updatedQuest.xpReward, 'Daily quest completed');

      final userGam = await getUserGamification(userId);
      _currentUserGamification = userGam.copyWith(
        coins: userGam.coins + updatedQuest.coinsReward,
      );
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
    final newlyUnlocked = <Achievement>[];

    for (final achievement in achievements) {
      // Пропустить уже разблокированные
      if (_unlockedAchievements.any((ua) => ua.achievementId == achievement.id)) {
        continue;
      }

      final currentValue = _getCurrentValueForAchievement(achievement, userGam);

      if (currentValue >= achievement.targetValue) {
        _unlockedAchievements.add(UnlockedAchievement(
          achievementId: achievement.id,
          unlockedAt: DateTime.now(),
          currentValue: currentValue,
        ));

        // Дать награду
        await awardXP(userId, achievement.xpReward, 'Achievement unlocked');

        final updatedGam = await getUserGamification(userId);
        _currentUserGamification = updatedGam.copyWith(
          coins: updatedGam.coins + achievement.coinsReward,
        );

        newlyUnlocked.add(achievement);
      }
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
  void _generateDailyQuests(String userId) {
    _dailyQuests.clear();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final expiresAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);

    _dailyQuests.addAll([
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
    ]);
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
