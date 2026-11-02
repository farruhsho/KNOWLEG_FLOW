import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/exam_attempt.dart';
import '../domain/exam_blueprint.dart';
import '../domain/exam_failure.dart';
import '../domain/exam_variant.dart';
import '../domain/json_utils.dart';

/// Bundled offline copy of the blueprints (same format as Firestore).
const String examBlueprintsAsset = 'assets/data/exam_blueprints.json';

@immutable
class VariantPage {
  final List<ExamVariant> items;
  final bool hasMore;

  const VariantPage({required this.items, required this.hasMore});
}

@immutable
class AttemptPage {
  final List<AttemptSummary> items;

  /// Opaque pagination cursor for the next page.
  final Object? cursor;
  final bool hasMore;

  const AttemptPage({required this.items, this.cursor, required this.hasMore});
}

/// Read-only access to exam catalog data (blueprints, variants, attempts).
abstract interface class ExamCatalogRepository {
  /// Active blueprints from Firestore; falls back to the bundled asset when
  /// Firestore is unreachable or has none.
  Future<List<ExamBlueprint>> loadBlueprints();

  /// A blueprint by id (also retired ones, for old attempts).
  Future<ExamBlueprint?> loadBlueprint(String id);

  /// Published variants of [blueprintId] in [language], ordered by number.
  Future<VariantPage> loadVariants({
    required String blueprintId,
    required String language,
    int? afterNumber,
    int limit = 20,
  });

  Future<ExamVariant?> loadVariant(String variantId);

  /// Live list of the user's attempts (most recent first is not guaranteed).
  Stream<List<AttemptSummary>> watchMyAttempts(String uid);

  /// Completed attempts, newest first.
  Future<AttemptPage> loadHistory(String uid, {Object? cursor, int limit = 20});

  Future<AttemptSummary?> loadAttempt(String attemptId);
}

/// Parses the bundled blueprint asset.
Future<List<ExamBlueprint>> loadBlueprintsFromAsset(AssetBundle bundle) async {
  final raw = await bundle.loadString(examBlueprintsAsset);
  return ExamBlueprint.listFromJson(jsonDecode(raw));
}

/// Converts Firestore values (Timestamp, references) into JSON-safe values so
/// the domain parsers never see platform types.
Object? firestoreToJson(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is DocumentReference) return value.path;
  if (value is GeoPoint) {
    return {'latitude': value.latitude, 'longitude': value.longitude};
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), firestoreToJson(v)));
  }
  if (value is List) return value.map(firestoreToJson).toList();
  return value;
}

class FirestoreExamCatalogRepository implements ExamCatalogRepository {
  final FirebaseFirestore _db;
  final AssetBundle _bundle;

  FirestoreExamCatalogRepository(this._db, this._bundle);

  List<ExamBlueprint>? _assetCache;

  Future<List<ExamBlueprint>> _asset() async =>
      _assetCache ??= await loadBlueprintsFromAsset(_bundle);

  Map<String, dynamic> _json(Map<String, dynamic>? data) =>
      asJsonMap(firestoreToJson(data));

