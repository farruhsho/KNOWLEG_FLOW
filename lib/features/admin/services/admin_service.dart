import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/subject_model.dart';
import '../../../shared/models/lesson_model.dart';
import '../../../shared/models/question_model.dart';
import '../../../shared/models/daily_mission_model.dart';

/// Admin service for CRUD operations on content
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== SUBJECTS ==========

  /// Create new subject
  Future<String> createSubject(SubjectModel subject) async {
    try {
      final docRef = await _firestore.collection('subjects').add(subject.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create subject: $e');
    }
  }

  /// Update existing subject
  Future<void> updateSubject(String id, SubjectModel subject) async {
    try {
      await _firestore.collection('subjects').doc(id).update(subject.toFirestore());
    } catch (e) {
      throw Exception('Failed to update subject: $e');
    }
  }

  /// Delete subject
  Future<void> deleteSubject(String id) async {
    try {
      // Delete subject
      await _firestore.collection('subjects').doc(id).delete();
      
      // TODO: Consider cascade delete for lessons and questions
    } catch (e) {
      throw Exception('Failed to delete subject: $e');
    }
  }

  /// Get all subjects
  Future<List<SubjectModel>> getAllSubjects() async {
    try {
      final snapshot = await _firestore
          .collection('subjects')
          .orderBy('order', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => SubjectModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get subjects: $e');
    }
  }

  // ========== LESSONS ==========

  /// Create new lesson
  Future<String> createLesson(LessonModel lesson) async {
    try {
      final docRef = await _firestore.collection('lessons').add(lesson.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create lesson: $e');
    }
  }

  /// Update existing lesson
  Future<void> updateLesson(String id, LessonModel lesson) async {
    try {
      await _firestore.collection('lessons').doc(id).update(lesson.toFirestore());
    } catch (e) {
      throw Exception('Failed to update lesson: $e');
    }
  }

  /// Delete lesson
  Future<void> deleteLesson(String id) async {
    try {
      await _firestore.collection('lessons').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete lesson: $e');
    }
  }

  /// Get lessons by subject
  Future<List<LessonModel>> getLessonsBySubject(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection('lessons')
          .where('subjectId', isEqualTo: subjectId)
          .orderBy('order', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get lessons: $e');
    }
  }

  // ========== QUESTIONS ==========

  /// Create new question
  Future<String> createQuestion(QuestionModel question) async {
    try {
      final docRef = await _firestore.collection('questions').add(question.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create question: $e');
    }
  }

  /// Update existing question
  Future<void> updateQuestion(String id, QuestionModel question) async {
    try {
      await _firestore.collection('questions').doc(id).update(question.toFirestore());
    } catch (e) {
      throw Exception('Failed to update question: $e');
    }
  }

  /// Delete question
  Future<void> deleteQuestion(String id) async {
    try {
      await _firestore.collection('questions').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete question: $e');
    }
  }

  /// Get questions by subject
  Future<List<QuestionModel>> getQuestionsBySubject(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('subjectId', isEqualTo: subjectId)
          .get();

      return snapshot.docs
          .map((doc) => QuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get questions: $e');
    }
  }

  /// Search questions
  Future<List<QuestionModel>> searchQuestions({
    String? subjectId,
    int? difficulty,
    List<String>? tags,
  }) async {
    try {
      Query query = _firestore.collection('questions');

      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query.get();
      var questions = snapshot.docs
          .map((doc) => QuestionModel.fromFirestore(doc))
          .toList();

      // Filter by tags if provided
      if (tags != null && tags.isNotEmpty) {
        questions = questions.where((q) {
          return tags.any((tag) => (q.tags).contains(tag));
        }).toList();
      }

      return questions;
    } catch (e) {
      throw Exception('Failed to search questions: $e');
    }
  }

  // ========== DAILY MISSIONS ==========

  /// Create new mission
  Future<String> createMission(DailyMissionModel mission) async {
    try {
      final docRef = await _firestore.collection('daily_missions').add(mission.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create mission: $e');
    }
  }

  /// Update existing mission
  Future<void> updateMission(String id, DailyMissionModel mission) async {
    try {
      await _firestore.collection('daily_missions').doc(id).update(mission.toFirestore());
    } catch (e) {
      throw Exception('Failed to update mission: $e');
    }
  }

  /// Delete mission
  Future<void> deleteMission(String id) async {
    try {
      await _firestore.collection('daily_missions').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete mission: $e');
    }
  }

  /// Get all missions
  Future<List<DailyMissionModel>> getAllMissions() async {
    try {
      final snapshot = await _firestore
          .collection('daily_missions')
          .orderBy('expiresAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => DailyMissionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get missions: $e');
    }
  }

  // ========== BATCH OPERATIONS ==========

  /// Bulk delete questions
  Future<void> bulkDeleteQuestions(List<String> questionIds) async {
    try {
      final batch = _firestore.batch();
      for (final id in questionIds) {
        batch.delete(_firestore.collection('questions').doc(id));
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk delete questions: $e');
    }
  }

  /// Update question difficulty in bulk
  Future<void> bulkUpdateDifficulty(List<String> questionIds, int difficulty) async {
    try {
      final batch = _firestore.batch();
      for (final id in questionIds) {
        batch.update(
          _firestore.collection('questions').doc(id),
          {'difficulty': difficulty},
        );
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update difficulty: $e');
    }
  }
}
