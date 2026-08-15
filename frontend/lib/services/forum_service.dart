// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)
//
// Handles all HTTP calls to the /forum endpoints. Swap `baseUrl` and the
// auth-token retrieval for whatever the team's shared API client uses.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/forum_post.dart';

class ForumService {
  final String baseUrl;
  final String Function() getAuthToken; // injected from the auth module

  ForumService({required this.baseUrl, required this.getAuthToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${getAuthToken()}',
      };

  Future<List<ForumPost>> fetchFeed({int skip = 0, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/forum/posts?skip=$skip&limit=$limit');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to load forum feed (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ForumPost.fromJson(json)).toList();
  }

  Future<ForumPost> createPost({
    String? title,
    required String body,
    String? parentPostId,
  }) async {
    final uri = Uri.parse('$baseUrl/forum/posts');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'body': body,
        'parent_post_id': parentPostId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create post (${response.statusCode})');
    }
    return ForumPost.fromJson(jsonDecode(response.body));
  }

  Future<void> reportPost({
    required String postId,
    required String reason, // 'harmful' | 'triggering' | 'harassment' | 'spam' | 'other'
    String? details,
  }) async {
    final uri = Uri.parse('$baseUrl/forum/reports');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'post_id': postId,
        'reason': reason,
        'details': details,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to submit report (${response.statusCode})');
    }
  }
}
