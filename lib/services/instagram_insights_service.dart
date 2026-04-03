/// Placeholder service for fetching Instagram Business profile and insights.
/// Isolated from rest of app.
///
/// TODO: Insert Facebook App ID, Client Token, App Secret; wire Instagram Graph API (Insights).
/// TODO: Use InstagramAuthService.getAccessToken(); get IG Business Account ID from me/accounts then call profile/insights.

class IgProfileMock {
  final String id;
  final String username;
  final String? profilePictureUrl;
  final int followersCount;
  final int followsCount;
  final int mediaCount;

  const IgProfileMock({
    required this.id,
    required this.username,
    this.profilePictureUrl,
    this.followersCount = 0,
    this.followsCount = 0,
    this.mediaCount = 0,
  });
}

class IgInsightsMock {
  final int reach;
  final int impressions;
  final int profileViews;

  const IgInsightsMock({
    this.reach = 0,
    this.impressions = 0,
    this.profileViews = 0,
  });
}

class InstagramInsightsService {
  InstagramInsightsService._();
  static final InstagramInsightsService _instance = InstagramInsightsService._();
  static InstagramInsightsService get instance => _instance;

  /// Fetch Instagram Business profile.
  /// TODO: GET graph.facebook.com/v21.0/{ig-user-id}?fields=followers_count,follows_count,media_count,username,profile_picture_url
  Future<IgProfileMock?> fetchProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const IgProfileMock(
      id: 'mock_ig_user_id',
      username: 'mock_business_account',
      profilePictureUrl: null,
      followersCount: 12500,
      followsCount: 320,
      mediaCount: 84,
    );
  }

  /// Fetch insights (reach, impressions, profile_views).
  /// TODO: GET graph.facebook.com/v21.0/{ig-user-id}/insights?metric=impressions,reach,profile_views&period=day
  Future<IgInsightsMock?> fetchInsights() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const IgInsightsMock(
      reach: 8200,
      impressions: 15200,
      profileViews: 1100,
    );
  }
}
