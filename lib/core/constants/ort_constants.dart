/// ORT (Общереспубликанское тестирование) constants for code that needs a
/// synchronous answer (admin pickers, AI drafting prompts, legacy screens).
///
/// **The canonical exam structure is `assets/data/exam_blueprints.json`**
/// (versioned blueprints, verified against the official 2026 brochure — see
/// docs/modernization/ARCHITECTURE.md §1.1). Everything below mirrors
/// blueprint `ort_main_2026` / `ort_subject_*_2026`, and
/// test/learning/ort_constants_test.dart fails if the two drift apart
/// (CMS-08). New features should read the blueprint, not these constants.
///
/// Scoring: the app counts raw correct answers (1 point each, no penalty).
/// The official conversion to the ORT scale is not published, so nothing in
/// the app may present a raw count or a percentage as an official ORT score.
class OrtConstants {
  // ═══════════════════════════════════════════════════════════════════
  // ОСНОВНОЙ ТЕСТ (ort_main_2026): math 60/90 → verbal 30/30 →
  // reading 30/60 → grammar 30/35. Итого 150 заданий / 215 минут.
  // ═══════════════════════════════════════════════════════════════════

  static const int totalMainQuestions = 150;
  static const int totalMainMinutes = 215;

  /// Raw points of the main test (1 per correct answer). NOT the official
  /// ORT scale — see [officialMainMaxScore].
  static const int totalMainScore = 150;

  /// Official maximum of the main test on the ORT scale (blueprint
  /// `reference.official_max_score`). Reference information only: the app
  /// never converts raw results to this scale.
  static const int officialMainMaxScore = 245;

  // Section timers. Parts inside a section share the section timer; the
  // per-part minutes below are the equal-pace share of that timer, used only
  // for display and pacing hints.
  static const int mathSectionMinutes = 90;
  static const int verbalSectionMinutes = 30;

  // Математика, часть I — сравнение величин (4 фиксированных варианта)
  static const int math1Questions = 30;
  static const int math1Minutes = 45;
  static const int math1PointsPerQuestion = 1;
  static const int math1MaxScore = 30;

  // Математика, часть II — задачи (5 вариантов ответа)
  static const int math2Questions = 30;
  static const int math2Minutes = 45;
  static const int math2PointsPerQuestion = 1;
  static const int math2MaxScore = 30;

  // Аналогии (часть раздела verbal; деление 15/15 официально не опубликовано)
  static const int analogiesQuestions = 15;
  static const int analogiesMinutes = 15;
  static const int analogiesPointsPerQuestion = 1;
  static const int analogiesMaxScore = 15;

  // Дополнение предложений (часть раздела verbal)
  static const int completionQuestions = 15;
  static const int completionMinutes = 15;
  static const int completionPointsPerQuestion = 1;
  static const int completionMaxScore = 15;

  // Чтение и понимание
  static const int readingQuestions = 30;
  static const int readingMinutes = 60;
  static const int readingPointsPerQuestion = 1;
  static const int readingMaxScore = 30;

  // Практическая грамматика (язык выбранного теста)
  static const int grammarQuestions = 30;
  static const int grammarMinutes = 35;
  static const int grammarPointsPerQuestion = 1;
  static const int grammarMaxScore = 30;

  // ═══════════════════════════════════════════════════════════════════
  // ПРЕДМЕТНЫЕ ТЕСТЫ (ort_subject_*_2026). Количество заданий и время
  // зависят от предмета — см. [subjectTestsList].
  // ═══════════════════════════════════════════════════════════════════

  /// Most common subject-test length (English has 50).
  static const int subjectTestQuestions = 40;

  /// Shortest subject-test duration; chemistry, physics and math take 80.
  static const int subjectTestMinutes = 60;
  static const int subjectTestPointsPerQuestion = 1;
  static const int subjectTestMaxScore = 40;

