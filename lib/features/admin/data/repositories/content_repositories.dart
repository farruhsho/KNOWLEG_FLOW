import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/lesson_doc.dart';
import '../../domain/practice_question_codec.dart';
import '../admin_firebase.dart';
import '../json_safe.dart';
import '../models/subject_doc.dart';

/// A subject id that is already taken (create never overwrites).
class SubjectExistsException implements Exception {
  const SubjectExistsException();
}

/// Hard delete refused because content still references the subject (CMS-22).
class SubjectInUseException implements Exception {
  final SubjectUsage usage;
  const SubjectInUseException(this.usage);
}

class SubjectUsage {
  final int lessons;
  final int questions;
  final int examQuestions;
  const SubjectUsage(this.lessons, this.questions, this.examQuestions);
  bool get isEmpty => lessons == 0 && questions == 0 && examQuestions == 0;
}

Future<int> _count(Query<Map<String, dynamic>> q) async =>
    (await q.count().get()).count ?? 0;

/// `subjects/{id}` — the doc id IS the subject id (CMS-05/CMS-06).
class SubjectsRepository {
  SubjectsRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.subjects);

  /// Subjects are a small, bounded collection (one doc per ORT subject).
  Future<List<SubjectDoc>> list() async {
    final snap = await _col.limit(300).get();
    final out = snap.docs.map(SubjectDoc.fromSnapshot).toList()
      ..sort((a, b) {
        final c = a.order.compareTo(b.order);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return out;
  }

  Future<void> create(SubjectDoc s) async {
    final ref = _col.doc(s.id);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) throw const SubjectExistsException();
      tx.set(ref, s.toWrite(isNew: true));
    });
  }

  /// `update` replaces each written top-level field, so a translation removed
  /// in the editor is really removed, while unknown fields survive.
  Future<void> update(SubjectDoc s) => _col.doc(s.id).update(s.toWrite(isNew: false));

  Future<void> setActive(String id, bool active) => _col.doc(id).update({
        'isActive': active,
        'is_active': active,
        'updated_at': FieldValue.serverTimestamp(),
      });

  Future<SubjectUsage> usage(String id) async {
    final r = await Future.wait([
      _count(_db.collection(AdminCollections.lessons).where('subjectId', isEqualTo: id)),
      _count(_db.collection(AdminCollections.questions).where('subjectId', isEqualTo: id)),
      _count(_db.collection(AdminCollections.examQuestions).where('subject_id', isEqualTo: id)),
    ]);
    return SubjectUsage(r[0], r[1], r[2]);
  }

  /// Hard delete, only when nothing references the subject (CMS-22). The
  /// default action in the UI is deactivation (soft delete).
  Future<void> deleteIfUnused(String id) async {
    final u = await usage(id);
    if (!u.isEmpty) throw SubjectInUseException(u);
    await _col.doc(id).delete();
  }
}

