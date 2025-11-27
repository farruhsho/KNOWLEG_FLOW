import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';

/// Questions repository provider
final questionsRepositoryProvider = Provider((ref) => QuestionsRepository());

/// Repository for managing questions
class QuestionsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'questions';

  /// Get all questions stream
  Stream<List<QuestionModel>> getQuestionsStream({
    String? subjectId,
    int? difficulty,
    bool? isActive,
  }) {
    Query query = _firestore.collection(_collection);

    if (subjectId != null) {
      query = query.where('subject_id', isEqualTo: subjectId);
    }
    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty);
    }
    if (isActive != null) {
      query = query.where('is_active', isEqualTo: isActive);
    }

    return query.orderBy('created_at', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => QuestionModel.fromFirestore(doc))
            .toList();
      },
    );
  }

  /// Get single question
  Future<QuestionModel?> getQuestion(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return QuestionModel.fromFirestore(doc);
  }

  /// Create question
  Future<String> createQuestion(QuestionModel question) async {
    final docRef = await _firestore.collection(_collection).add(
          question.toFirestore(),
        );
    return docRef.id;
  }

  /// Update question
  Future<void> updateQuestion(QuestionModel question) async {
    await _firestore
        .collection(_collection)
        .doc(question.id)
        .update(question.toFirestore());
  }

  /// Delete question
  Future<void> deleteQuestion(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Bulk delete questions
  Future<void> bulkDeleteQuestions(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_firestore.collection(_collection).doc(id));
    }
    await batch.commit();
  }

  /// Bulk update difficulty
  Future<void> bulkUpdateDifficulty(List<String> ids, int difficulty) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(
        _firestore.collection(_collection).doc(id),
        {'difficulty': difficulty, 'updated_at': Timestamp.now()},
      );
    }
    await batch.commit();
  }

  /// Bulk add tags
  Future<void> bulkAddTags(List<String> ids, List<String> tags) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(
        _firestore.collection(_collection).doc(id),
        {
          'tags': FieldValue.arrayUnion(tags),
          'updated_at': Timestamp.now(),
        },
      );
    }
    await batch.commit();
  }

  /// Search questions
  Future<List<QuestionModel>> searchQuestions(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .where((question) {
      final stemRu = question.stem['ru']?.toLowerCase() ?? '';
      final stemKy = question.stem['ky']?.toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return stemRu.contains(searchQuery) || stemKy.contains(searchQuery);
    }).toList();
  }

  /// Get questions by subject
  Future<List<QuestionModel>> getQuestionsBySubject(String subjectId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('subject_id', isEqualTo: subjectId)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .toList();
  }

  /// Get questions by difficulty
  Future<List<QuestionModel>> getQuestionsByDifficulty(int difficulty) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('difficulty', isEqualTo: difficulty)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .toList();
  }

  /// Get questions by tags
  Future<List<QuestionModel>> getQuestionsByTags(List<String> tags) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('tags', arrayContainsAny: tags)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => QuestionModel.fromFirestore(doc))
        .toList();
  }

  /// Import questions from JSON
  Future<int> importQuestions(List<Map<String, dynamic>> questionsData) async {
    final batch = _firestore.batch();
    int count = 0;

    for (final data in questionsData) {
      final docRef = _firestore.collection(_collection).doc();
      batch.set(docRef, data);
      count++;

      // Firestore batch limit is 500
      if (count % 500 == 0) {
        await batch.commit();
      }
    }

    if (count % 500 != 0) {
      await batch.commit();
    }

    return count;
  }

  /// Export questions to JSON
  Future<List<Map<String, dynamic>>> exportQuestions({
    String? subjectId,
    List<String>? questionIds,
  }) async {
    Query query = _firestore.collection(_collection);

    if (subjectId != null) {
      query = query.where('subject_id', isEqualTo: subjectId);
    }

    if (questionIds != null && questionIds.isNotEmpty) {
      // Firestore 'in' query limit is 10
      final chunks = <List<String>>[];
      for (var i = 0; i < questionIds.length; i += 10) {
        chunks.add(
          questionIds.sublist(
            i,
            i + 10 > questionIds.length ? questionIds.length : i + 10,
          ),
        );
      }

      final allDocs = <QueryDocumentSnapshot>[];
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        allDocs.addAll(snapshot.docs);
      }

      return allDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}

/// Questions list provider
final questionsProvider = StreamProvider.family<List<QuestionModel>, String?>(
  (ref, subjectId) {
    final repository = ref.watch(questionsRepositoryProvider);
    return repository.getQuestionsStream(subjectId: subjectId);
  },
);
