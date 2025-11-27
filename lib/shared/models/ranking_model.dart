
/// User ranking model for leaderboards
class UserRankingModel {
  final String userId;
  final String userName;
  final int rank;
  final int score;
  final String? region; // Oblast/City for regional rankings
  final String? avatarUrl;

  UserRankingModel({
    required this.userId,
    required this.userName,
    required this.rank,
    required this.score,
    this.region,
    this.avatarUrl,
  });

  factory UserRankingModel.fromFirestore(Map<String, dynamic> data, int rank) {
    return UserRankingModel(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Пользователь',
      rank: rank,
      score: data['averageScore'] ?? 0,
      region: data['region'],
      avatarUrl: data['avatarUrl'],
    );
  }
}

/// Subject-specific ranking
class SubjectRankingModel {
  final String subjectId;
  final String subjectName;
  final int rank;
  final int totalUsers;
  final double progress;
  final int score;

  SubjectRankingModel({
    required this.subjectId,
    required this.subjectName,
    required this.rank,
    required this.totalUsers,
    required this.progress,
    required this.score,
  });
}

/// Overall user ranking with additional stats
class OverallRankingModel {
  final int globalRank;
  final int totalUsers;
  final int regionalRank;
  final int regionalUsers;
  final String percentile; // Top X%
  final List<UserRankingModel> topUsers; // Top 10
  final List<UserRankingModel> nearbyUsers; // Users near current user

  OverallRankingModel({
    required this.globalRank,
    required this.totalUsers,
    required this.regionalRank,
    required this.regionalUsers,
    required this.percentile,
    required this.topUsers,
    required this.nearbyUsers,
  });
}
