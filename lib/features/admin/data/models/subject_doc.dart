import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/localized_text.dart';

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

/// Topic of a subject, stored inline in `subjects/{id}.topics[]` so the
/// existing `subjects` rule covers it. Ids are dotted (`math.quadratic_equations`)
/// to match `exam_questions.topic_id`.
class TopicDoc {
  final String id;
  final Map<String, String> title;
  final int order;

  const TopicDoc({required this.id, required this.title, this.order = 0});

  factory TopicDoc.fromMap(Map raw) => TopicDoc(
        id: (raw['id'] ?? '').toString(),
        title: readLocalized(raw['title'] ?? raw['name']),
        order: _int(raw['order']),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'order': order};
}

/// Admin view of `subjects/{id}`.
///
/// CMS-06: the CMS reads every legacy shape (seeded camelCase docs with `name`
/// and ISO-string dates, the old admin snake_case docs) and writes the fields
/// the student `SubjectModel.fromFirestore` requires — `id`, `title`,
/// `description`, `icon`, `color`, `totalLessons`, `totalQuestions` — so a doc
/// saved here can never crash the student Subjects tab (CMS-21).
class SubjectDoc {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final String icon;
  final String color;
  final int order;
  final bool isActive;
  final int totalLessons;
  final int totalQuestions;
  final List<TopicDoc> topics;
  final Map<String, dynamic> raw;

  const SubjectDoc({
    required this.id,
    required this.title,
    required this.description,
    this.icon = 'book',
    this.color = '#4D6BEE',
    this.order = 0,
    this.isActive = true,
    this.totalLessons = 0,
    this.totalQuestions = 0,
    this.topics = const [],
    this.raw = const {},
  });

  factory SubjectDoc.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SubjectDoc.fromMap(doc.id, doc.data() ?? const {});

  factory SubjectDoc.fromMap(String id, Map<String, dynamic> d) {
    final topics = <TopicDoc>[];
    final rawTopics = d['topics'];
    if (rawTopics is List) {
      for (final t in rawTopics) {
        if (t is Map) topics.add(TopicDoc.fromMap(t));
      }
    }
    topics.sort((a, b) => a.order.compareTo(b.order));
    return SubjectDoc(
      id: id,
      title: readLocalized(d['title'] ?? d['name']),
      description: readLocalized(d['description']),
      icon: (d['icon'] is String && (d['icon'] as String).isNotEmpty)
          ? d['icon'] as String
          : 'book',
      color: (d['color'] is String && (d['color'] as String).isNotEmpty)
          ? d['color'] as String
          : '#4D6BEE',
      order: _int(d['order']),
      isActive: (d['isActive'] ?? d['is_active'] ?? true) == true,
      totalLessons: _int(d['totalLessons'] ?? d['total_lessons']),
      totalQuestions: _int(d['totalQuestions'] ?? d['total_questions']),
      topics: topics,
      raw: d,
    );
  }

  SubjectDoc copyWith({
    Map<String, String>? title,
    Map<String, String>? description,
    String? icon,
    String? color,
    int? order,
    bool? isActive,
    List<TopicDoc>? topics,
  }) =>
      SubjectDoc(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        order: order ?? this.order,
        isActive: isActive ?? this.isActive,
        totalLessons: totalLessons,
        totalQuestions: totalQuestions,
        topics: topics ?? this.topics,
        raw: raw,
      );

  /// Fields written on save (merged into the existing document so unknown
  /// fields survive).
  Map<String, dynamic> toWrite({required bool isNew}) => {
        'id': id,
        'title': title,
        // Keep the legacy `name` mirror in sync where it exists.
        if (raw.containsKey('name')) 'name': title,
        'description': description,
        'icon': icon,
        'color': color,
        'order': order,
        'isActive': isActive,
        'is_active': isActive,
        'totalLessons': totalLessons,
        'totalQuestions': totalQuestions,
        'topics': [for (final t in topics) t.toMap()],
        'updated_at': FieldValue.serverTimestamp(),
        if (isNew) 'created_at': FieldValue.serverTimestamp(),
      };

  static final RegExp idPattern = RegExp(r'^[a-z][a-z0-9_]{1,40}$');
  static final RegExp topicSuffixPattern = RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)*$');
}
