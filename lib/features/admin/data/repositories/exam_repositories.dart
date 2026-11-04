import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/blueprint_spec.dart';
import '../../domain/exam_question.dart';
import '../../domain/review_workflow.dart';
import '../../domain/variant_validation.dart';
import '../admin_firebase.dart';
import '../models/admin_records.dart';

/// Exam bank filter (equality filters only → no composite indexes needed).
typedef ExamBankFilter = ({
  String? subjectId,
  String? sectionId,
  String? partId,
  String? topicId,
  int? difficulty,
  String? language,
  String? reviewStatus,
});

const ExamBankFilter kEmptyExamBankFilter = (
  subjectId: null,
  sectionId: null,
  partId: null,
  topicId: null,
  difficulty: null,
  language: null,
  reviewStatus: null,
);

/// `exam_questions` + `exam_question_keys` + `exam_passages` (§1.3).
class ExamBankRepository {
  ExamBankRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _questions =>
      _db.collection(AdminCollections.examQuestions);
  CollectionReference<Map<String, dynamic>> get _keys =>
      _db.collection(AdminCollections.examQuestionKeys);
  CollectionReference<Map<String, dynamic>> get _passages =>
      _db.collection(AdminCollections.examPassages);

  String newId() => _questions.doc().id;
  String newPassageId() => _passages.doc().id;

  Query<Map<String, dynamic>> _query(ExamBankFilter f) {
    Query<Map<String, dynamic>> q = _questions;
    if (f.subjectId != null) q = q.where('subject_id', isEqualTo: f.subjectId);
    if (f.sectionId != null) q = q.where('section_id', isEqualTo: f.sectionId);
    if (f.partId != null) q = q.where('part_id', isEqualTo: f.partId);
    if (f.topicId != null) q = q.where('topic_id', isEqualTo: f.topicId);
    if (f.difficulty != null) q = q.where('difficulty', isEqualTo: f.difficulty);
    if (f.language != null) q = q.where('language', isEqualTo: f.language);
    if (f.reviewStatus != null) q = q.where('review.status', isEqualTo: f.reviewStatus);
    return q;
  }

  Future<AdminPage<ExamQuestionDoc>> page(
    ExamBankFilter f, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) =>
      fetchPage(_query(f),
          after: after,
          pageSize: pageSize,
          map: (d) => ExamQuestionDoc.fromMap(d.id, d.data() ?? const {}));

  Future<({ExamQuestionDoc question, ExamKeyDoc key})?> get(String id) async {
    final r = await Future.wait([_questions.doc(id).get(), _keys.doc(id).get()]);
    final data = r[0].data();
    if (data == null) return null;
    return (question: ExamQuestionDoc.fromMap(id, data), key: ExamKeyDoc.fromMap(r[1].data()));
  }

