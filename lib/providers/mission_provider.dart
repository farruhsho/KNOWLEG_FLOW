import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/models/daily_mission_model.dart';
import '../shared/services/firebase_data_service.dart';

/// Provider for daily missions
final dailyMissionsProvider = FutureProvider.autoDispose<List<DailyMissionModel>>((ref) async {
  final dataService = FirebaseDataService();
  final missions = await dataService.getDailyMissions();
  // Convert dynamic list to DailyMissionModel list
  return missions.map((m) => DailyMissionModel.fromFirestore(m)).toList();
});

/// Provider for user mission progress
final userMissionProgressProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  final dataService = FirebaseDataService();
  return await dataService.getUserMissionProgress(userId);
});

/// Provider for updating mission progress
final missionProgressNotifierProvider = StateNotifierProvider<MissionProgressNotifier, AsyncValue<void>>((ref) {
  return MissionProgressNotifier();
});

class MissionProgressNotifier extends StateNotifier<AsyncValue<void>> {
  MissionProgressNotifier() : super(const AsyncValue.data(null));

  Future<void> updateProgress({
    required String userId,
    required String missionId,
    required int progress,
  }) async {
    state = const AsyncValue.loading();
    try {
      final dataService = FirebaseDataService();
      await dataService.updateMissionProgress(
        userId,
        missionId,
        progress,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
