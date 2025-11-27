/// ORT (Общереспубликанское тестирование) Кыргызстана
/// Complete structure and constants for ORT testing system
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

  /// Get all main sections as OrtSection objects
  static List<OrtSection> get mainSectionsList {
    return [
      OrtSection(
        id: 'math1',
        nameRu: 'Математика 1',
        nameKy: 'Математика 1',
        nameEn: 'Mathematics 1',
        descriptionRu: 'Базовая математика: арифметика, алгебра, геометрия',
        descriptionKy: 'Базалык математика: арифметика, алгебра, геометрия',
        descriptionEn: 'Basic mathematics: arithmetic, algebra, geometry',
        questionCount: math1Questions,
        timeMinutes: math1Minutes,
        pointsPerQuestion: math1PointsPerQuestion,
        maxScore: math1MaxScore,
        order: 1,
        icon: '📐',
        color: '#6366F1',
        topics: ['Арифметика', 'Уравнения', 'Неравенства', 'Геометрия', 'Функции'],
      ),
      OrtSection(
        id: 'math2',
        nameRu: 'Математика 2',
        nameKy: 'Математика 2',
        nameEn: 'Mathematics 2',
        descriptionRu: 'Продвинутая математика: анализ, комбинаторика',
        descriptionKy: 'Өркүндөтүлгөн математика: анализ, комбинаторика',
        descriptionEn: 'Advanced mathematics: analysis, combinatorics',
        questionCount: math2Questions,
        timeMinutes: math2Minutes,
        pointsPerQuestion: math2PointsPerQuestion,
        maxScore: math2MaxScore,
        order: 2,
        icon: '🔢',
        color: '#8B5CF6',
        topics: ['Производные', 'Интегралы', 'Комбинаторика', 'Теория вероятностей'],
      ),
      OrtSection(
        id: 'analogies',
        nameRu: 'Аналогии',
        nameKy: 'Аналогиялар',
        nameEn: 'Analogies',
        descriptionRu: 'Логические связи между понятиями',
        descriptionKy: 'Түшүнүктөрдүн ортосундагы логикалык байланыштар',
        descriptionEn: 'Logical relationships between concepts',
        questionCount: analogiesQuestions,
        timeMinutes: analogiesMinutes,
        pointsPerQuestion: analogiesPointsPerQuestion,
        maxScore: analogiesMaxScore,
        order: 3,
        icon: '🔗',
        color: '#EC4899',
        topics: ['Синонимы', 'Антонимы', 'Часть-целое', 'Причина-следствие'],
      ),
      OrtSection(
        id: 'completion',
        nameRu: 'Дополнение предложений',
        nameKy: 'Сүйлөмдөрдү толуктоо',
        nameEn: 'Sentence Completion',
        descriptionRu: 'Логическое завершение предложений',
        descriptionKy: 'Сүйлөмдөрдү логикалык жактан толуктоо',
        descriptionEn: 'Logical sentence completion',
        questionCount: completionQuestions,
        timeMinutes: completionMinutes,
        pointsPerQuestion: completionPointsPerQuestion,
        maxScore: completionMaxScore,
        order: 4,
        icon: '✏️',
        color: '#F59E0B',
        topics: ['Контекст', 'Логика', 'Грамматика', 'Смысловые связи'],
      ),
      OrtSection(
        id: 'grammar',
        nameRu: 'Грамматика',
        nameKy: 'Грамматика',
        nameEn: 'Grammar',
        descriptionRu: 'Правила русского/кыргызского языка',
        descriptionKy: 'Орус/кыргыз тилинин эрежелери',
        descriptionEn: 'Russian/Kyrgyz language rules',
        questionCount: grammarQuestions,
        timeMinutes: grammarMinutes,
        pointsPerQuestion: grammarPointsPerQuestion,
        maxScore: grammarMaxScore,
        order: 5,
        icon: '📖',
        color: '#10B981',
        topics: ['Орфография', 'Пунктуация', 'Морфология', 'Синтаксис'],
      ),
      OrtSection(
        id: 'reading',
        nameRu: 'Чтение и понимание',
        nameKy: 'Окуу жана түшүнүү',
        nameEn: 'Reading Comprehension',
        descriptionRu: 'Анализ и понимание текстов',
        descriptionKy: 'Текстти талдоо жана түшүнүү',
        descriptionEn: 'Text analysis and comprehension',
        questionCount: readingQuestions,
        timeMinutes: readingMinutes,
        pointsPerQuestion: readingPointsPerQuestion,
        maxScore: readingMaxScore,
        order: 6,
        icon: '📄',
        color: '#06B6D4',
        topics: ['Главная мысль', 'Детали', 'Выводы', 'Авторская позиция'],
      ),
    ];
  }

  /// Get all subject tests as OrtSubject objects
  static List<OrtSubject> get subjectTestsList {
    return [
      const OrtSubject(
        id: 'physics',
        code: 'PHYS',
        nameRu: 'Физика',
        nameKy: 'Физика',
        nameEn: 'Physics',
        icon: '⚛️',
        color: '#EF4444',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'chemistry',
        code: 'CHEM',
        nameRu: 'Химия',
        nameKy: 'Химия',
        nameEn: 'Chemistry',
        icon: '🧪',
        color: '#22C55E',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'biology',
        code: 'BIO',
        nameRu: 'Биология',
        nameKy: 'Биология',
        nameEn: 'Biology',
        icon: '🧬',
        color: '#84CC16',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'history_kg',
        code: 'HIST_KG',
        nameRu: 'История Кыргызстана',
        nameKy: 'Кыргызстандын тарыхы',
        nameEn: 'History of Kyrgyzstan',
        icon: '🏛️',
        color: '#F97316',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'history_world',
        code: 'HIST_WORLD',
        nameRu: 'Всемирная история',
        nameKy: 'Дүйнөлүк тарых',
        nameEn: 'World History',
        icon: '🌍',
        color: '#A855F7',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'geography',
        code: 'GEO',
        nameRu: 'География',
        nameKy: 'География',
        nameEn: 'Geography',
        icon: '🗺️',
        color: '#14B8A6',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'english',
        code: 'ENG',
        nameRu: 'Английский язык',
        nameKy: 'Англис тили',
        nameEn: 'English Language',
        icon: '🇬🇧',
        color: '#3B82F6',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'german',
        code: 'DEU',
        nameRu: 'Немецкий язык',
        nameKy: 'Немис тили',
        nameEn: 'German Language',
        icon: '🇩🇪',
        color: '#FBBF24',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'turkish',
        code: 'TUR',
        nameRu: 'Турецкий язык',
        nameKy: 'Түрк тили',
        nameEn: 'Turkish Language',
        icon: '🇹🇷',
        color: '#EF4444',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'kyrgyz_lang',
        code: 'KY_FOR_RU',
        nameRu: 'Кыргызский язык',
        nameKy: 'Кыргыз тили',
        nameEn: 'Kyrgyz Language',
        icon: '🇰🇬',
        color: '#DC2626',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'russian_lang',
        code: 'RU_FOR_KY',
        nameRu: 'Русский язык',
        nameKy: 'Орус тили',
        nameEn: 'Russian Language',
        icon: '🇷🇺',
        color: '#2563EB',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
      const OrtSubject(
        id: 'informatics',
        code: 'IT',
        nameRu: 'Информатика',
        nameKy: 'Информатика',
        nameEn: 'Computer Science',
        icon: '💻',
        color: '#6366F1',
        questionCount: subjectTestQuestions,
        timeMinutes: subjectTestMinutes,
        maxScore: subjectTestMaxScore,
      ),
    ];
  }

  /// University score thresholds
  static const Map<String, int> universityThresholds = {
    'medical': 190,
    'technical': 170,
    'economics': 160,
    'pedagogical': 140,
    'humanitarian': 130,
    'minimum': 110,
  };

  /// Format time in mm:ss
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Calculate grade based on score
  static String getGrade(int score, int maxScore) {
    final percentage = (score / maxScore) * 100;
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }
}

