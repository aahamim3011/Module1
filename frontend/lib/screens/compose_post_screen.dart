// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)

import 'package:flutter/material.dart';
import '../services/forum_service.dart';

class ComposePostScreen extends StatefulWidget {
  final ForumService forumService;
  final String? parentPostId; // set when replying

  const ComposePostScreen({
    super.key,
    required this.forumService,
    this.parentPostId,
  });

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something before posting')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final post = await widget.forumService.createPost(
        title: widget.parentPostId == null && _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        body: _bodyController.text.trim(),
        parentPostId: widget.parentPostId,
      );
      if (mounted) Navigator.pop(context, post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.parentPostId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isReply ? 'Reply' : 'Share with the community')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off_outlined, size: 18, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your identity stays hidden. You\'ll post under your forum pseudonym, and any personal details you type are automatically scrubbed.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isReply)
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            if (!isReply) const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 8,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isReply ? 'Post reply' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }
}
