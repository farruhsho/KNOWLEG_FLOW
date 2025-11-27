import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class QuestionModel extends Equatable {
  final String id;
  final String subjectId;
  final String? lessonId;
  final String type; // 'mcq', 'tf', 'fill'
  final int difficulty; // 1-5
  final Map<String, String> stem; // Question text
  final List<OptionModel> options;
  final String correctAnswer; // e.g., 'A', 'B', 'C', 'D'
  final Map<String, String> explanation;
  final List<String> tags;
  final String? imageUrl;
  final String? videoUrl;
  final String createdBy;
  final DateTime createdAt;
  final String category; // 'main', 'subject', 'language' for ORT sections
  final List<double>? embedding; // Vector embedding for duplicate detection
  final String source; // 'ai', 'scraped', 'manual'

  const QuestionModel({
    required this.id,
    required this.subjectId,
    this.lessonId,
    required this.type,
    required this.difficulty,
    required this.stem,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.tags = const [],
    this.imageUrl,
    this.videoUrl,
    required this.createdBy,
    required this.createdAt,
    this.category = 'subject', // Default to subject category
    this.embedding,
    this.source = 'manual',
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      subjectId: data['subject_id'] ?? '',
      lessonId: data['lesson_id'],
      type: data['type'] ?? 'mcq',
      difficulty: data['difficulty'] ?? 1,
      stem: Map<String, String>.from(data['stem'] ?? {}),
      options: (data['options'] as List<dynamic>?)
              ?.map((e) => OptionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: data['correct'] ?? 'A',
      explanation: Map<String, String>.from(data['explanation'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['image_url'],
      videoUrl: data['video_url'],
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'subject',
      embedding: data['embedding'] != null 
          ? List<double>.from(data['embedding'] as List<dynamic>)
          : null,
      source: data['source'] ?? 'manual',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'lesson_id': lessonId,
      'type': type,
      'difficulty': difficulty,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correct': correctAnswer,
      'explanation': explanation,
      'tags': tags,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'category': category,
      'embedding': embedding,
      'source': source,
    };
  }
  
  // JSON serialization for export/import
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? json['subject_id'] ?? '',
      lessonId: json['lessonId'] ?? json['lesson_id'],
      type: json['type'] ?? 'mcq',
      difficulty: json['difficulty'] ?? 1,
      stem: Map<String, String>.from(json['stem'] ?? {}),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => OptionModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'] ?? json['correct'] ?? 'A',
      explanation: Map<String, String>.from(json['explanation'] ?? {}),
      tags: List<String>.from(json['tags'] ?? []),
      imageUrl: json['imageUrl'] ?? json['image_url'],
      videoUrl: json['videoUrl'] ?? json['video_url'],
      createdBy: json['createdBy'] ?? json['created_by'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      category: json['category'] ?? 'subject',
      embedding: json['embedding'] != null
          ? List<double>.from(json['embedding'] as List<dynamic>)
          : null,
      source: json['source'] ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'lessonId': lessonId,
      'type': type,
      'difficulty': difficulty,
      'stem': stem,
      'options': options.map((e) => e.toMap()).toList(),
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'tags': tags,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'embedding': embedding,
      'source': source,
    };
  }

  String getStem(String locale) {
    return stem[locale] ?? stem['en'] ?? stem['ru'] ?? '';
  }

  String getExplanation(String locale) {
    return explanation[locale] ?? explanation['en'] ?? explanation['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        lessonId,
        type,
        difficulty,
        stem,
        options,
        correctAnswer,
        explanation,
        tags,
        imageUrl,
        videoUrl,
        createdBy,
        createdAt,
        category,
        embedding,
        source,
      ];
}

class OptionModel extends Equatable {
  final String id; // 'A', 'B', 'C', 'D'
  final Map<String, String> text;

  const OptionModel({
    required this.id,
    required this.text,
  });

  factory OptionModel.fromMap(Map<String, dynamic> map) {
    return OptionModel(
      id: map['id'] ?? '',
      text: Map<String, String>.from(map['text'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }

  String getText(String locale) {
    return text[locale] ?? text['en'] ?? text['ru'] ?? '';
  }

  @override
  List<Object?> get props => [id, text];
}
