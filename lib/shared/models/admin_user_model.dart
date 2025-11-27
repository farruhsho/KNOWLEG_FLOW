import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin role types
enum AdminRole {
  superAdmin,
  admin,
  moderator,
}

/// Admin user model with role-based permissions
class AdminUser {
  final String uid;
  final String email;
  final String name;
  final AdminRole role;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  const AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: _parseRole(data['role'] ?? 'admin'),
      permissions: List<String>.from(data['permissions'] ?? []),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['last_login'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'permissions': permissions,
      'created_at': Timestamp.fromDate(createdAt),
      'last_login': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'is_active': isActive,
    };
  }

  static AdminRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'superadmin':
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'moderator':
        return AdminRole.moderator;
      default:
        return AdminRole.admin;
    }
  }

  bool hasPermission(String permission) {
    // Super admins have all permissions
    if (role == AdminRole.superAdmin) return true;
    
    return permissions.contains(permission);
  }

  bool canManageUsers() => hasPermission('manage_users') || role == AdminRole.superAdmin;
  bool canManageQuestions() => hasPermission('manage_questions') || role == AdminRole.superAdmin;
  bool canManageMissions() => hasPermission('manage_missions') || role == AdminRole.superAdmin;
  bool canManageLessons() => hasPermission('manage_lessons') || role == AdminRole.superAdmin;
  bool canUseAIGenerator() => hasPermission('use_ai_generator') || role == AdminRole.superAdmin;
  bool canViewAnalytics() => hasPermission('view_analytics') || role == AdminRole.superAdmin;

  AdminUser copyWith({
    String? uid,
    String? email,
    String? name,
    AdminRole? role,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return AdminUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Default permissions for each role
class AdminPermissions {
  static const List<String> superAdminPermissions = [
    'manage_users',
    'manage_questions',
    'manage_missions',
    'manage_lessons',
    'manage_subjects',
    'use_ai_generator',
    'view_analytics',
    'manage_admins',
    'delete_content',
  ];

  static const List<String> adminPermissions = [
    'manage_questions',
    'manage_missions',
    'manage_lessons',
    'manage_subjects',
    'use_ai_generator',
    'view_analytics',
  ];

  static const List<String> moderatorPermissions = [
    'manage_questions',
    'manage_missions',
    'manage_lessons',
  ];

  static List<String> getDefaultPermissions(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return superAdminPermissions;
      case AdminRole.admin:
        return adminPermissions;
      case AdminRole.moderator:
        return moderatorPermissions;
    }
  }
}