  /// How many subject tests the app lets a student plan for. App-side limit,
  /// not an official rule (requirements depend on the chosen programme).
  static const int maxSubjectTests = 2;
  static const int totalSubjectMaxScore = subjectTestMaxScore * maxSubjectTests;

  /// Kept for old callers: the official main-test maximum. There is no
  /// official "main + subject tests" total.
  static const int totalMaxScore = officialMainMaxScore;

  // Тест по государственному языку (ort_state_language_2026): только
  // кыргызский, результат — уровень 1–4.
  static const int stateLanguageQuestions = 50;
  static const int stateLanguageMinutes = 60;

  /// Subject tests offered in 2026 (blueprint subject ids).
  static const List<String> availableSubjects = [
    'chemistry',
    'biology',
    'physics',
    'math',
    'history',
    'english',
    'kyrgyz_lit',
    'russian_lit',
  ];

  /// Subject names, including legacy ids that older content still uses.
  static const Map<String, Map<String, String>> subjectNames = {
    'chemistry': {'ru': 'Химия', 'ky': 'Химия', 'en': 'Chemistry'},
    'biology': {'ru': 'Биология', 'ky': 'Биология', 'en': 'Biology'},
    'physics': {'ru': 'Физика', 'ky': 'Физика', 'en': 'Physics'},
    'math': {'ru': 'Математика', 'ky': 'Математика', 'en': 'Mathematics'},
    'history': {'ru': 'История', 'ky': 'Тарых', 'en': 'History'},
    'english': {'ru': 'Английский язык', 'ky': 'Англис тили', 'en': 'English'},
    'kyrgyz_lit': {
      'ru': 'Кыргызский язык и литература',
      'ky': 'Кыргыз тили жана адабияты',
      'en': 'Kyrgyz language and literature',
    },
    'russian_lit': {
      'ru': 'Русский язык и литература',
      'ky': 'Орус тили жана адабияты',
      'en': 'Russian language and literature',
    },
    // Legacy ids (pre-2026 content).
    'history_kg': {'ru': 'История Кыргызстана', 'ky': 'Кыргызстандын тарыхы', 'en': 'History of Kyrgyzstan'},
    'history_world': {'ru': 'Всемирная история', 'ky': 'Дүйнөлүк тарых', 'en': 'World History'},
    'geography': {'ru': 'География', 'ky': 'География', 'en': 'Geography'},
    'german': {'ru': 'Немецкий язык', 'ky': 'Немис тили', 'en': 'German'},
    'kyrgyz_lang': {'ru': 'Кыргызский язык', 'ky': 'Кыргыз тили', 'en': 'Kyrgyz language'},
    'russian_lang': {'ru': 'Русский язык', 'ky': 'Орус тили', 'en': 'Russian language'},
  };

  // ═══════════════════════════════════════════════════════════════════
  // ТИПЫ ВОПРОСОВ
  // ═══════════════════════════════════════════════════════════════════

  static const List<String> questionTypes = [
    'single_choice', // Один правильный ответ (4 варианта; в задачах по математике — 5)
    'multiple_choice', // Несколько правильных ответов (в ОРТ не используется)
    'matching', // Соответствие
    'ordering', // Правильный порядок
    'fill_blank', // Заполнить пропуск
    'text_based', // Вопросы к тексту
  ];

  /// Answer letters. ORT items have 4 options (A–D); math part II has 5.
  static const List<String> answerOptions = ['A', 'B', 'C', 'D', 'E'];

  // ═══════════════════════════════════════════════════════════════════
  // СИСТЕМА ОЦЕНКИ (сырые баллы приложения)
  // ═══════════════════════════════════════════════════════════════════

  static const int correctAnswerPoints = 1;
  static const int incorrectAnswerPoints = 0;
  static const int skippedAnswerPoints = 0;
  static const bool hasPenaltyForWrong = false;

  // Уровни сложности (1–3)
  static const int difficultyEasy = 1;
  static const int difficultyMedium = 2;
  static const int difficultyHard = 3;

  static const Map<int, String> difficultyNames = {
    1: 'Лёгкий',
    2: 'Средний',
    3: 'Сложный',
  };

