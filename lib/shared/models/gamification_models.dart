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

  factory UserGamification.fromJson(Map<String, dynamic> json) {
    return UserGamification(
      userId: json['userId'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      xpToNextLevel: json['xpToNextLevel'] as int,
      coins: json['coins'] as int,
      streakDays: json['streakDays'] as int? ?? 0,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.parse(json['lastActivityDate'] as String)
          : null,
      statistics: (json['statistics'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as int),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'coins': coins,
      'streakDays': streakDays,
      'lastActivityDate': lastActivityDate?.toIso8601String(),
      'statistics': statistics,
    };
  }
}

/// Достижение
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

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconName: json['iconName'] as String,
      rarity: AchievementRarity.values[json['rarity'] as int],
      type: AchievementType.values[json['type'] as int],
      targetValue: json['targetValue'] as int,
      xpReward: json['xpReward'] as int,
      coinsReward: json['coinsReward'] as int,
      isSecret: json['isSecret'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconName': iconName,
      'rarity': rarity.index,
      'type': type.index,
      'targetValue': targetValue,
      'xpReward': xpReward,
      'coinsReward': coinsReward,
      'isSecret': isSecret,
    };
  }
}

/// Разблокированное достижение пользователя
class UnlockedAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int currentValue;

  UnlockedAchievement({
    required this.achievementId,
    required this.unlockedAt,
    required this.currentValue,
  });

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) {
    return UnlockedAchievement(
      achievementId: json['achievementId'] as String,
      unlockedAt: DateTime.parse(json['unlockedAt'] as String),
      currentValue: json['currentValue'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievementId': achievementId,
      'unlockedAt': unlockedAt.toIso8601String(),
      'currentValue': currentValue,
    };
  }
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

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: QuestType.values[json['type'] as int],
      targetValue: json['targetValue'] as int,
      currentValue: json['currentValue'] as int? ?? 0,
      xpReward: json['xpReward'] as int,
      coinsReward: json['coinsReward'] as int,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      relatedTopicId: json['relatedTopicId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.index,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'xpReward': xpReward,
      'coinsReward': coinsReward,
      'expiresAt': expiresAt.toIso8601String(),
      'relatedTopicId': relatedTopicId,
    };
  }
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
