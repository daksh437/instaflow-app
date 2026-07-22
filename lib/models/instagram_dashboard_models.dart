/// Display models for Instagram analytics dashboard (API + derived estimates where noted).
class InstagramTopPostDisplay {
  const InstagramTopPostDisplay({
    this.thumbnailUrl,
    required this.likes,
    required this.comments,
    required this.label,
  });

  final String? thumbnailUrl;
  final int likes;
  final int comments;
  final String label;
}
