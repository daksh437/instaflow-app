/// Instagram Graph API (Business) response models.

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class IgProfile {
  final String id;
  final String username;
  final String? profilePictureUrl;
  final int followersCount;
  final int followsCount;
  final int mediaCount;

  const IgProfile({
    required this.id,
    required this.username,
    this.profilePictureUrl,
    this.followersCount = 0,
    this.followsCount = 0,
    this.mediaCount = 0,
  });

  factory IgProfile.fromJson(Map<String, dynamic> json) {
    return IgProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePictureUrl: json['profile_picture_url']?.toString(),
      followersCount: _parseInt(json['followers_count']),
      followsCount: _parseInt(json['follows_count']),
      mediaCount: _parseInt(json['media_count']),
    );
  }
}

class IgMedia {
  final String id;
  final String? caption;
  final String? mediaType;
  final String? mediaUrl;
  final String? timestamp;
  final int likeCount;
  final int commentsCount;

  const IgMedia({
    required this.id,
    this.caption,
    this.mediaType,
    this.mediaUrl,
    this.timestamp,
    this.likeCount = 0,
    this.commentsCount = 0,
  });

  factory IgMedia.fromJson(Map<String, dynamic> json) {
    return IgMedia(
      id: json['id']?.toString() ?? '',
      caption: json['caption']?.toString(),
      mediaType: json['media_type']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      timestamp: json['timestamp']?.toString(),
      likeCount: _parseInt(json['like_count']),
      commentsCount: _parseInt(json['comments_count']),
    );
  }
}

class IgInsightValue {
  final String endTime;
  final String value;

  const IgInsightValue({required this.endTime, required this.value});

  factory IgInsightValue.fromJson(Map<String, dynamic> json) {
    return IgInsightValue(
      endTime: json['end_time']?.toString() ?? '',
      value: json['value']?.toString() ?? '0',
    );
  }
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

  factory IgInsights.fromMetrics(List<dynamic>? data) {
    int reach = 0, impressions = 0, profileViews = 0;
    if (data == null) return const IgInsights();
    for (final item in data) {
      final map = item is Map<String, dynamic> ? item : <String, dynamic>{};
      final name = map['name']?.toString() ?? '';
      final values = map['values'] as List<dynamic>?;
      int total = 0;
      if (values != null && values.isNotEmpty) {
        final first = values.first;
        if (first is Map<String, dynamic>) {
          total = int.tryParse(first['value']?.toString() ?? '') ?? 0;
        }
      }
      if (name == 'reach') reach = total;
      if (name == 'impressions') impressions = total;
      if (name == 'profile_views') profileViews = total;
    }
    return IgInsights(reach: reach, impressions: impressions, profileViews: profileViews);
  }
}

class IgComment {
  final String id;
  final String? text;
  final String? username;
  final String? timestamp;

  const IgComment({
    required this.id,
    this.text,
    this.username,
    this.timestamp,
  });

  factory IgComment.fromJson(Map<String, dynamic> json) {
    return IgComment(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString(),
      username: json['username']?.toString(),
      timestamp: json['timestamp']?.toString(),
    );
  }
}
