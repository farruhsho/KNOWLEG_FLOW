import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for admin panel
class AdminUserModel {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final bool isPremium;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime lastActive;
  final Map<String, dynamic> stats;
  final List<String> roles;

  AdminUserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.isPremium = false,
    this.isBanned = false,
    required this.createdAt,
    required this.lastActive,
    this.stats = const {},
    this.roles = const ['user'],
  });

  factory AdminUserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photo_url'],
      isPremium: data['is_premium'] ?? false,
      isBanned: data['is_banned'] ?? false,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      lastActive: (data['last_active'] as Timestamp).toDate(),
      stats: Map<String, dynamic>.from(data['stats'] ?? {}),
      roles: List<String>.from(data['roles'] ?? ['user']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'photo_url': photoUrl,
      'is_premium': isPremium,
      'is_banned': isBanned,
      'created_at': Timestamp.fromDate(createdAt),
      'last_active': Timestamp.fromDate(lastActive),
      'stats': stats,
      'roles': roles,
    };
  }

  AdminUserModel copyWith({
    String? email,
    String? name,
    String? photoUrl,
    bool? isPremium,
    bool? isBanned,
    DateTime? createdAt,
    DateTime? lastActive,
    Map<String, dynamic>? stats,
    List<String>? roles,
  }) {
    return AdminUserModel(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      stats: stats ?? this.stats,
      roles: roles ?? this.roles,
    );
  }

  // Helper getters
  int get totalTests => stats['total_tests'] ?? 0;
  int get completedTests => stats['completed_tests'] ?? 0;
  double get averageScore => (stats['average_score'] ?? 0.0).toDouble();
  int get totalQuestions => stats['total_questions'] ?? 0;
  int get correctAnswers => stats['correct_answers'] ?? 0;
  
  double get accuracy {
    if (totalQuestions == 0) return 0.0;
    return (correctAnswers / totalQuestions) * 100;
  }

  String get statusLabel {
    if (isBanned) return 'Заблокирован';
    if (isPremium) return 'Premium';
    return 'Активен';
  }
}