/// `lessons/{id}` — the single lessons collection the student app reads.
class LessonsRepository {
  LessonsRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.lessons);

  String newId() => _col.doc().id;

  /// Lessons of one subject (bounded: a subject has at most a few hundred
  /// lessons), sorted by `order`. Filtering on the legacy `subjectId` field is
  /// what the student app does, so the CMS sees exactly what students see.
  Future<List<LessonDoc>> bySubject(String subjectId) async {
    final snap = await _col.where('subjectId', isEqualTo: subjectId).limit(500).get();
    final out = [for (final d in snap.docs) LessonDoc.fromMap(d.id, d.data())]
      ..sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  Future<LessonDoc?> get(String id) async {
    final doc = await _col.doc(id).get();
    final data = doc.data();
    return data == null ? null : LessonDoc.fromMap(doc.id, data);
  }

  Future<void> save(LessonDoc lesson, {required bool isNew, required String actor}) {
    final fields = lesson.toWrite(actor: actor)
      ..['updated_at'] = FieldValue.serverTimestamp()
      ..['updated_by'] = actor;
    if (isNew) {
      fields['created_at'] = FieldValue.serverTimestamp();
      return _col.doc(lesson.id).set(fields);
    }
    return _col.doc(lesson.id).update(fields);
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Filters for the legacy practice bank. Equality filters only, so no
/// composite index is needed (Firestore merges single-field indexes).
typedef PracticeFilter = ({String? subjectId, int? difficulty, String? type, bool? active});

/// Legacy practice bank `questions/{id}` (FB-13/CMS-18: one codec, snake_case
/// type values; FB-16/CMS-16: a fresh WriteBatch per 400 documents).
class PracticeQuestionsRepository {
  PracticeQuestionsRepository(this._db);
  final FirebaseFirestore _db;

  static const int batchSize = 400;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AdminCollections.questions);

  Query<Map<String, dynamic>> _query(PracticeFilter f) {
    Query<Map<String, dynamic>> q = _col;
    if (f.subjectId != null) q = q.where('subjectId', isEqualTo: f.subjectId);
    if (f.difficulty != null) q = q.where('difficulty', isEqualTo: f.difficulty);
    if (f.type != null) q = q.where('type', isEqualTo: f.type);
    if (f.active != null) q = q.where('is_active', isEqualTo: f.active);
    return q;
  }

  Future<AdminPage<PracticeQuestionDraft>> page(
    PracticeFilter f, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 25,
  }) =>
      fetchPage(
        _query(f),
        after: after,
        pageSize: pageSize,
        map: (d) => PracticeQuestionDraft.fromMap(d.data() ?? const {}, id: d.id),
      );

  Future<PracticeQuestionDraft?> get(String id) async {
    final d = await _col.doc(id).get();
    final data = d.data();
    return data == null ? null : PracticeQuestionDraft.fromMap(data, id: d.id);
  }

  Future<String> save(PracticeQuestionDraft q, {required String actor}) async {
    final fields = q.toFirestoreFields()
      ..['updated_at'] = FieldValue.serverTimestamp()
      ..['updated_by'] = actor;
    if (q.id == null || q.id!.isEmpty) {
      final ref = _col.doc();
      fields
        ..['created_at'] = FieldValue.serverTimestamp()
        ..['created_by'] = actor
        ..['is_ai_generated'] = false;
      await ref.set(fields);
      return ref.id;
    }
    // `update` keeps unknown fields (stats, embedding, video_url, ...) while
    // replacing each edited field as a whole.
    await _col.doc(q.id).update(fields);
    return q.id!;
  }

  Future<void> setActive(String id, bool active) => _col.doc(id).update({
        'is_active': active,
        'updated_at': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Imports validated drafts. Rows with an id are upserted (merge keeps
  /// statistics), rows without one get a new document.
  Future<int> import(
    List<PracticeQuestionDraft> drafts, {
    required String actor,
    void Function(int done, int total)? onProgress,
  }) async {
    var done = 0;
    for (final chunk in chunked(drafts, batchSize)) {
      final batch = _db.batch(); // fresh batch per chunk (FB-16)
      for (final q in chunk) {
        final fields = q.toFirestoreFields()
          ..['updated_at'] = FieldValue.serverTimestamp()
          ..['updated_by'] = actor;
        if (q.id != null && q.id!.isNotEmpty) {
          batch.set(_col.doc(q.id), fields, SetOptions(merge: true));
        } else {
          fields
            ..['created_at'] = FieldValue.serverTimestamp()
            ..['created_by'] = actor
            ..['source'] = q.source ?? 'import';
          batch.set(_col.doc(), fields);
        }
      }
      await batch.commit();
      done += chunk.length;
      onProgress?.call(done, drafts.length);
    }
    return done;
  }

  /// Export rows for the current filter, paginated (never a full scan in one
  /// read). Returns parsed drafts and JSON-safe raw documents (CMS-17).
  Future<({List<PracticeQuestionDraft> drafts, List<Map<String, dynamic>> raw})> export(
    PracticeFilter f, {
    int maxDocs = 5000,
  }) async {
    final drafts = <PracticeQuestionDraft>[];
    final raw = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (drafts.length < maxDocs) {
      var q = _query(f).limit(500);
      if (cursor != null) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final d in snap.docs) {
        drafts.add(PracticeQuestionDraft.fromMap(d.data(), id: d.id));
        raw.add({'id': d.id, ...(jsonSafe(d.data()) as Map<String, dynamic>)});
      }
      cursor = snap.docs.last;
      if (snap.docs.length < 500) break;
    }
    return (drafts: drafts, raw: raw);
  }
}

class MediaTooLargeException implements Exception {
  final int maxBytes;
  const MediaTooLargeException(this.maxBytes);
}

/// Storage uploads to `exam_media/{questionId}/` and `lesson_media/{lessonId}/`
/// (ARCHITECTURE.md §1: images ≤ 5 MB, PDF ≤ 20 MB).
class MediaRepository {
  MediaRepository(this._storage);
  final FirebaseStorage _storage;

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const int maxPdfBytes = 20 * 1024 * 1024;

  static String contentTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Uploads and returns the Storage path (stored in Firestore, not a URL).
  Future<String> upload({
    required String folder,
    required String ownerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final type = contentTypeFor(fileName);
    final max = type == 'application/pdf' ? maxPdfBytes : maxImageBytes;
    if (bytes.lengthInBytes > max) throw MediaTooLargeException(max);
    final path =
        '$folder/$ownerId/${DateTime.now().millisecondsSinceEpoch}_${_safeName(fileName)}';
    await _storage.ref(path).putData(bytes, SettableMetadata(contentType: type));
    return path;
  }

  Future<String> downloadUrl(String path) => _storage.ref(path).getDownloadURL();
}
