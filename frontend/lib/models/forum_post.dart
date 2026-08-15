// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)

class ForumPost {
  final String postId;
  final String? parentPostId;
  final String? title;
  final String body;
  final String displayName; // pseudonym, never the real username
  final String avatarSeed;
  final DateTime createdAt;

  ForumPost({
    required this.postId,
    this.parentPostId,
    this.title,
    required this.body,
    required this.displayName,
    required this.avatarSeed,
    required this.createdAt,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      postId: json['post_id'] as String,
      parentPostId: json['parent_post_id'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String,
      displayName: json['display_name'] as String,
      avatarSeed: json['avatar_seed'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
