import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/backend_contract.dart';

/// Writes the draft of the open section to
/// `exam_attempts/{attemptId}/drafts/{sectionId}` (ARCHITECTURE §1). The
/// server uses drafts to close a section the client never submitted
/// (`examExpireStale`); they are never trusted for scoring of a submitted
/// section.
abstract interface class ExamDraftSink {
  Future<void> writeDraft({
    required String attemptId,
    required String sectionId,
    required Map<String, String> answers,
    required List<String> flags,
  });
}

class FirestoreExamDraftSink implements ExamDraftSink {
  final FirebaseFirestore _db;

  const FirestoreExamDraftSink(this._db);

  @override
  Future<void> writeDraft({
    required String attemptId,
    required String sectionId,
    required Map<String, String> answers,
    required List<String> flags,
  }) {
    return _db
        .collection(Collections.examAttempts)
        .doc(attemptId)
        .collection(Collections.examDrafts)
        .doc(sectionId)
        .set({
      'section_id': sectionId,
      'answers': answers,
      'flags': flags,
      'client_saved_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
