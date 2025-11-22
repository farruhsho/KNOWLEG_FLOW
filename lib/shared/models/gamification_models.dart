import 'package:json_annotation/json_annotation.dart';

part 'gamification_models.g.dart';

/// Рарность достижения
enum AchievementRarity {
  common,    // Обычное (серое)
  uncommon,  // Необычное (зелёное)
  rare,      // Редкое (синее)
  epic,      // Эпическое (фиолетовое)
  legendary, // Легендарное (оранжевое)
  secret,    // Секретное (золотое)
}

/// Тип достижения
enum AchievementType {
  testsCompleted,      // Пройдено тестов
  questionsAnswered,   // Отвечено на вопросы
  perfectScore,        // Идеальный результат
  streakDays,         // Дней подряд
  topicMastery,       // Мастерство темы
  speedRun,           // Быстрое прохождение
  nightOwl,           // Ночная сова
  earlyBird,          // Ранняя птичка
  marathonCompleted,  // Марафон завершён
  olympicsWinner,     // Победитель олимпиады
}

/// Тип квеста
enum QuestType {
  answerQuestions,   // Ответить на N вопросов
  completeTest,      // Пройти N тестов
  studyMinutes,      // Учиться N минут
  perfectAnswers,    // N правильных ответов подряд
  specificTopic,     // Практика конкретной темы
}

/// Геймификация пользователя
@JsonSerializable()
class UserGamification {
  final String userId;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int coins;
  final int streakDays;
  final DateTime? lastActivityDate;
  final Map<String, int> statistics;

  UserGamification({
    required this.userId,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.coins,
    this.streakDays = 0,
    this.lastActivityDate,
    this.statistics = const {},
  });

  /// Прогресс до следующего уровня (0.0 - 1.0)
  double get levelProgress => xpToNextLevel > 0 ? xp / xpToNextLevel : 0.0;

  /// Копирование с изменениями
  UserGamification copyWith({
    String? userId,
    int? level,
    int? xp,
    int? xpToNextLevel,
    int? coins,
    int? streakDays,
    DateTime? lastActivityDate,
    Map<String, int>? statistics,
  }) {
    return UserGamification(
      userId: userId ?? this.userId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      coins: coins ?? this.coins,
      streakDays: streakDays ?? this.streakDays,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      statistics: statistics ?? this.statistics,
    );
  }

  factory UserGamification.fromJson(Map<String, dynamic> json) =>
      _$UserGamificationFromJson(json);

  Map<String, dynamic> toJson() => _$UserGamificationToJson(this);
}

/// Достижение
@JsonSerializable()
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconName; // Название иконки из Material Icons
  final AchievementRarity rarity;
  final AchievementType type;
  final int targetValue;
  final int xpReward;
  final int coinsReward;
  final bool isSecret; // Показывать ли до разблокировки

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.rarity,
    required this.type,
    required this.targetValue,
    required this.xpReward,
    required this.coinsReward,
    this.isSecret = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);

  Map<String, dynamic> toJson() => _$AchievementToJson(this);
}

/// Разблокированное достижение пользователя
@JsonSerializable()
class UnlockedAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int currentValue;

  UnlockedAchievement({
    required this.achievementId,
    required this.unlockedAt,
    required this.currentValue,
  });

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) =>
      _$UnlockedAchievementFromJson(json);

  Map<String, dynamic> toJson() => _$UnlockedAchievementToJson(this);
}

/// Прогресс достижения
class AchievementProgress {
  final Achievement achievement;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  AchievementProgress({
    required this.achievement,
    required this.currentValue,
    required this.isUnlocked,
    this.unlockedAt,
  });

  double get progress => achievement.targetValue > 0
      ? (currentValue / achievement.targetValue).clamp(0.0, 1.0)
      : 0.0;

  bool get isCompleted => currentValue >= achievement.targetValue;
}

/// Ежедневный квест
@JsonSerializable()
class DailyQuest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final int coinsReward;
  final DateTime expiresAt;
  final String? relatedTopicId; // Для квестов по конкретной теме

  DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.xpReward,
    required this.coinsReward,
    required this.expiresAt,
    this.relatedTopicId,
  });

  bool get isCompleted => currentValue >= targetValue;

  double get progress => targetValue > 0
      ? (currentValue / targetValue).clamp(0.0, 1.0)
      : 0.0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  DailyQuest copyWith({
    String? id,
    String? title,
    String? description,
    QuestType? type,
    int? targetValue,
    int? currentValue,
    int? xpReward,
    int? coinsReward,
    DateTime? expiresAt,
    String? relatedTopicId,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      xpReward: xpReward ?? this.xpReward,
      coinsReward: coinsReward ?? this.coinsReward,
      expiresAt: expiresAt ?? this.expiresAt,
      relatedTopicId: relatedTopicId ?? this.relatedTopicId,
    );
  }

  factory DailyQuest.fromJson(Map<String, dynamic> json) =>
      _$DailyQuestFromJson(json);

  Map<String, dynamic> toJson() => _$DailyQuestToJson(this);
}

/// Награда XP
class XPReward {
  final int xpGained;
  final int newXP;
  final bool levelUp;
  final int newLevel;
  final int coinsGained;

  XPReward({
    required this.xpGained,
    required this.newXP,
    required this.levelUp,
    required this.newLevel,
    this.coinsGained = 0,
  });
}

/// Обновление streak
class StreakUpdate {
  final int newStreak;
  final bool streakIncreased;
  final bool streakLost;
  final int previousStreak;

  StreakUpdate({
    required this.newStreak,
    required this.streakIncreased,
    required this.streakLost,
    required this.previousStreak,
  });
}
