import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/models/admin_user_model.dart';

/// Provider for current admin user
final adminUserProvider = StreamProvider<AdminUser?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('admins')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return AdminUser.fromFirestore(doc);
  });
});

/// Admin access control middleware
class AdminAccessControl {
  static Future<bool> isAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();
      
      if (!doc.exists) return false;
      
      final adminUser = AdminUser.fromFirestore(doc);
      return adminUser.isActive;
    } catch (e) {
      return false;
    }
  }

  static Future<AdminUser?> getAdminUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();
      
      if (!doc.exists) return null;
      
      return AdminUser.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> hasPermission(String uid, String permission) async {
    final adminUser = await getAdminUser(uid);
    if (adminUser == null) return false;
    
    return adminUser.hasPermission(permission);
  }

  static Future<void> updateLastLogin(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .update({
        'last_login': Timestamp.now(),
      });
    } catch (e) {
      // Silently fail - not critical
    }
  }
}

/// Widget to protect admin-only routes
class AdminGuard extends ConsumerWidget {
  final Widget child;
  final String? requiredPermission;
  final Widget? fallback;

  const AdminGuard({
    super.key,
    required this.child,
    this.requiredPermission,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminUserAsync = ref.watch(adminUserProvider);

    return adminUserAsync.when(
      data: (adminUser) {
        if (adminUser == null || !adminUser.isActive) {
          return fallback ?? _buildUnauthorized(context);
        }

        if (requiredPermission != null && !adminUser.hasPermission(requiredPermission!)) {
          return fallback ?? _buildUnauthorized(context);
        }

        return child;
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, error.toString()),
    );
  }

  Widget _buildUnauthorized(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Доступ запрещен',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'У вас нет прав для доступа к этой странице',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