/// ORT Section Model (Main test sections)
class OrtSection {
  final String id;
  final String nameRu;
  final String nameKy;
  final String nameEn;
  final String descriptionRu;
  final String descriptionKy;
  final String descriptionEn;
  final int questionCount;
  final int timeMinutes;
  final int pointsPerQuestion;
  final int maxScore;
  final int order;
  final String icon;
  final String color;
  final List<String> topics;

  const OrtSection({
    required this.id,
    required this.nameRu,
    required this.nameKy,
    required this.nameEn,
    required this.descriptionRu,
    required this.descriptionKy,
    required this.descriptionEn,
    required this.questionCount,
    required this.timeMinutes,
    required this.pointsPerQuestion,
    required this.maxScore,
    required this.order,
    required this.icon,
    required this.color,
    required this.topics,
  });

  /// Get localized name
  String getName(String locale) {
    switch (locale) {
      case 'ky':
        return nameKy;
      case 'en':
        return nameEn;
      default:
        return nameRu;
    }
  }

  /// Get localized description
  String getDescription(String locale) {
    switch (locale) {
      case 'ky':
        return descriptionKy;
      case 'en':
        return descriptionEn;
      default:
        return descriptionRu;
    }
  }

  /// Get total time in seconds
  int get totalSeconds => timeMinutes * 60;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameRu': nameRu,
      'nameKy': nameKy,
      'nameEn': nameEn,
      'descriptionRu': descriptionRu,
      'descriptionKy': descriptionKy,
      'descriptionEn': descriptionEn,
      'questionCount': questionCount,
      'timeMinutes': timeMinutes,
      'pointsPerQuestion': pointsPerQuestion,
      'maxScore': maxScore,
      'order': order,
      'icon': icon,
      'color': color,
      'topics': topics,
    };
  }
}

/// ORT Subject Model (Subject tests)
class OrtSubject {
  final String id;
  final String code;
  final String nameRu;
  final String nameKy;
  final String nameEn;
  final String icon;
  final String color;
  final int questionCount;
  final int timeMinutes;
  final int maxScore;

  const OrtSubject({
    required this.id,
    required this.code,
    required this.nameRu,
    required this.nameKy,
    required this.nameEn,
    required this.icon,
    required this.color,
    required this.questionCount,
    required this.timeMinutes,
    required this.maxScore,
  });

  /// Get localized name
  String getName(String locale) {
    switch (locale) {
      case 'ky':
        return nameKy;
      case 'en':
        return nameEn;
      default:
        return nameRu;
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'nameRu': nameRu,
      'nameKy': nameKy,
      'nameEn': nameEn,
      'icon': icon,
      'color': color,
      'questionCount': questionCount,
      'timeMinutes': timeMinutes,
      'maxScore': maxScore,
    };
  }
}