  /// Writes question + key atomically. [review] is the status after this
  /// edit (see [ReviewWorkflow.statusAfterContentEdit]).
  ///
  /// With [original] (the document as loaded) an update writes only the
  /// fields that changed, and with [originalKey] the key is written only when
  /// it changed — so a metadata-only edit never touches review-relevant
  /// fields (AUTH-ADM-04). `content_hash` is never written (D11); every save
  /// sets [kEditedInCmsAtField] so the content pipeline does not silently
  /// revert it (CP-04). A save without any change writes nothing.
  Future<void> save(
    ExamQuestionDoc q,
    ExamKeyDoc key, {
    required bool isNew,
    required String actor,
    required ReviewStatus review,
    bool reviewChanged = false,
    ExamQuestionDoc? original,
    ExamKeyDoc? originalKey,
  }) async {
    final fields = examQuestionWriteFields(q, isNew: isNew, original: original);
    final writeKey = isNew || originalKey == null || !key.sameAs(originalKey);
    if (!isNew && fields.isEmpty && !reviewChanged && !writeKey) return;
    final batch = _db.batch();
    fields
      ..['updated_at'] = FieldValue.serverTimestamp()
      ..['updated_by'] = actor
      ..[kEditedInCmsAtField] = FieldValue.serverTimestamp();
    if (isNew || reviewChanged) {
      // Saving content is never a review decision: an automatic reset (content
      // edited by a non-reviewer) clears the previous reviewer.
      fields['review'] = {
        'status': review.wire,
        'reviewed_by': null,
        'reviewed_at': null,
        'notes': q.review.notes,
      };
    }
    if (isNew) {
      fields
        ..['created_at'] = FieldValue.serverTimestamp()
        ..['created_by'] = actor;
      batch.set(_questions.doc(q.id), fields);
    } else {
      batch.update(_questions.doc(q.id), fields);
    }
    if (writeKey) {
      batch.set(_keys.doc(q.id), {
        ...key.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': actor,
        kEditedInCmsAtField: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Review transition (approve / reject / send back). Approving requires a
  /// key with a correct option — checked here as well as in the UI.
  Future<void> setReview(String id, ReviewStatus status,
      {required String actor, String notes = ''}) async {
    if (status == ReviewStatus.methodologistApproved) {
      final key = ExamKeyDoc.fromMap((await _keys.doc(id).get()).data());
      if (!key.hasCorrect) throw const MissingKeyException();
    }
    await _questions.doc(id).update({
      'review.status': status.wire,
      'review.reviewed_by': actor,
      'review.reviewed_at': FieldValue.serverTimestamp(),
      'review.notes': notes,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final batch = _db.batch()
      ..delete(_questions.doc(id))
      ..delete(_keys.doc(id));
    await batch.commit();
  }

  // --- Translations ---------------------------------------------------------

  Future<List<ExamQuestionDoc>> translations(String groupId) async {
    final snap =
        await _questions.where('translation_group_id', isEqualTo: groupId).limit(10).get();
    return [for (final d in snap.docs) ExamQuestionDoc.fromMap(d.id, d.data())];
  }

  /// Ensures [questionId] has a translation group and returns it.
  Future<String> ensureGroup(String questionId, String? current) async {
    if (current != null && current.isNotEmpty) return current;
    final group = 'tg_$questionId';
    await _questions.doc(questionId).update({'translation_group_id': group});
    return group;
  }

  /// Links [targetId] into the translation group of [sourceId].
  Future<String> link(String sourceId, String? sourceGroup, String targetId) async {
    final target = await _questions.doc(targetId).get();
    if (!target.exists) throw const QuestionNotFoundException();
    final group = (sourceGroup != null && sourceGroup.isNotEmpty) ? sourceGroup : 'tg_$sourceId';
    final batch = _db.batch()
      ..update(_questions.doc(sourceId), {'translation_group_id': group})
      ..update(_questions.doc(targetId), {'translation_group_id': group});
    await batch.commit();
    return group;
  }

  Future<void> unlink(String questionId) =>
      _questions.doc(questionId).update({'translation_group_id': null});

  // --- Passages -------------------------------------------------------------

  Future<List<ExamPassageDoc>> passages({String? sectionId, String? language}) async {
    Query<Map<String, dynamic>> q = _passages;
    if (sectionId != null) q = q.where('section_id', isEqualTo: sectionId);
    if (language != null) q = q.where('language', isEqualTo: language);
    final snap = await q.limit(100).get();
    return [for (final d in snap.docs) ExamPassageDoc.fromMap(d.id, d.data())];
  }

  Future<ExamPassageDoc?> passage(String id) async {
    final d = await _passages.doc(id).get();
    final data = d.data();
    return data == null ? null : ExamPassageDoc.fromMap(d.id, data);
  }

  Future<void> savePassage(ExamPassageDoc p, {required String actor}) =>
      _passages.doc(p.id).set({
        ...p.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': actor,
        kEditedInCmsAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // --- Variant support ------------------------------------------------------

  /// Loads what the variant validator needs for [ids] (`whereIn` chunks of 30).
  Future<Map<String, VariantQuestionInfo>> infos(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    final out = <String, VariantQuestionInfo>{};
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, i + 30 > unique.length ? unique.length : i + 30);
      final r = await Future.wait([
        _questions.where(FieldPath.documentId, whereIn: chunk).get(),
        _keys.where(FieldPath.documentId, whereIn: chunk).get(),
      ]);
      final keys = {for (final d in r[1].docs) d.id: ExamKeyDoc.fromMap(d.data())};
      for (final d in r[0].docs) {
        final q = ExamQuestionDoc.fromMap(d.id, d.data());
        out[d.id] = VariantQuestionInfo(
          id: d.id,
          sectionId: q.sectionId,
          partId: q.partId,
          language: q.language,
          type: q.type,
          optionCount: q.options.length,
          reviewStatus: q.review.status,
          hasKey: keys[d.id]?.hasCorrect ?? false,
          passageId: q.passageId,
        );
      }
    }
    return out;
  }

  /// Approved questions for auto-filling a variant section/part.
  Future<List<String>> approvedIds({
    required String sectionId,
    required String language,
    String? partId,
    int limit = 200,
  }) async {
    var q = _questions
        .where('section_id', isEqualTo: sectionId)
        .where('language', isEqualTo: language)
        .where('review.status', isEqualTo: ReviewStatus.methodologistApproved.wire);
    if (partId != null) q = q.where('part_id', isEqualTo: partId);
    final snap = await q.limit(limit).get();
    return [for (final d in snap.docs) d.id];
  }

  /// Saves AI drafts as `review.status == draft` questions + keys (2 writes
  /// per draft, a fresh batch per 200 drafts).
  Future<List<String>> saveDrafts(List<AiDraft> drafts, {required String actor}) async {
    final ids = <String>[];
    for (var i = 0; i < drafts.length; i += 200) {
      final batch = _db.batch();
      for (final d in drafts.skip(i).take(200)) {
        final q = d.question;
        batch.set(_questions.doc(q.id), {
          ...q.toContentFields(),
          kEditedInCmsAtField: FieldValue.serverTimestamp(),
          'review': {
            'status': ReviewStatus.draft.wire,
            'reviewed_by': null,
            'reviewed_at': null,
            'notes': '',
          },
          'created_at': FieldValue.serverTimestamp(),
          'created_by': actor,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': actor,
        });
        batch.set(_keys.doc(q.id), {
          ...d.key.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': actor,
          kEditedInCmsAtField: FieldValue.serverTimestamp(),
        });
        ids.add(q.id);
      }
      await batch.commit();
    }
    return ids;
  }
}

class MissingKeyException implements Exception {
  const MissingKeyException();
}

class QuestionNotFoundException implements Exception {
  const QuestionNotFoundException();
}

class VariantPublishedException implements Exception {
  const VariantPublishedException();
}

typedef VariantFilter = ({String? blueprintId, String? status});

/// `exam_variants/{id}` drafts. Publishing goes only through the
/// `adminPublishVariant` callable; the client never writes `published`.
class VariantsRepository {
  VariantsRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.examVariants);

  String newId() => _col.doc().id;

  Future<AdminPage<VariantDoc>> page(
    VariantFilter f, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) {
    Query<Map<String, dynamic>> q = _col;
    if (f.blueprintId != null) q = q.where('blueprint_id', isEqualTo: f.blueprintId);
    if (f.status != null) q = q.where('status', isEqualTo: f.status);
    return fetchPage(q, after: after, pageSize: pageSize, map: VariantDoc.fromSnapshot);
  }

  Future<VariantDoc?> get(String id) async {
    final d = await _col.doc(id).get();
    return d.exists ? VariantDoc.fromSnapshot(d) : null;
  }

  Future<int> countFor(String blueprintId, String language) async =>
      (await _col
                  .where('blueprint_id', isEqualTo: blueprintId)
                  .where('language', isEqualTo: language)
                  .count()
                  .get())
              .count ??
          0;

  /// Saves a draft / in-review variant. Refuses published variants: they must
  /// be unpublished first so students never see a half-edited variant.
  Future<void> save(VariantDoc v, {required bool isNew, required String actor}) async {
    if (!isNew) {
      final current = await get(v.id);
      if (current != null && current.isPublished) throw const VariantPublishedException();
    }
    final status = v.status == 'published' ? 'draft' : v.status;
    final fields = <String, dynamic>{
      'blueprint_id': v.blueprintId,
      'blueprint_version': v.blueprintVersion,
      'number': v.number,
      'title': v.title,
      'language': v.language,
      'status': status,
      'sections': [
        for (final s in v.sections) {'section_id': s.sectionId, 'question_ids': s.questionIds},
      ],
      'content_version': isNew ? 1 : v.contentVersion + 1,
      'difficulty_label': v.difficultyLabel,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': actor,
    };
    if (isNew) {
      fields
        ..['created_by'] = actor
        ..['created_at'] = FieldValue.serverTimestamp()
        ..['stats'] = {'attempts': 0, 'avg_percent': 0};
      await _col.doc(v.id).set(fields);
    } else {
      await _col.doc(v.id).update(fields);
    }
  }
}

/// Blueprints from `exam_blueprints` with the bundled asset as fallback (same
/// format, ARCHITECTURE.md §1.1).
class BlueprintsRepository {
  BlueprintsRepository(this._db, {Future<String> Function()? loadAsset})
      : _loadAsset =
            loadAsset ?? (() => rootBundle.loadString('assets/data/exam_blueprints.json'));
  final FirebaseFirestore _db;
  final Future<String> Function() _loadAsset;

  Future<List<BlueprintSpec>> list() async {
    final byId = <String, BlueprintSpec>{};
    try {
      for (final b in BlueprintSpec.listFromJson(jsonDecode(await _loadAsset()))) {
        byId[b.id] = b;
      }
    } catch (_) {
      // Asset missing in a test harness — Firestore alone is fine.
    }
    try {
      final snap = await _db.collection(AdminCollections.examBlueprints).limit(100).get();
      for (final d in snap.docs) {
        byId[d.id] = BlueprintSpec.fromJson(d.data(), id: d.id);
      }
    } catch (_) {
      if (byId.isEmpty) rethrow;
    }
    final out = byId.values.where((b) => b.status != 'retired').toList()
      ..sort((a, b) {
        int rank(String k) => k == 'main' ? 0 : (k == 'subject' ? 1 : 2);
        final c = rank(a.kind).compareTo(rank(b.kind));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return out;
  }
}
