import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_contract.dart';
import '../../../core/network/firebase_service.dart';
import '../domain/achievement_config.dart';

/// Live `config/achievements`. Emits the built-in defaults first and keeps
/// them when the document is missing, unreadable or offline.
final achievementConfigProvider = StreamProvider<AchievementConfig>((ref) async* {
  yield AchievementConfig.empty;
  try {
    await for (final snap in FirebaseService.firestore
        .collection(Collections.config)
        .doc('achievements')
        .snapshots()) {
      yield AchievementConfig.fromMap(snap.data());
    }
  } catch (_) {
    // Permission denied / offline / Firebase unavailable: built-in copy.
  }
});
