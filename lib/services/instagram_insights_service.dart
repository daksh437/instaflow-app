import 'instagram_service.dart';

class IgProfile {
  final String id;
  final String username;
  final int followersCount;
  final int followsCount;
  final int mediaCount;
  final String accountType;

  const IgProfile({
    required this.id,
    required this.username,
    this.followersCount = 0,
    this.followsCount = 0,
    this.mediaCount = 0,
    this.accountType = '',
  });
}

class IgInsights {
  final int reach;
  final int impressions;
  final int profileViews;

  const IgInsights({
    this.reach = 0,
    this.impressions = 0,
    this.profileViews = 0,
  });
}

class InstagramInsightsService {
  InstagramInsightsService._();
  static final InstagramInsightsService _instance = InstagramInsightsService._();
  static InstagramInsightsService get instance => _instance;
  final InstagramService _instagramService = InstagramService();

  Future<IgProfile?> fetchProfile() async {
    final profile = await _instagramService.getUserProfile('');
    return IgProfile(
      id: profile['id']?.toString() ?? '',
      username: profile['username']?.toString() ?? '',
      followersCount: (profile['followers_count'] as num?)?.toInt() ?? 0,
      followsCount: (profile['follows_count'] as num?)?.toInt() ?? 0,
      mediaCount: (profile['media_count'] as num?)?.toInt() ?? 0,
      accountType: profile['account_type']?.toString() ?? '',
    );
  }

  Future<IgInsights?> fetchInsights() async {
    final profile = await fetchProfile();
    if (profile == null) return null;
    return const IgInsights(
      reach: 0,
      impressions: 0,
      profileViews: 0,
    );
  }
}