  // ═══════════════════════════════════════════════════════════════════
  // РАЗДЕЛЫ ОСНОВНОГО ТЕСТА (части в порядке прохождения)
  // ═══════════════════════════════════════════════════════════════════

  static const Map<String, Map<String, dynamic>> mainSections = {
    'math1': {
      'name': {'ru': 'Математика, часть I', 'ky': 'Математика, I бөлүк', 'en': 'Mathematics, part I'},
      'description': {'ru': 'Сравнение величин', 'ky': 'Чоңдуктарды салыштыруу', 'en': 'Quantitative comparison'},
      'section_id': 'math',
      'questions': math1Questions,
      'minutes': math1Minutes,
      'options': 4,
      'pointsPerQuestion': math1PointsPerQuestion,
      'maxScore': math1MaxScore,
      'order': 1,
    },
    'math2': {
      'name': {'ru': 'Математика, часть II', 'ky': 'Математика, II бөлүк', 'en': 'Mathematics, part II'},
      'description': {'ru': 'Задачи', 'ky': 'Маселелер', 'en': 'Problem solving'},
      'section_id': 'math',
      'questions': math2Questions,
      'minutes': math2Minutes,
      'options': 5,
      'pointsPerQuestion': math2PointsPerQuestion,
      'maxScore': math2MaxScore,
      'order': 2,
    },
    'analogies': {
      'name': {'ru': 'Аналогии', 'ky': 'Аналогиялар', 'en': 'Analogies'},
      'description': {'ru': 'Логические связи между словами', 'ky': 'Сөздөрдүн ортосундагы логикалык байланыш', 'en': 'Word relationships'},
      'section_id': 'verbal',
      'questions': analogiesQuestions,
      'minutes': analogiesMinutes,
      'options': 4,
      'pointsPerQuestion': analogiesPointsPerQuestion,
      'maxScore': analogiesMaxScore,
      'order': 3,
    },
    'completion': {
      'name': {'ru': 'Дополнение предложений', 'ky': 'Сүйлөмдөрдү толуктоо', 'en': 'Sentence completion'},
      'description': {'ru': 'Смысловое завершение предложений', 'ky': 'Сүйлөмдү мааниси боюнча толуктоо', 'en': 'Completing sentences by meaning'},
      'section_id': 'verbal',
      'questions': completionQuestions,
      'minutes': completionMinutes,
      'options': 4,
      'pointsPerQuestion': completionPointsPerQuestion,
      'maxScore': completionMaxScore,
      'order': 4,
    },
    'reading': {
      'name': {'ru': 'Чтение и понимание', 'ky': 'Окуу жана түшүнүү', 'en': 'Reading comprehension'},
      'description': {'ru': 'Задания к текстам', 'ky': 'Тексттерге тапшырмалар', 'en': 'Questions on texts'},
      'section_id': 'reading',
      'questions': readingQuestions,
      'minutes': readingMinutes,
      'options': 4,
      'pointsPerQuestion': readingPointsPerQuestion,
      'maxScore': readingMaxScore,
      'order': 5,
    },
    'grammar': {
      'name': {'ru': 'Практическая грамматика', 'ky': 'Практикалык грамматика', 'en': 'Practical grammar'},
      'description': {'ru': 'Язык выбранного теста', 'ky': 'Тандалган тесттин тили', 'en': 'Language of the chosen test'},
      'section_id': 'grammar',
      'questions': grammarQuestions,
      'minutes': grammarMinutes,
      'options': 4,
      'pointsPerQuestion': grammarPointsPerQuestion,
      'maxScore': grammarMaxScore,
      'order': 6,
    },
  };

  /// Get section configuration by ID
  static Map<String, dynamic>? getSectionConfig(String sectionId) {
    return mainSections[sectionId];
  }

  /// Get subject name by ID and language
  static String getSubjectName(String subjectId, String language) {
    return subjectNames[subjectId]?[language] ?? subjectNames[subjectId]?['ru'] ?? subjectId;
  }

