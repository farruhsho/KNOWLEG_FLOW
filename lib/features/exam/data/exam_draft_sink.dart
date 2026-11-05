import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/backend_contract.dart';

/// Writes the draft of the open section to
/// `exam_attempts/{attemptId}/drafts/{sectionId}` (ARCHITECTURE §1). The
/// server uses drafts to close a section the client never submitted
/// (`examExpireStale`); they are never trusted for scoring of a submitted
/// section. The device's Hive copy stays authoritative for the runner: a
/// failed draft write never changes local state.
abstract interface class ExamDraftSink {
  Future<void> writeDraft({
    required String attemptId,
    required String sectionId,
    required Map<String, String> answers,
    required List<String> flags,
  });
}

/// The only keys a draft document may have. `firestore.rules`
/// (`canWriteDraft`) enforces `hasOnly` on exactly this list, so adding a key
/// here without changing the rule makes every autosave PERMISSION_DENIED.
/// The section id is the document id and is not repeated in the body.
const List<String> examDraftKeys = ['answers', 'flags', 'client_updated_at'];

/// Body of a draft document (contract D1): `answers` (question id → option
/// id), `flags` (question ids) and `client_updated_at`, which defaults to
/// [FieldValue.serverTimestamp] so the rule can compare it with
/// `request.time`.
Map<String, Object> examDraftData({
  required Map<String, String> answers,
  required List<String> flags,
  Object? clientUpdatedAt,
}) =>
    {
      'answers': Map<String, String>.of(answers),
      'flags': List<String>.of(flags),
      'client_updated_at': clientUpdatedAt ?? FieldValue.serverTimestamp(),
    };

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
    // A full set() (no merge): the stored document is exactly
    // [examDraftData], so stale keys from older builds are dropped too.
    return _db
        .collection(Collections.examAttempts)
        .doc(attemptId)
        .collection(Collections.examDrafts)
        .doc(sectionId)
        .set(examDraftData(answers: answers, flags: flags));
  }
}
