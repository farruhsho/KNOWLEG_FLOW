import 'dart:async';
import '../models/subject_model.dart';
import '../models/question_model.dart';
import '../models/mock_test_model.dart';

/// Сервис управления для администраторов
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  // Простая авторизация админа (в продакшн использовать Firebase Auth с custom claims)
  final Map<String, String> _adminCredentials = {
    'admin@ort.kg': 'admin123',
    'superadmin@ort.kg': 'super123',
  };

  String? _currentAdminEmail;

  // Временное хранилище данных
  final Map<String, SubjectModel> _subjects = {};
  final Map<String, QuestionModel> _questions = {};
  final Map<String, MockTestModel> _mockTests = {};

  bool get isAdminLoggedIn => _currentAdminEmail != null;
  String? get currentAdminEmail => _currentAdminEmail;

  /// Вход администратора
  Future<bool> loginAdmin(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (_adminCredentials[email] == password) {
      _currentAdminEmail = email;
      return true;
    }
    return false;
  }

  /// Выход администратора
  Future<void> logoutAdmin() async {
    _currentAdminEmail = null;
  }

  // ==================== УПРАВЛЕНИЕ ПРЕДМЕТАМИ ====================

  /// Получить все предметы
  Future<List<SubjectModel>> getAllSubjects() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _subjects.values.toList();
  }

  /// Получить предмет по ID
  Future<SubjectModel?> getSubject(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _subjects[id];
  }

  /// Создать новый предмет
  Future<SubjectModel> createSubject(SubjectModel subject) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _subjects[subject.id] = subject;
    return subject;
  }

  /// Обновить предмет
  Future<SubjectModel> updateSubject(SubjectModel subject) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _subjects[subject.id] = subject;
    return subject;
  }

  /// Удалить предмет
  Future<void> deleteSubject(String id) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _subjects.remove(id);

    // Удалить связанные вопросы
    _questions.removeWhere((key, question) => question.subjectId == id);
  }

  // ==================== УПРАВЛЕНИЕ ВОПРОСАМИ ====================

  /// Получить все вопросы
  Future<List<QuestionModel>> getAllQuestions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _questions.values.toList();
  }

  /// Получить вопросы по предмету
  Future<List<QuestionModel>> getQuestionsBySubject(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _questions.values
        .where((q) => q.subjectId == subjectId)
        .toList();
  }

  /// Получить вопрос по ID
  Future<QuestionModel?> getQuestion(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _questions[id];
  }

  /// Создать новый вопрос
  Future<QuestionModel> createQuestion(QuestionModel question) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _questions[question.id] = question;

    // Обновить счетчик вопросов в предмете
    final subject = _subjects[question.subjectId];
    if (subject != null) {
      final questionCount = _questions.values
          .where((q) => q.subjectId == question.subjectId)
          .length;
      _subjects[question.subjectId] = SubjectModel(
        id: subject.id,
        title: subject.title,
        description: subject.description,
        icon: subject.icon,
        color: subject.color,
        moduleIds: subject.moduleIds,
        difficultyTags: subject.difficultyTags,
        totalLessons: subject.totalLessons,
        totalQuestions: questionCount,
      );
    }

    return question;
  }

  /// Создать несколько вопросов
  Future<List<QuestionModel>> createQuestionsBatch(List<QuestionModel> questions) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 500));

    for (final question in questions) {
      _questions[question.id] = question;
    }

    // Обновить счетчики для всех затронутых предметов
    final subjectIds = questions.map((q) => q.subjectId).toSet();
    for (final subjectId in subjectIds) {
      final subject = _subjects[subjectId];
      if (subject != null) {
        final questionCount = _questions.values
            .where((q) => q.subjectId == subjectId)
            .length;
        _subjects[subjectId] = SubjectModel(
          id: subject.id,
          title: subject.title,
          description: subject.description,
          icon: subject.icon,
          color: subject.color,
          moduleIds: subject.moduleIds,
          difficultyTags: subject.difficultyTags,
          totalLessons: subject.totalLessons,
          totalQuestions: questionCount,
        );
      }
    }

    return questions;
  }

  /// Обновить вопрос
  Future<QuestionModel> updateQuestion(QuestionModel question) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _questions[question.id] = question;
    return question;
  }

  /// Удалить вопрос
  Future<void> deleteQuestion(String id) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    final question = _questions.remove(id);

    // Обновить счетчик вопросов в предмете
    if (question != null) {
      final subject = _subjects[question.subjectId];
      if (subject != null) {
        final questionCount = _questions.values
            .where((q) => q.subjectId == question.subjectId)
            .length;
        _subjects[question.subjectId] = SubjectModel(
          id: subject.id,
          title: subject.title,
          description: subject.description,
          icon: subject.icon,
          color: subject.color,
          moduleIds: subject.moduleIds,
          difficultyTags: subject.difficultyTags,
          totalLessons: subject.totalLessons,
          totalQuestions: questionCount,
        );
      }
    }
  }

  // ==================== УПРАВЛЕНИЕ ТЕСТАМИ ====================

  /// Получить все тесты
  Future<List<MockTestModel>> getAllMockTests() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockTests.values.toList();
  }

  /// Получить тест по ID
  Future<MockTestModel?> getMockTest(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockTests[id];
  }

  /// Создать новый тест
  Future<MockTestModel> createMockTest(MockTestModel test) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _mockTests[test.id] = test;
    return test;
  }

  /// Обновить тест
  Future<MockTestModel> updateMockTest(MockTestModel test) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _mockTests[test.id] = test;
    return test;
  }

  /// Удалить тест
  Future<void> deleteMockTest(String id) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    await Future.delayed(const Duration(milliseconds: 300));
    _mockTests.remove(id);
  }

  /// Опубликовать тест
  Future<MockTestModel> publishMockTest(String id) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    final test = _mockTests[id];
    if (test == null) throw Exception('Тест не найден');

    final updatedTest = MockTestModel(
      id: test.id,
      title: test.title,
      description: test.description,
      sections: test.sections,
      priceKGS: test.priceKGS,
      isPublished: true,
      createdBy: test.createdBy,
      createdAt: test.createdAt,
    );

    _mockTests[id] = updatedTest;
    return updatedTest;
  }

  /// Снять с публикации
  Future<MockTestModel> unpublishMockTest(String id) async {
    if (!isAdminLoggedIn) throw Exception('Требуется авторизация администратора');

    final test = _mockTests[id];
    if (test == null) throw Exception('Тест не найден');

    final updatedTest = MockTestModel(
      id: test.id,
      title: test.title,
      description: test.description,
      sections: test.sections,
      priceKGS: test.priceKGS,
      isPublished: false,
      createdBy: test.createdBy,
      createdAt: test.createdAt,
    );

    _mockTests[id] = updatedTest;
    return updatedTest;
  }

  // ==================== СТАТИСТИКА ====================

  /// Получить статистику для админ-панели
  Future<Map<String, dynamic>> getStatistics() async {
    await Future.delayed(const Duration(milliseconds: 200));

    return {
      'totalSubjects': _subjects.length,
      'totalQuestions': _questions.length,
      'totalMockTests': _mockTests.length,
      'publishedTests': _mockTests.values.where((t) => t.isPublished).length,
      'questionsByDifficulty': _getQuestionsByDifficulty(),
      'questionsBySubject': _getQuestionsBySubject(),
    };
  }

  Map<int, int> _getQuestionsByDifficulty() {
    final Map<int, int> result = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final question in _questions.values) {
      result[question.difficulty] = (result[question.difficulty] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _getQuestionsBySubject() {
    final Map<String, int> result = {};
    for (final question in _questions.values) {
      result[question.subjectId] = (result[question.subjectId] ?? 0) + 1;
    }
    return result;
  }
}