  /// Validate if user can select subject tests
  static bool canSelectSubjects(List<String> selectedSubjects) {
    return selectedSubjects.length <= maxSubjectTests;
  }

  /// Sum of raw points. Not an official ORT score.
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

  /// Main-test parts in exam order (math I, math II, analogies, completion,
  /// reading, grammar).
  static List<OrtSection> get mainSectionsList {
    return [
      const OrtSection(
        id: 'math1',
        blueprintSectionId: 'math',
        nameRu: 'Математика, часть I',
        nameKy: 'Математика, I бөлүк',
        nameEn: 'Mathematics, part I',
        descriptionRu: 'Сравнение величин: какая из двух величин больше (4 фиксированных варианта)',
        descriptionKy: 'Чоңдуктарды салыштыруу: эки чоңдуктун кайсынысы чоң (4 туруктуу вариант)',
        descriptionEn: 'Quantitative comparison: which of two quantities is greater (4 fixed options)',
        questionCount: math1Questions,
        timeMinutes: math1Minutes,
        pointsPerQuestion: math1PointsPerQuestion,
        maxScore: math1MaxScore,
        optionsPerQuestion: 4,
        order: 1,
        icon: '📐',
        color: '#6366F1',
        topics: ['Арифметика', 'Алгебраические выражения', 'Уравнения и неравенства', 'Проценты и пропорции', 'Геометрия'],
      ),
      const OrtSection(
        id: 'math2',
        blueprintSectionId: 'math',
        nameRu: 'Математика, часть II',
        nameKy: 'Математика, II бөлүк',
        nameEn: 'Mathematics, part II',
        descriptionRu: 'Задачи с выбором одного ответа из 5',
        descriptionKy: '5 варианттан бир жоопту тандоочу маселелер',
        descriptionEn: 'Problems with one answer out of 5',
        questionCount: math2Questions,
        timeMinutes: math2Minutes,
        pointsPerQuestion: math2PointsPerQuestion,
        maxScore: math2MaxScore,
        optionsPerQuestion: 5,
        order: 2,
        icon: '🔢',
        color: '#8B5CF6',
        topics: ['Текстовые задачи', 'Уравнения и системы', 'Функции и графики', 'Геометрия', 'Элементы комбинаторики и вероятности'],
      ),
      const OrtSection(
        id: 'analogies',
        blueprintSectionId: 'verbal',
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
        optionsPerQuestion: 4,
        order: 3,
        icon: '🔗',
        color: '#EC4899',
        topics: ['Синонимы', 'Антонимы', 'Часть-целое', 'Причина-следствие'],
      ),
      const OrtSection(
        id: 'completion',
        blueprintSectionId: 'verbal',
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
        optionsPerQuestion: 4,
        order: 4,
        icon: '✏️',
        color: '#F59E0B',
        topics: ['Контекст', 'Логика', 'Смысловые связи'],
      ),
      const OrtSection(
        id: 'reading',
        blueprintSectionId: 'reading',
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
        optionsPerQuestion: 4,
        order: 5,
        icon: '📄',
        color: '#06B6D4',
        topics: ['Главная мысль', 'Детали', 'Выводы', 'Авторская позиция'],
      ),
      const OrtSection(
        id: 'grammar',
        blueprintSectionId: 'grammar',
        nameRu: 'Практическая грамматика',
        nameKy: 'Практикалык грамматика',
        nameEn: 'Practical grammar',
        descriptionRu: 'Правила языка выбранного теста (русский или кыргызский)',
        descriptionKy: 'Тандалган тесттин тилинин эрежелери (орус же кыргыз)',
        descriptionEn: 'Language rules of the chosen test (Russian or Kyrgyz)',
        questionCount: grammarQuestions,
        timeMinutes: grammarMinutes,
        pointsPerQuestion: grammarPointsPerQuestion,
        maxScore: grammarMaxScore,
        optionsPerQuestion: 4,
        order: 6,
        icon: '📖',
        color: '#10B981',
        topics: ['Орфография', 'Пунктуация', 'Морфология', 'Синтаксис'],
      ),
    ];
  }

