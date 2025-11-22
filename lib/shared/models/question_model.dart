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
