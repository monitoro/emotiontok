import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';

class PostDetailScreen extends StatefulWidget {
  final PublicPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        DateFormat('yyyy-MM-dd HH:mm').format(widget.post.timestamp);
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('감정 상세')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.post.authorNickname,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(timeStr,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('분노 ${widget.post.angerLevel.toInt()}%',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.post.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(widget.post.imagePath!)
                        : Image.file(File(widget.post.imagePath!)),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(widget.post.content,
                    style: const TextStyle(fontSize: 18, height: 1.6)),
                const SizedBox(height: 32),
                // Interaction Buttons
                Consumer<VentingViewModel>(
                  builder: (context, ventingVM, child) {
                    return Row(
                      children: [
                        _DetailInteractionButton(
                          icon: Icons.fireplace,
                          label: '장작 넣기',
                          count: widget.post.supportCount,
                          itemCount: ventingVM.firewoodCount,
                          color: Colors.orange,
                          onTap: () => ventingVM.addFirewood(widget.post.id),
                        ),
                        const SizedBox(width: 12),
                        _DetailInteractionButton(
                          icon: Icons.water_drop,
                          label: '물 뿌리기',
                          count: widget.post.comfortCount,
                          itemCount: ventingVM.waterCount,
                          color: Colors.blue,
                          onTap: () => ventingVM.addWater(widget.post.id),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                const Text('공감 댓글',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ...widget.post.comments.asMap().entries.map((entry) =>
                    _buildCommentTile(context, entry.value, entry.key)),
              ],
            ),
          ),
          _buildCommentInput(context, userVM),
        ],
      ),
    );
  }

  Widget _buildCommentTile(
      BuildContext context, PublicComment comment, int index) {
    final ventingVM = Provider.of<VentingViewModel>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(comment.nickname,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange)),
                  const SizedBox(width: 8),
                  Text(DateFormat('HH:mm').format(comment.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
              Row(
                children: [
                  _CommentInteraction(
                    icon: Icons.fireplace,
                    count: comment.supportCount,
                    color: Colors.orange,
                    onTap: () =>
                        ventingVM.addFirewoodToComment(widget.post.id, index),
                  ),
                  const SizedBox(width: 8),
                  _CommentInteraction(
                    icon: Icons.water_drop,
                    count: comment.comfortCount,
                    color: Colors.blue,
                    onTap: () =>
                        ventingVM.addWaterToComment(widget.post.id, index),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, UserViewModel userVM) {
    return Container(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16),
      decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(top: BorderSide(color: Colors.white12))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                  hintText: '따뜻한 위로를 건네주세요...', border: InputBorder.none),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFFF4D00)),
            onPressed: () {
              if (_commentController.text.isNotEmpty) {
                Provider.of<VentingViewModel>(context, listen: false)
                    .addComment(
                  widget.post.id,
                  userVM.nickname ?? '익명',
                  _commentController.text,
                );
                _commentController.clear();
                FocusScope.of(context).unfocus();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DetailInteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int itemCount;
  final Color color;
  final VoidCallback onTap;

  const _DetailInteractionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.itemCount,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text('$label $count',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('보유: $itemCount',
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _CommentInteraction extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CommentInteraction({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.7)),
          const SizedBox(width: 2),
          Text('$count',
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }
}
