/// Achievement model for gamification
class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String icon; // Emoji or icon name
  final String category; // 'tests', 'streaks', 'scores', 'subjects'
  final int requiredValue; // e.g., 7 for 7-day streak
  final bool isUnlocked;
  final int currentProgress; // Current value towards goal
  final DateTime? unlockedAt;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.requiredValue,
    this.isUnlocked = false,
    this.currentProgress = 0,
    this.unlockedAt,
  });

  double get progressPercentage =>
      requiredValue > 0 ? (currentProgress / requiredValue).clamp(0.0, 1.0) : 0.0;

  factory AchievementModel.fromFirestore(Map<String, dynamic> data) {
    return AchievementModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '🏆',
      category: data['category'] ?? 'general',
      requiredValue: data['requiredValue'] ?? 0,
      isUnlocked: data['isUnlocked'] ?? false,
      currentProgress: data['currentProgress'] ?? 0,
      unlockedAt: data['unlockedAt'] != null
          ? DateTime.parse(data['unlockedAt'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'category': category,
      'requiredValue': requiredValue,
      'isUnlocked': isUnlocked,
      'currentProgress': currentProgress,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  /// Get predefined achievements
  static List<AchievementModel> getDefaultAchievements() {
    return [
      AchievementModel(
        id: 'first_test',
        title: 'Первый шаг',
        description: 'Пройдите первый тест',
        icon: '🎯',
        category: 'tests',
        requiredValue: 1,
      ),
      AchievementModel(
        id: 'streak_7',
        title: 'Марафонец',
        description: 'Занимайтесь 7 дней подряд',
        icon: '🔥',
        category: 'streaks',
        requiredValue: 7,
      ),
      AchievementModel(
        id: 'score_80',
        title: 'Отличник',
        description: 'Средний балл выше 80',
        icon: '⭐',
        category: 'scores',
        requiredValue: 80,
      ),
      AchievementModel(
        id: 'tests_10',
        title: 'Практик',
        description: 'Пройдите 10 тестов',
        icon: '📚',
        category: 'tests',
        requiredValue: 10,
      ),
      AchievementModel(
        id: 'tests_50',
        title: 'Эксперт',
        description: 'Пройдите 50 тестов',
        icon: '🎓',
        category: 'tests',
        requiredValue: 50,
      ),
      AchievementModel(
        id: 'perfect_score',
        title: 'Идеальный результат',
        description: 'Получите 100% в тесте',
        icon: '💯',
        category: 'scores',
        requiredValue: 100,
      ),
      AchievementModel(
        id: 'streak_30',
        title: 'Железная воля',
        description: 'Занимайтесь 30 дней подряд',
        icon: '💪',
        category: 'streaks',
        requiredValue: 30,
      ),
      AchievementModel(
        id: 'all_subjects',
        title: 'Универсал',
        description: 'Пройдите тесты по всем предметам',
        icon: '🌟',
        category: 'subjects',
        requiredValue: 5, // Assuming 5 subjects
      ),
    ];
  }
}
