import 'package:cloud_firestore/cloud_firestore.dart';

/// Subject model for admin panel
class SubjectModel {
  final String id;
  final Map<String, String> title; // {'ru': '', 'ky': '', 'en': ''}
  final Map<String, String> description;
  final String icon; // emoji или URL
  final String color; // HEX
  final int order;
  final bool isActive;
  final bool isPremium;
  final bool allowAiGeneration;
  final int totalLessons;
  final int totalQuestions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  SubjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.order,
    required this.isActive,
    required this.isPremium,
    required this.allowAiGeneration,
    this.totalLessons = 0,
    this.totalQuestions = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectModel(
      id: doc.id,
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      icon: data['icon'] ?? '📚',
      color: data['color'] ?? '#6366F1',
      order: data['order'] ?? 0,
      isActive: data['is_active'] ?? true,
      isPremium: data['is_premium'] ?? false,
      allowAiGeneration: data['allow_ai_generation'] ?? true,
      totalLessons: data['total_lessons'] ?? 0,
      totalQuestions: data['total_questions'] ?? 0,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      createdBy: data['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'order': order,
      'is_active': isActive,
      'is_premium': isPremium,
      'allow_ai_generation': allowAiGeneration,
      'total_lessons': totalLessons,
      'total_questions': totalQuestions,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'created_by': createdBy,
    };
  }

  SubjectModel copyWith({
    String? id,
    Map<String, String>? title,
    Map<String, String>? description,
    String? icon,
    String? color,
    int? order,
    bool? isActive,
    bool? isPremium,
    bool? allowAiGeneration,
    int? totalLessons,
    int? totalQuestions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      allowAiGeneration: allowAiGeneration ?? this.allowAiGeneration,
      totalLessons: totalLessons ?? this.totalLessons,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
