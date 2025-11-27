import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject_model.dart';

/// Subjects repository provider
final subjectsRepositoryProvider = Provider((ref) => SubjectsRepository());

/// Repository for managing subjects
class SubjectsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'subjects';

  /// Get all subjects stream
  Stream<List<SubjectModel>> getSubjectsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubjectModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get single subject
  Future<SubjectModel?> getSubject(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return SubjectModel.fromFirestore(doc);
  }

  /// Create subject
  Future<String> createSubject(SubjectModel subject) async {
    final docRef = await _firestore.collection(_collection).add(
          subject.toFirestore(),
        );
    return docRef.id;
  }

  /// Update subject
  Future<void> updateSubject(SubjectModel subject) async {
    await _firestore
        .collection(_collection)
        .doc(subject.id)
        .update(subject.toFirestore());
  }

  /// Delete subject
  Future<void> deleteSubject(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Bulk delete subjects
  Future<void> bulkDeleteSubjects(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_firestore.collection(_collection).doc(id));
    }
    await batch.commit();
  }

  /// Search subjects
  Future<List<SubjectModel>> searchSubjects(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => SubjectModel.fromFirestore(doc))
        .where((subject) {
      final titleRu = subject.title['ru']?.toLowerCase() ?? '';
      final titleKy = subject.title['ky']?.toLowerCase() ?? '';
      final titleEn = subject.title['en']?.toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return titleRu.contains(searchQuery) ||
          titleKy.contains(searchQuery) ||
          titleEn.contains(searchQuery);
    }).toList();
  }
}

/// Subjects list provider
final subjectsProvider = StreamProvider<List<SubjectModel>>((ref) {
  final repository = ref.watch(subjectsRepositoryProvider);
  return repository.getSubjectsStream();
});
