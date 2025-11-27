/// ORT (Общереспубликанское тестирование) Кыргызстана
/// Константы и структура тестирования
class OrtConstants {
  // ═══════════════════════════════════════════════════════════════════
  // ОСНОВНОЙ ТЕСТ (Обязательный для всех)
  // ═══════════════════════════════════════════════════════════════════

  static const int totalMainQuestions = 140;
  static const int totalMainMinutes = 160;
  static const int totalMainScore = 160;

  // Математика 1 (Базовая)
  static const int math1Questions = 30;
  static const int math1Minutes = 40;
  static const int math1PointsPerQuestion = 1;
  static const int math1MaxScore = 30;

  // Математика 2 (Продвинутая)
  static const int math2Questions = 20;
  static const int math2Minutes = 30;
  static const int math2PointsPerQuestion = 2;
  static const int math2MaxScore = 40;

  // Аналогии (Логика)
  static const int analogiesQuestions = 15;
  static const int analogiesMinutes = 12;
  static const int analogiesPointsPerQuestion = 1;
  static const int analogiesMaxScore = 15;

  // Дополнение предложений (Логика)
  static const int completionQuestions = 15;
  static const int completionMinutes = 13;
  static const int completionPointsPerQuestion = 1;
  static const int completionMaxScore = 15;

  // Грамматика (русский/кыргызский)
  static const int grammarQuestions = 40;
  static const int grammarMinutes = 35;
  static const int grammarPointsPerQuestion = 1;
  static const int grammarMaxScore = 40;

  // Чтение и понимание
  static const int readingQuestions = 20;
  static const int readingMinutes = 30;
  static const int readingPointsPerQuestion = 1;
  static const int readingMaxScore = 20;

  // ═══════════════════════════════════════════════════════════════════
  // ПРЕДМЕТНЫЕ ТЕСТЫ (По выбору - максимум 2)
  // ═══════════════════════════════════════════════════════════════════

  static const int subjectTestQuestions = 30;
  static const int subjectTestMinutes = 45;
  static const int subjectTestPointsPerQuestion = 2;
  static const int subjectTestMaxScore = 60;
  static const int maxSubjectTests = 2;
  static const int totalSubjectMaxScore = 120; // 60 × 2

  // Общий максимум
  static const int totalMaxScore = 220; // 160 + 60

  // Список доступных предметных тестов
  static const List<String> availableSubjects = [
    'physics',
    'chemistry',
    'biology',
    'history_kg',
    'history_world',
    'geography',
    'english',
    'german',
    'kyrgyz_lang',
    'russian_lang',
  ];

  // Названия предметов
  static const Map<String, Map<String, String>> subjectNames = {
    'physics': {
      'ru': 'Физика',
      'ky': 'Физика',
      'en': 'Physics',
    },
    'chemistry': {
      'ru': 'Химия',
      'ky': 'Химия',
      'en': 'Chemistry',
    },
    'biology': {
      'ru': 'Биология',
      'ky': 'Биология',
      'en': 'Biology',
    },
    'history_kg': {
      'ru': 'История Кыргызстана',
      'ky': 'Кыргызстандын тарыхы',
      'en': 'History of Kyrgyzstan',
    },
    'history_world': {
      'ru': 'Всемирная история',
      'ky': 'Дүйнөлүк тарых',
      'en': 'World History',
    },
    'geography': {
      'ru': 'География',
      'ky': 'География',
      'en': 'Geography',
    },
    'english': {
      'ru': 'Английский язык',
      'ky': 'Англис тили',
      'en': 'English Language',
    },
    'german': {
      'ru': 'Немецкий язык',
      'ky': 'Немис тили',
      'en': 'German Language',
    },
    'kyrgyz_lang': {
      'ru': 'Кыргызский язык (для русских школ)',
      'ky': 'Кыргыз тили (орус мектептери үчүн)',
      'en': 'Kyrgyz Language (for Russian schools)',
    },
    'russian_lang': {
      'ru': 'Русский язык (для кыргызских школ)',
      'ky': 'Орус тили (кыргыз мектептери үчүн)',
      'en': 'Russian Language (for Kyrgyz schools)',
    },
  };

  // ═══════════════════════════════════════════════════════════════════
  // ТИПЫ ВОПРОСОВ
  // ═══════════════════════════════════════════════════════════════════

  static const List<String> questionTypes = [
    'single_choice', // Один правильный ответ из 5 вариантов (A-E)
    'multiple_choice', // Несколько правильных ответов
    'matching', // Соответствие
    'ordering', // Правильный порядок
    'fill_blank', // Заполнить пропуск
    'text_based', // Вопросы к тексту
  ];

