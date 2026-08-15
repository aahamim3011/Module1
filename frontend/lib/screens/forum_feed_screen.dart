// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)

import 'package:flutter/material.dart';
import '../models/forum_post.dart';
import '../services/forum_service.dart';
import '../widgets/forum_post_card.dart';
import 'compose_post_screen.dart';

class ForumFeedScreen extends StatefulWidget {
  final ForumService forumService;

  const ForumFeedScreen({super.key, required this.forumService});

  @override
  State<ForumFeedScreen> createState() => _ForumFeedScreenState();
}

class _ForumFeedScreenState extends State<ForumFeedScreen> {
  final List<ForumPost> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFeed(refresh: true);
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newPosts = await widget.forumService.fetchFeed(
        skip: refresh ? 0 : _posts.length,
        limit: _pageSize,
      );
      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(newPosts);
        _hasMore = newPosts.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load forum: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportPost(ForumPost post) async {
    try {
      await widget.forumService.reportPost(postId: post.postId, reason: 'harmful');
      setState(() => _posts.removeWhere((p) => p.postId == post.postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post reported and hidden pending review')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit report: $e')),
        );
      }
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.push<ForumPost>(
      context,
      MaterialPageRoute(
        builder: (_) => ComposePostScreen(forumService: widget.forumService),
      ),
    );
    if (created != null) {
      setState(() => _posts.insert(0, created));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Forum')),
      body: RefreshIndicator(
        onRefresh: () => _loadFeed(refresh: true),
        child: _posts.isEmpty && !_isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No posts yet. Be the first to share.')),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (_hasMore &&
                      !_isLoading &&
                      scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                    _loadFeed();
                  }
                  return false;
                },
                child: ListView.builder(
                  itemCount: _posts.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final post = _posts[index];
                    return ForumPostCard(
                      post: post,
                      onReport: () => _reportPost(post),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Share'),
      ),
    );
  }
}
