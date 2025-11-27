import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject_model.dart';
import '../models/lesson_model.dart';
import '../models/question_model.dart';
import '../models/user_progress_model.dart';

/// Сервис для работы с реальными данными из Firebase Firestore
class FirebaseDataService {
  static final FirebaseDataService _instance = FirebaseDataService._internal();
  factory FirebaseDataService() => _instance;
  FirebaseDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== SUBJECTS ==========

  /// Получить все предметы из Firestore
  Future<List<SubjectModel>> getSubjects() async {
    try {
      final snapshot = await _firestore
          .collection('subjects')
          .orderBy('order', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('⚠️ No subjects found in Firestore. Using fallback data.');
        return _getFallbackSubjects();
      }

      return snapshot.docs
          .map((doc) => SubjectModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading subjects from Firebase: $e');
      return _getFallbackSubjects();
    }
  }

  /// Получить предмет по ID
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final doc = await _firestore.collection('subjects').doc(id).get();

      if (!doc.exists) {
        // ignore: avoid_print
        print('⚠️ Subject $id not found in Firestore');
        return _getFallbackSubjects().firstWhere(
          (s) => s.id == id,
          orElse: () => _getFallbackSubjects().first,
        );
      }

      return SubjectModel.fromFirestore(doc.data()!);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading subject $id: $e');
      return null;
    }
  }

  // ========== LESSONS ==========

  /// Получить все уроки для предмета
  Future<List<LessonModel>> getLessonsBySubject(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('subjectId', isEqualTo: subjectId)
          .orderBy('order', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('⚠️ No lessons found for subject $subjectId. Using fallback.');
        return _getFallbackLessons(subjectId);
      }

      return snapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading lessons for $subjectId: $e');
      return _getFallbackLessons(subjectId);
    }
  }

  /// Получить урок по ID
  Future<LessonModel?> getLessonById(String id) async {
    try {
      final doc = await _firestore.collection('lessons').doc(id).get();

      if (!doc.exists) {
        // ignore: avoid_print
        print('⚠️ Lesson $id not found in Firestore');
        return null;
      }

      return LessonModel.fromFirestore(doc.data()!);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading lesson $id: $e');
      return null;
    }
  }

  // ========== QUESTIONS ==========

  /// Получить вопросы для теста
  Future<List<QuestionModel>> getQuestions({
    int count = 10,
    String? subjectId,
    int? difficulty,
  }) async {
    try {
      Query query = _firestore.collection('questions');

      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }

      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query.limit(count).get();

      if (snapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('⚠️ No questions found. Using fallback questions.');
        return _getFallbackQuestions(count: count, subjectId: subjectId);
      }

      return snapshot.docs
          .map((doc) => QuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading questions: $e');
      return _getFallbackQuestions(count: count, subjectId: subjectId);
    }
  }

  /// Получить вопрос по ID
  Future<QuestionModel?> getQuestionById(String id) async {
    try {
      final doc = await _firestore.collection('questions').doc(id).get();

      if (!doc.exists) {
        // ignore: avoid_print
        print('⚠️ Question $id not found');
        return null;
      }

      return QuestionModel.fromFirestore(doc);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading question $id: $e');
      return null;
    }
  }

  // ========== USER PROGRESS ==========

  /// Получить прогресс пользователя
  Future<UserProgressModel?> getUserProgress(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_progress')
          .doc(userId)
          .get();

      if (!doc.exists) {
        // Создаём начальный прогресс для нового пользователя
        final initialProgress = UserProgressModel(
          userId: userId,
          testsCompleted: 0,
          averageScore: 0,
          streakDays: 0,
          totalStudyHours: 0,
          subjectProgress: {},
          completedLessons: [],
          lastActivityDate: DateTime.now(),
        );

        await saveUserProgress(initialProgress);
        return initialProgress;
      }

      return UserProgressModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading user progress: $e');
      return null;
    }
  }

  /// Сохранить прогресс пользователя
  Future<void> saveUserProgress(UserProgressModel progress) async {
    try {
      await _firestore
          .collection('user_progress')
          .doc(progress.userId)
          .set(progress.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error saving user progress: $e');
      rethrow;
    }
  }

  /// Обновить статистику после прохождения теста
  Future<void> updateTestStats(
    String userId,
    int score,
    int totalQuestions,
    String subjectId,
  ) async {
    try {
      final progress = await getUserProgress(userId);
      if (progress == null) return;

      final newTestsCompleted = progress.testsCompleted + 1;
      final newAverageScore =
          ((progress.averageScore * progress.testsCompleted) + score) / newTestsCompleted;

      final updatedProgress = progress.copyWith(
        testsCompleted: newTestsCompleted,
        averageScore: newAverageScore.round(),
        lastActivityDate: DateTime.now(),
      );

      await saveUserProgress(updatedProgress);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating test stats: $e');
    }
  }

  /// Обновить прогресс по предмету
  Future<void> updateSubjectProgress(
    String userId,
    String subjectId,
    double progress,
  ) async {
    try {
      final userProgress = await getUserProgress(userId);
      if (userProgress == null) return;

      final subjectProgress = Map<String, double>.from(userProgress.subjectProgress);
      subjectProgress[subjectId] = progress;

      final updatedProgress = userProgress.copyWith(
        subjectProgress: subjectProgress,
      );

      await saveUserProgress(updatedProgress);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating subject progress: $e');
    }
  }

  /// Отметить урок как пройденный
  Future<void> markLessonCompleted(String userId, String lessonId) async {
    try {
      final progress = await getUserProgress(userId);
      if (progress == null) return;

      if (!progress.completedLessons.contains(lessonId)) {
        final updatedProgress = progress.copyWith(
          completedLessons: [...progress.completedLessons, lessonId],
        );
        await saveUserProgress(updatedProgress);
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error marking lesson completed: $e');
    }
  }

  // ========== FALLBACK DATA (when Firebase is empty) ==========

  List<SubjectModel> _getFallbackSubjects() {
    return [
      SubjectModel(
        id: 'math',
        title: {'ru': 'Математика', 'ky': 'Математика', 'en': 'Mathematics'},
        description: {'ru': 'Алгебра, геометрия, тригонометрия', 'ky': 'Алгебра, геометрия, тригонометрия', 'en': 'Algebra, geometry, trigonometry'},
        icon: '📐',
        color: '#8B5CF6',
        moduleIds: ['math-1', 'math-2'],
        difficultyTags: ['basic', 'intermediate', 'advanced'],
        totalLessons: 24,
        totalQuestions: 240,
      ),
      SubjectModel(
        id: 'physics',
        title: {'ru': 'Физика', 'ky': 'Физика', 'en': 'Physics'},
        description: {'ru': 'Механика, электричество, оптика', 'ky': 'Механика, электр, оптика', 'en': 'Mechanics, electricity, optics'},
        icon: '⚡',
        color: '#3B82F6',
        totalLessons: 18,
        totalQuestions: 180,
      ),
      SubjectModel(
        id: 'chemistry',
        title: {'ru': 'Химия', 'ky': 'Химия', 'en': 'Chemistry'},
        description: {'ru': 'Органическая и неорганическая химия', 'ky': 'Органикалык жана органикалык эмес химия', 'en': 'Organic and inorganic chemistry'},
        icon: '🧪',
        color: '#10B981',
        totalLessons: 20,
        totalQuestions: 200,
      ),
      SubjectModel(
        id: 'biology',
        title: {'ru': 'Биология', 'ky': 'Биология', 'en': 'Biology'},
        description: {'ru': 'Анатомия, ботаника, генетика', 'ky': 'Анатомия, ботаника, генетика', 'en': 'Anatomy, botany, genetics'},
        icon: '🧬',
        color: '#06B6D4',
        totalLessons: 22,
        totalQuestions: 220,
      ),
      SubjectModel(
        id: 'history',
        title: {'ru': 'История Кыргызстана', 'ky': 'Кыргызстандын тарыхы', 'en': 'History of Kyrgyzstan'},
        description: {'ru': 'От древности до современности', 'ky': 'Байыркы мезгилден азыркы учурга чейин', 'en': 'From ancient times to present'},
        icon: '📜',
        color: '#EF4444',
        totalLessons: 16,
        totalQuestions: 160,
      ),
    ];
  }

  List<LessonModel> _getFallbackLessons(String subjectId) {
    final now = DateTime.now();
    return List.generate(5, (index) {
      return LessonModel(
        id: '$subjectId-lesson-${index + 1}',
        subjectId: subjectId,
        title: {
          'ru': 'Урок ${index + 1}',
          'ky': 'Сабак ${index + 1}',
          'en': 'Lesson ${index + 1}',
        },
        content: {
          'ru': 'Содержание урока ${index + 1} по предмету $subjectId',
          'ky': '$subjectId предмети боюнча ${index + 1} сабактын мазмуну',
          'en': 'Content of lesson ${index + 1} for subject $subjectId',
        },
        mediaUrls: [],
        estimatedTimeMinutes: 15 + (index * 5),
        tags: ['topic-${index + 1}'],
        order: index + 1,
        createdBy: 'admin',
        createdAt: now,
      );
    });
  }

  List<QuestionModel> _getFallbackQuestions({int count = 10, String? subjectId}) {
    final now = DateTime.now();
    final questions = <QuestionModel>[];

    for (int i = 0; i < count; i++) {
      questions.add(
        QuestionModel(
          id: 'question-${i + 1}',
          subjectId: subjectId ?? 'math',
          type: 'mcq',
          difficulty: (i % 5) + 1,
          stem: {
            'ru': 'Вопрос ${i + 1}: Сколько будет ${i + 1} + ${i + 1}?',
            'ky': 'Суроо ${i + 1}: ${i + 1} + ${i + 1} канча болот?',
            'en': 'Question ${i + 1}: What is ${i + 1} + ${i + 1}?',
          },
          options: [
            OptionModel(
              id: 'A',
              text: {
                'ru': '${(i + 1) * 2 - 1}',
                'ky': '${(i + 1) * 2 - 1}',
                'en': '${(i + 1) * 2 - 1}',
              },
            ),
            OptionModel(
              id: 'B',
              text: {
                'ru': '${(i + 1) * 2}',
                'ky': '${(i + 1) * 2}',
                'en': '${(i + 1) * 2}',
              },
            ),
            OptionModel(
              id: 'C',
              text: {
                'ru': '${(i + 1) * 2 + 1}',
                'ky': '${(i + 1) * 2 + 1}',
                'en': '${(i + 1) * 2 + 1}',
              },
            ),
            OptionModel(
              id: 'D',
              text: {
                'ru': '${(i + 1) * 2 + 2}',
                'ky': '${(i + 1) * 2 + 2}',
                'en': '${(i + 1) * 2 + 2}',
              },
            ),
          ],
          correctAnswer: 'B',
          explanation: {
            'ru': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
            'ky': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
            'en': '${i + 1} + ${i + 1} = ${(i + 1) * 2}',
          },
          tags: ['arithmetic', 'basic'],
          createdBy: 'admin',
          createdAt: now,
        ),
      );
    }

    return questions;
  }

  // ========== ORT TESTS ==========

  /// Get all ORT tests
  Future<List<dynamic>> getOrtTests() async {
    try {
      final snapshot = await _firestore.collection('ort_tests').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading ORT tests: $e');
      return [];
    }
  }

  // ========== DAILY MISSIONS ==========

  /// Get daily missions
  Future<List<dynamic>> getDailyMissions() async {
    try {
      final snapshot = await _firestore
          .collection('daily_missions')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading daily missions: $e');
      return [];
    }
  }

  /// Get user mission progress
  Future<Map<String, dynamic>?> getUserMissionProgress(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_mission_progress')
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading user mission progress: $e');
      return null;
    }
  }

  /// Update mission progress
  Future<void> updateMissionProgress(
    String userId,
    String missionId,
    int progress,
  ) async {
    try {
      await _firestore
          .collection('user_mission_progress')
          .doc(userId)
          .set({
        missionId: progress,
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating mission progress: $e');
    }
  }
}