  // Варианты ответов для single/multiple choice
  static const List<String> answerOptions = ['A', 'B', 'C', 'D', 'E'];

  // ═══════════════════════════════════════════════════════════════════
  // СИСТЕМА ОЦЕНКИ
  // ═══════════════════════════════════════════════════════════════════

  static const int correctAnswerPoints = 1;
  static const int incorrectAnswerPoints = 0;
  static const int skippedAnswerPoints = 0;
  static const bool hasPenaltyForWrong = false;

  // Уровни сложности
  static const int difficultyEasy = 1;
  static const int difficultyMedium = 2;
  static const int difficultyHard = 3;

  static const Map<int, String> difficultyNames = {
    1: 'Лёгкий',
    2: 'Средний',
    3: 'Сложный',
  };

  // ═══════════════════════════════════════════════════════════════════
  // РАЗДЕЛЫ ОСНОВНОГО ТЕСТА
  // ═══════════════════════════════════════════════════════════════════

  static const Map<String, Map<String, dynamic>> mainSections = {
    'math1': {
      'name': {'ru': 'Математика 1', 'ky': 'Математика 1', 'en': 'Math 1'},
      'description': {'ru': 'Базовая математика', 'ky': 'Базалык математика', 'en': 'Basic Mathematics'},
      'questions': math1Questions,
      'minutes': math1Minutes,
      'pointsPerQuestion': math1PointsPerQuestion,
      'maxScore': math1MaxScore,
      'order': 1,
    },
    'math2': {
      'name': {'ru': 'Математика 2', 'ky': 'Математика 2', 'en': 'Math 2'},
      'description': {'ru': 'Продвинутая математика', 'ky': 'Өркүндөтүлгөн математика', 'en': 'Advanced Mathematics'},
      'questions': math2Questions,
      'minutes': math2Minutes,
      'pointsPerQuestion': math2PointsPerQuestion,
      'maxScore': math2MaxScore,
      'order': 2,
    },
    'analogies': {
      'name': {'ru': 'Аналогии', 'ky': 'Аналогиялар', 'en': 'Analogies'},
      'description': {'ru': 'Логика', 'ky': 'Логика', 'en': 'Logic'},
      'questions': analogiesQuestions,
      'minutes': analogiesMinutes,
      'pointsPerQuestion': analogiesPointsPerQuestion,
      'maxScore': analogiesMaxScore,
      'order': 3,
    },
    'completion': {
      'name': {'ru': 'Дополнение предложений', 'ky': 'Сүйлөмдөрдү толуктоо', 'en': 'Sentence Completion'},
      'description': {'ru': 'Логика', 'ky': 'Логика', 'en': 'Logic'},
      'questions': completionQuestions,
      'minutes': completionMinutes,
      'pointsPerQuestion': completionPointsPerQuestion,
      'maxScore': completionMaxScore,
      'order': 4,
    },
    'grammar': {
      'name': {'ru': 'Грамматика', 'ky': 'Грамматика', 'en': 'Grammar'},
      'description': {'ru': 'Русский/Кыргызский язык', 'ky': 'Орус/Кыргыз тили', 'en': 'Russian/Kyrgyz Language'},
      'questions': grammarQuestions,
      'minutes': grammarMinutes,
      'pointsPerQuestion': grammarPointsPerQuestion,
      'maxScore': grammarMaxScore,
      'order': 5,
    },
    'reading': {
      'name': {'ru': 'Чтение и понимание', 'ky': 'Окуу жана түшүнүү', 'en': 'Reading Comprehension'},
      'description': {'ru': 'Работа с текстом', 'ky': 'Текст менен иштөө', 'en': 'Text Analysis'},
      'questions': readingQuestions,
      'minutes': readingMinutes,
      'pointsPerQuestion': readingPointsPerQuestion,
      'maxScore': readingMaxScore,
      'order': 6,
    },
  };

  /// Get section configuration by ID
  static Map<String, dynamic>? getSectionConfig(String sectionId) {
    return mainSections[sectionId];
  }

  /// Get subject name by ID and language
  static String getSubjectName(String subjectId, String language) {
    return subjectNames[subjectId]?[language] ?? subjectId;
  }

  /// Validate if user can select subject tests
  static bool canSelectSubjects(List<String> selectedSubjects) {
    return selectedSubjects.length <= maxSubjectTests;
  }

  /// Calculate total score
  static int calculateTotalScore({
    required int mainScore,
    required int subjectScore,
  }) {
    return mainScore + subjectScore;
  }

  /// Get difficulty name
  static String getDifficultyName(int difficulty) {
    return difficultyNames[difficulty] ?? 'Неизвестно';
  }
}
