import 'package:hive_flutter/hive_flutter.dart';
import '../models/question_model.dart';
import '../models/subject_model.dart';
import '../models/lesson_model.dart';
import '../models/user_progress_model.dart';

/// Offline database service using Hive for local storage
class OfflineDatabase {
  static final OfflineDatabase _instance = OfflineDatabase._internal();
  factory OfflineDatabase() => _instance;
  OfflineDatabase._internal();

  // Box names
  static const String _questionsBox = 'questions';
  static const String _subjectsBox = 'subjects';
  static const String _lessonsBox = 'lessons';
  static const String _progressBox = 'progress';
  static const String _settingsBox = 'settings';

  bool _initialized = false;

  /// Initialize Hive and register adapters
  Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register type adapters if needed
    // Hive.registerAdapter(QuestionModelAdapter());
    // For now, we'll use JSON serialization

    _initialized = true;
  }

  /// Open all required boxes
  Future<void> openBoxes() async {
    await Future.wait([
      Hive.openBox(_questionsBox),
      Hive.openBox(_subjectsBox),
      Hive.openBox(_lessonsBox),
      Hive.openBox(_progressBox),
      Hive.openBox(_settingsBox),
    ]);
  }

  // ==================== QUESTIONS ====================

  /// Save questions to offline storage
  Future<void> saveQuestions(List<QuestionModel> questions) async {
    final box = Hive.box(_questionsBox);
    for (final question in questions) {
      await box.put(question.id, question.toJson());
    }
  }

  /// Get all offline questions
  Future<List<QuestionModel>> getQuestions() async {
    final box = Hive.box(_questionsBox);
    final List<QuestionModel> questions = [];
    
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        // questions.add(QuestionModel.fromJson(data));
        // Implement fromJson in QuestionModel
      }
    }
    
    return questions;
  }

  /// Get questions by subject
  Future<List<QuestionModel>> getQuestionsBySubject(String subjectId) async {
    final allQuestions = await getQuestions();
    return allQuestions.where((q) => q.subjectId == subjectId).toList();
  }

  /// Delete question
  Future<void> deleteQuestion(String id) async {
    final box = Hive.box(_questionsBox);
    await box.delete(id);
  }

  /// Clear all questions
  Future<void> clearQuestions() async {
    final box = Hive.box(_questionsBox);
    await box.clear();
  }

  // ==================== SUBJECTS ====================

  /// Save subjects
  Future<void> saveSubjects(List<SubjectModel> subjects) async {
    final box = Hive.box(_subjectsBox);
    for (final subject in subjects) {
      // TODO: Implement toJson in SubjectModel
      // await box.put(subject.id, subject.toJson());
      await box.put(subject.id, {
        'id': subject.id,
        'title': subject.title,
        'icon': subject.icon,
      });
    }
  }

  /// Get all subjects
  Future<List<SubjectModel>> getSubjects() async {
    final box = Hive.box(_subjectsBox);
    final List<SubjectModel> subjects = [];
    
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        // TODO: Implement fromJson in SubjectModel
        // subjects.add(SubjectModel.fromJson(data));
      }
    }
    
    return subjects;
  }

  // ==================== LESSONS ====================

  /// Save lessons
  Future<void> saveLessons(List<LessonModel> lessons) async {
    final box = Hive.box(_lessonsBox);
    for (final lesson in lessons) {
      // TODO: Implement toJson in LessonModel
      // await box.put(lesson.id, lesson.toJson());
      await box.put(lesson.id, {
        'id': lesson.id,
        'title': lesson.title,
        'subjectId': lesson.subjectId,
      });
    }
  }

  /// Get lessons by subject
  Future<List<LessonModel>> getLessonsBySubject(String subjectId) async {
    final box = Hive.box(_lessonsBox);
    final List<LessonModel> lessons = [];
    
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        // TODO: Implement fromJson in LessonModel
        // final lesson = LessonModel.fromJson(data);
        // if (lesson.subjectId == subjectId) {
        //   lessons.add(lesson);
        // }
      }
    }
    
    return lessons;
  }

  // ==================== PROGRESS ====================

  /// Save user progress
  Future<void> saveProgress(UserProgressModel progress) async {
    final box = Hive.box(_progressBox);
    await box.put(progress.userId, progress.toFirestore());
  }

  /// Get user progress
  Future<UserProgressModel?> getProgress(String userId) async {
    final box = Hive.box(_progressBox);
    final data = box.get(userId);
    
    if (data != null) {
      return UserProgressModel.fromFirestore(data, userId);
    }
    
    return null;
  }

  // ==================== SETTINGS ====================

  /// Save setting
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  /// Get setting
  T? getSetting<T>(String key, {T? defaultValue}) {
    final box = Hive.box(_settingsBox);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  // ==================== SYNC STATUS ====================

  /// Check if data needs sync
  Future<bool> needsSync() async {
    final lastSync = getSetting<int>('last_sync_timestamp');
    if (lastSync == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceSync = (now - lastSync) / (1000 * 60 * 60);
    
    return hoursSinceSync > 24; // Sync if more than 24 hours
  }

  /// Update last sync timestamp
  Future<void> updateSyncTimestamp() async {
    await saveSetting('last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get offline data size
  Future<int> getDataSize() async {
    int totalSize = 0;
    
    final boxes = [
      Hive.box(_questionsBox),
      Hive.box(_subjectsBox),
      Hive.box(_lessonsBox),
      Hive.box(_progressBox),
      Hive.box(_settingsBox),
    ];
    
    for (final box in boxes) {
      totalSize += box.length;
    }
    
    return totalSize;
  }

  /// Clear all offline data
  Future<void> clearAllData() async {
    await Future.wait([
      Hive.box(_questionsBox).clear(),
      Hive.box(_subjectsBox).clear(),
      Hive.box(_lessonsBox).clear(),
      Hive.box(_progressBox).clear(),
      // Don't clear settings
    ]);
  }

  /// Close all boxes
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}
