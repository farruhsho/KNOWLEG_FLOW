import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class LessonModel extends Equatable {
  final String id;
  final String subjectId;
  final Map<String, String> title;
  final Map<String, String> content; // Rich text content
  final List<String> mediaUrls;
  final int estimatedTimeMinutes;
  final List<String> tags;
  final int order;
  final String createdBy;
  final DateTime createdAt;

  const LessonModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.content,
    this.mediaUrls = const [],
    required this.estimatedTimeMinutes,
    this.tags = const [],
    this.order = 0,
    required this.createdBy,
    required this.createdAt,
  });

  factory LessonModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonModel(
      id: doc.id,
      subjectId: data['subject_id'] ?? '',
      title: Map<String, String>.from(data['title'] ?? {}),
      content: Map<String, String>.from(data['content'] ?? {}),
      mediaUrls: List<String>.from(data['media_urls'] ?? []),
      estimatedTimeMinutes: data['estimated_time'] ?? 15,
      tags: List<String>.from(data['tags'] ?? []),
      order: data['order'] ?? 0,
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'title': title,
      'content': content,
      'media_urls': mediaUrls,
      'estimated_time': estimatedTimeMinutes,
      'tags': tags,
      'order': order,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['en'] ?? title['ru'] ?? '';
  }

  String getContent(String locale) {
    return content[locale] ?? content['en'] ?? content['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        title,
        content,
        mediaUrls,
        estimatedTimeMinutes,
        tags,
        order,
        createdBy,
        createdAt,
      ];
}