  @override
  Future<List<ExamBlueprint>> loadBlueprints() async {
    try {
      final snap = await _db
          .collection(Collections.examBlueprints)
          .where('status', isEqualTo: 'active')
          .get()
          .timeout(const Duration(seconds: 12));
      final list = snap.docs
          .map((d) => ExamBlueprint.fromJson(_json(d.data()), id: d.id))
          .where((b) => b.sections.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return _sorted(list);
    } catch (e) {
      debugPrint('exam: blueprints from Firestore failed, using asset ($e)');
    }
    return _sorted(await _asset());
  }

  List<ExamBlueprint> _sorted(List<ExamBlueprint> list) {
    int rank(BlueprintKind k) => switch (k) {
          BlueprintKind.main => 0,
          BlueprintKind.subject => 1,
          BlueprintKind.stateLanguage => 2,
          BlueprintKind.unknown => 3,
        };
    final copy = [...list]
      ..sort((a, b) {
        final r = rank(a.kind).compareTo(rank(b.kind));
        if (r != 0) return r;
        final y = b.examYear.compareTo(a.examYear);
        return y != 0 ? y : a.id.compareTo(b.id);
      });
    return List.unmodifiable(copy);
  }

  @override
  Future<ExamBlueprint?> loadBlueprint(String id) async {
    try {
      final doc = await _db
          .collection(Collections.examBlueprints)
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 12));
      if (doc.exists) {
        final bp = ExamBlueprint.fromJson(_json(doc.data()), id: doc.id);
        if (bp.sections.isNotEmpty) return bp;
      }
    } catch (e) {
      debugPrint('exam: blueprint $id from Firestore failed ($e)');
    }
    for (final b in await _asset()) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<VariantPage> loadVariants({
    required String blueprintId,
    required String language,
    int? afterNumber,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> base() => _db
        .collection(Collections.examVariants)
        .where('blueprint_id', isEqualTo: blueprintId)
        .where('status', isEqualTo: 'published');

    try {
      var q = base().where('language', isEqualTo: language).orderBy('number');
      if (afterNumber != null) q = q.startAfter([afterNumber]);
      final snap = await q.limit(limit + 1).get();
      final items = snap.docs
          .map((d) => ExamVariant.fromJson(d.id, _json(d.data())))
          .toList();
      return VariantPage(
        items: List.unmodifiable(items.take(limit)),
        hasMore: items.length > limit,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') throw _map(e);
      // Composite index (blueprint_id, status, language, number) not deployed
      // yet: fall back to the smaller index and filter the language here.
      var q = base().orderBy('number');
      if (afterNumber != null) q = q.startAfter([afterNumber]);
      try {
        final snap = await q.limit(limit * 3).get();
        final all = snap.docs
            .map((d) => ExamVariant.fromJson(d.id, _json(d.data())))
            .toList();
        final items = all.where((v) => v.language == language).take(limit);
        return VariantPage(
          items: List.unmodifiable(items),
          hasMore: all.length >= limit * 3,
        );
      } on FirebaseException catch (e2) {
        throw _map(e2);
      }
    }
  }

  @override
  Future<ExamVariant?> loadVariant(String variantId) async {
    try {
      final doc =
          await _db.collection(Collections.examVariants).doc(variantId).get();
      if (!doc.exists) return null;
      return ExamVariant.fromJson(doc.id, _json(doc.data()));
    } on FirebaseException catch (e) {
      // Unpublished variants are not readable by students.
      if (e.code == 'permission-denied') return null;
      throw _map(e);
    }
  }

  @override
  Stream<List<AttemptSummary>> watchMyAttempts(String uid) => _db
      .collection(Collections.examAttempts)
      .where('uid', isEqualTo: uid)
      .limit(300)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AttemptSummary.fromJson(d.id, _json(d.data())))
          .toList(growable: false));

  @override
  Future<AttemptPage> loadHistory(String uid,
      {Object? cursor, int limit = 20}) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection(Collections.examAttempts)
          .where('uid', isEqualTo: uid)
          .orderBy('completed_at', descending: true);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.limit(limit).get();
      final items = snap.docs
          .map((d) => AttemptSummary.fromJson(d.id, _json(d.data())))
          // In-progress attempts carry `completed_at: null` and sort last.
          .where((a) => a.isCompleted)
          .toList(growable: false);
      return AttemptPage(
        items: items,
        cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
        hasMore: snap.docs.length == limit,
      );
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AttemptSummary?> loadAttempt(String attemptId) async {
    try {
      final doc =
          await _db.collection(Collections.examAttempts).doc(attemptId).get();
      if (!doc.exists) return null;
      return AttemptSummary.fromJson(doc.id, _json(doc.data()));
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  ExamFailure _map(FirebaseException e) => ExamFailure(
        switch (e.code) {
          'unavailable' || 'deadline-exceeded' => ExamFailureKind.network,
          'unauthenticated' => ExamFailureKind.unauthenticated,
          'not-found' => ExamFailureKind.attemptNotFound,
          _ => ExamFailureKind.unknown,
        },
        e.message,
      );
}