  /// Subject tests of 2026 with their real length (blueprint
  /// `ort_subject_{id}_2026`).
  static List<OrtSubject> get subjectTestsList {
    return const [
      OrtSubject(
        id: 'chemistry',
        code: 'CHEM',
        nameRu: 'Химия',
        nameKy: 'Химия',
        nameEn: 'Chemistry',
        icon: '🧪',
        color: '#22C55E',
        questionCount: 40,
        timeMinutes: 80,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'biology',
        code: 'BIO',
        nameRu: 'Биология',
        nameKy: 'Биология',
        nameEn: 'Biology',
        icon: '🧬',
        color: '#84CC16',
        questionCount: 40,
        timeMinutes: 60,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'physics',
        code: 'PHYS',
        nameRu: 'Физика',
        nameKy: 'Физика',
        nameEn: 'Physics',
        icon: '⚛️',
        color: '#EF4444',
        questionCount: 40,
        timeMinutes: 80,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'math',
        code: 'MATH',
        nameRu: 'Математика',
        nameKy: 'Математика',
        nameEn: 'Mathematics',
        icon: '📐',
        color: '#6366F1',
        questionCount: 40,
        timeMinutes: 80,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'history',
        code: 'HIST',
        nameRu: 'История',
        nameKy: 'Тарых',
        nameEn: 'History',
        icon: '🏛️',
        color: '#F97316',
        questionCount: 40,
        timeMinutes: 60,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'english',
        code: 'ENG',
        nameRu: 'Английский язык',
        nameKy: 'Англис тили',
        nameEn: 'English',
        icon: '🇬🇧',
        color: '#3B82F6',
        questionCount: 50,
        timeMinutes: 60,
        maxScore: 50,
      ),
      OrtSubject(
        id: 'kyrgyz_lit',
        code: 'KY_LIT',
        nameRu: 'Кыргызский язык и литература',
        nameKy: 'Кыргыз тили жана адабияты',
        nameEn: 'Kyrgyz language and literature',
        icon: '🇰🇬',
        color: '#DC2626',
        questionCount: 40,
        timeMinutes: 60,
        maxScore: 40,
      ),
      OrtSubject(
        id: 'russian_lit',
        code: 'RU_LIT',
        nameRu: 'Русский язык и литература',
        nameKy: 'Орус тили жана адабияты',
        nameEn: 'Russian language and literature',
        icon: '📚',
        color: '#2563EB',
        questionCount: 40,
        timeMinutes: 60,
        maxScore: 40,
      ),
    ];
  }

  /// Threshold scores for university admission, 2026–2027 (blueprint
  /// `reference.thresholds_2026_27.university`; source: testing.kg). They
  /// are set anew every year — always show them with the year.
  static const Map<String, int> universityThresholds = {
    'general': 110,
    'pedagogical_grant': 130,
    'pedagogical_contract': 115,
    'healthcare_grant': 120,
    'healthcare_contract': 110,
    'agriculture': 100,
    'military_grant': 90,
    'special_categories': 90,
    'subject_tests': 60,
  };

  /// Format time in mm:ss
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Calculate grade based on score
  static String getGrade(int score, int maxScore) {
    if (maxScore <= 0) return 'F';
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

  /// Blueprint section this part belongs to (`math`, `verbal`, `reading`,
  /// `grammar`); null for legacy callers.
  final String? blueprintSectionId;
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
  final int optionsPerQuestion;
  final int order;
  final String icon;
  final String color;
  final List<String> topics;

  const OrtSection({
    required this.id,
    this.blueprintSectionId,
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
    this.optionsPerQuestion = 4,
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
      if (blueprintSectionId != null) 'blueprintSectionId': blueprintSectionId,
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
      'optionsPerQuestion': optionsPerQuestion,
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
