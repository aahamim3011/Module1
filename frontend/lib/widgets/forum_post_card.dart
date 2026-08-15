// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)

import 'package:flutter/material.dart';
import '../models/forum_post.dart';
import 'pseudonym_avatar.dart';

class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onReport;
  final VoidCallback? onReply;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onReport,
    this.onReply,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showReportSheet(BuildContext context) {
    final reasons = ['harmful', 'triggering', 'harassment', 'spam', 'other'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why are you reporting this post?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...reasons.map((r) => ListTile(
                  title: Text(r[0].toUpperCase() + r.substring(1)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onReport();
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PseudonymAvatar(seed: post.avatarSeed),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(_timeAgo(post.createdAt),
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  tooltip: 'Report',
                  onPressed: () => _showReportSheet(context),
                ),
              ],
            ),
            if (post.title != null && post.title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.title!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
            const SizedBox(height: 6),
            Text(post.body),
            if (onReply != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
