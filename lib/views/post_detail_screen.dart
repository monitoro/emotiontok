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
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyToCommentId; // Changed from int index to String UUID
  String? _replyToNickname;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _enableReplyMode(String commentId, String nickname) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToNickname = nickname;
    });
    // Request focus and slight delay to ensure keyboard comes up
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_commentFocusNode);
    });
  }

  void _cancelReplyMode() {
    setState(() {
      _replyToCommentId = null;
      _replyToNickname = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Find the latest version of the post from ViewModel
    final ventingVM = Provider.of<VentingViewModel>(context);
    PublicPost displayPost;
    try {
      displayPost = ventingVM.publicPosts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );
    } catch (e) {
      displayPost = widget.post;
    }

    final timeStr =
        DateFormat('yyyy-MM-dd HH:mm').format(displayPost.timestamp);
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: PublicPost.getLevelColor(
                                    displayPost.authorLevel)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: PublicPost.getLevelColor(
                                    displayPost.authorLevel),
                                width: 0.5),
                          ),
                          child: Text(
                            'Lv.${displayPost.authorLevel}',
                            style: TextStyle(
                              color: PublicPost.getLevelColor(
                                  displayPost.authorLevel),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(displayPost.authorNickname,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: PublicPost.getLevelColor(
                                    displayPost.authorLevel))),
                      ],
                    ),
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
                    child: Text('분노 ${displayPost.angerLevel.toInt()}%',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                if (displayPost.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(displayPost.imagePath!)
                        : Image.file(File(displayPost.imagePath!)),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(displayPost.content,
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
                          count: displayPost.supportCount,
                          itemCount: ventingVM.firewoodCount,
                          color: Colors.orange,
                          onTap: () => ventingVM.addFirewood(displayPost.id),
                        ),
                        const SizedBox(width: 12),
                        _DetailInteractionButton(
                          icon: Icons.water_drop,
                          label: '물 뿌리기',
                          count: displayPost.comfortCount,
                          itemCount: ventingVM.waterCount,
                          color: Colors.blue,
                          onTap: () => ventingVM.addWater(displayPost.id),
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
                ...displayPost.comments.map((comment) =>
                    _buildCommentTree(context, comment, displayPost)),
              ],
            ),
          ),
          _buildCommentInput(context, userVM, displayPost),
        ],
      ),
    );
  }

  // Recursive builder for comment tree
  Widget _buildCommentTree(
      BuildContext context, PublicComment comment, PublicPost post,
      {int depth = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0), // Indent based on depth
          child:
              _buildSingleComment(context, comment, post, isReply: depth > 0),
        ),
        // Recursive Call for replies
        if (comment.replies.isNotEmpty)
          ...comment.replies.map((reply) =>
              _buildCommentTree(context, reply, post, depth: depth + 1)),
      ],
    );
  }

  Widget _buildSingleComment(
      BuildContext context, PublicComment comment, PublicPost post,
      {required bool isReply}) {
    final ventingVM = Provider.of<VentingViewModel>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isReply)
                  const Icon(Icons.subdirectory_arrow_right,
                      size: 16, color: Colors.grey),
                if (isReply) const SizedBox(width: 4),
                Text(comment.nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange)),
                const SizedBox(width: 8),
                Text(DateFormat('HH:mm').format(comment.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
                if (comment.authorId == post.authorId) ...[
                  const SizedBox(width: 4),
                  const Text('(작성자)',
                      style: TextStyle(
                          color: Color(0xFF2196F3), // Blue
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _enableReplyMode(comment.id, comment.nickname),
                  child: const Text('답글 달기',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                _CommentInteraction(
                  icon: Icons.fireplace,
                  count: comment.supportCount,
                  color: Colors.orange,
                  onTap: () =>
                      ventingVM.addFirewoodToComment(post.id, comment.id),
                ),
                const SizedBox(width: 8),
                _CommentInteraction(
                  icon: Icons.water_drop,
                  count: comment.comfortCount,
                  color: Colors.blue,
                  onTap: () => ventingVM.addWaterToComment(post.id, comment.id),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: isReply ? 20.0 : 0.0),
          child: Text(comment.content, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildCommentInput(
      BuildContext context, UserViewModel userVM, PublicPost post) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_replyToNickname != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_replyToNickname 님에게 답글 작성 중...',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12)),
                    GestureDetector(
                      onTap: _cancelReplyMode,
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText: _replyToNickname != null
                            ? '답글을 입력하세요...'
                            : '따뜻한 위로를 건네주세요...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFFFF4D00)),
                    onPressed: () {
                      if (_commentController.text.isNotEmpty) {
                        final ventingVM = Provider.of<VentingViewModel>(context,
                            listen: false);

                        if (_replyToCommentId != null) {
                          ventingVM.addReplyToComment(
                            post.id,
                            _replyToCommentId!,
                            userVM.nickname ?? '익명',
                            _commentController.text,
                            userVM.userId ?? 'anonymous',
                          );
                          _cancelReplyMode();
                        } else {
                          ventingVM.addComment(
                            post.id,
                            userVM.nickname ?? '익명',
                            _commentController.text,
                            userVM.userId ?? 'anonymous',
                          );
                        }

                        _commentController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
