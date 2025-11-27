import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_user_model.dart';

/// Users repository provider
final usersRepositoryProvider = Provider((ref) => UsersRepository());

/// Repository for managing users
class UsersRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  /// Get all users stream with filters
  Stream<List<AdminUserModel>> getUsersStream({
    bool? isPremium,
    bool? isBanned,
    String? searchQuery,
  }) {
    Query query = _firestore.collection(_collection);

    if (isPremium != null) {
      query = query.where('is_premium', isEqualTo: isPremium);
    }
    if (isBanned != null) {
      query = query.where('is_banned', isEqualTo: isBanned);
    }

    return query
        .orderBy('last_active', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      var users = snapshot.docs
          .map((doc) => AdminUserModel.fromFirestore(doc))
          .toList();

      // Client-side search filtering
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        users = users.where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        }).toList();
      }

      return users;
    });
  }

  /// Get single user
  Future<AdminUserModel?> getUser(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return AdminUserModel.fromFirestore(doc);
  }

  /// Update user premium status
  Future<void> updatePremiumStatus(String userId, bool isPremium) async {
    await _firestore.collection(_collection).doc(userId).update({
      'is_premium': isPremium,
      'updated_at': Timestamp.now(),
    });
  }

  /// Ban/unban user
  Future<void> updateBanStatus(String userId, bool isBanned) async {
    await _firestore.collection(_collection).doc(userId).update({
      'is_banned': isBanned,
      'updated_at': Timestamp.now(),
    });
  }

  /// Update user roles
  Future<void> updateUserRoles(String userId, List<String> roles) async {
    await _firestore.collection(_collection).doc(userId).update({
      'roles': roles,
      'updated_at': Timestamp.now(),
    });
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection(_collection).doc(userId).delete();
  }

  /// Bulk ban users
  Future<void> bulkBanUsers(List<String> userIds, bool isBanned) async {
    final batch = _firestore.batch();
    for (final id in userIds) {
      batch.update(
        _firestore.collection(_collection).doc(id),
        {
          'is_banned': isBanned,
          'updated_at': Timestamp.now(),
        },
      );
    }
    await batch.commit();
  }

  /// Bulk update premium
  Future<void> bulkUpdatePremium(List<String> userIds, bool isPremium) async {
    final batch = _firestore.batch();
    for (final id in userIds) {
      batch.update(
        _firestore.collection(_collection).doc(id),
        {
          'is_premium': isPremium,
          'updated_at': Timestamp.now(),
        },
      );
    }
    await batch.commit();
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final snapshot = await _firestore.collection(_collection).get();
    
    int totalUsers = snapshot.docs.length;
    int premiumUsers = 0;
    int bannedUsers = 0;
    int activeToday = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['is_premium'] == true) premiumUsers++;
      if (data['is_banned'] == true) bannedUsers++;
      
      final lastActive = (data['last_active'] as Timestamp?)?.toDate();
      if (lastActive != null && lastActive.isAfter(today)) {
        activeToday++;
      }
    }

    return {
      'total_users': totalUsers,
      'premium_users': premiumUsers,
      'banned_users': bannedUsers,
      'active_today': activeToday,
      'free_users': totalUsers - premiumUsers,
    };
  }

  /// Search users
  Future<List<AdminUserModel>> searchUsers(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('last_active', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => AdminUserModel.fromFirestore(doc))
        .where((user) {
      final searchQuery = query.toLowerCase();
      return user.name.toLowerCase().contains(searchQuery) ||
          user.email.toLowerCase().contains(searchQuery);
    }).toList();
  }
}

/// Users list provider with filters
final usersProvider = StreamProvider.family<List<AdminUserModel>, UsersFilter>(
  (ref, filter) {
    final repository = ref.watch(usersRepositoryProvider);
    return repository.getUsersStream(
      isPremium: filter.isPremium,
      isBanned: filter.isBanned,
      searchQuery: filter.searchQuery,
    );
  },
);

/// Users filter model
class UsersFilter {
  final bool? isPremium;
  final bool? isBanned;
  final String? searchQuery;

  const UsersFilter({
    this.isPremium,
    this.isBanned,
    this.searchQuery,
  });

  UsersFilter copyWith({
    bool? isPremium,
    bool? isBanned,
    String? searchQuery,
  }) {
    return UsersFilter(
      isPremium: isPremium ?? this.isPremium,
      isBanned: isBanned ?? this.isBanned,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
