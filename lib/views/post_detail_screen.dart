import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import '../utils/app_fonts.dart';

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
      appBar: AppBar(
        title: Text(
            '감정 상세 (${displayPost.tags.isNotEmpty ? displayPost.tags.first : '기타'})',
            style: const TextStyle(fontSize: 16)),
        actions: [
          // Only show report/block for posts not authored by current user
          if (displayPost.authorId != userVM.userId)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'report') {
                  _showReportDialog(context, displayPost, ventingVM, userVM);
                } else if (value == 'block') {
                  _confirmBlock(context, displayPost.authorId, ventingVM);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_problem,
                          color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('신고하기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text('이 사용자 차단'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: PublicPost.getLevelColor(displayPost.authorLevel)
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
                          color:
                              PublicPost.getLevelColor(displayPost.authorLevel),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(displayPost.authorNickname,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: PublicPost.getLevelColor(
                                displayPost.authorLevel))),
                    const SizedBox(width: 8),
                    // Compact Anger Level in Header
                    Text('분노 ${displayPost.angerLevel.toInt()}%',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(timeStr,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 16),

                // Image
                if (displayPost.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(displayPost.imagePath!)
                        : Image.file(File(displayPost.imagePath!)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Content (First line bold as subject)
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.5,
                      fontFamily: AppFonts.getFont(widget.post.fontName)
                          .fontFamily, // Optional: preserve font
                    ),
                    children: [
                      if (displayPost.content.contains('\n')) ...[
                        TextSpan(
                          text: '${displayPost.content.split('\n').first}\n',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: displayPost.content
                              .substring(displayPost.content.indexOf('\n') + 1),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ] else ...[
                        TextSpan(
                          text: displayPost.content,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Interaction Buttons
                Consumer<VentingViewModel>(
                  builder: (context, ventingVM, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: _DetailInteractionButton(
                            icon: Icons.fireplace,
                            label: '장작', // Shortened label
                            count: displayPost.supportCount,
                            itemCount: ventingVM.firewoodCount,
                            color: Colors.orange,
                            onTap: () async {
                              try {
                                await ventingVM.addFirewood(displayPost.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailInteractionButton(
                            icon: Icons.water_drop,
                            label: '물', // Shortened label
                            count: displayPost.comfortCount,
                            itemCount: ventingVM.waterCount,
                            color: Colors.blue,
                            onTap: () async {
                              try {
                                await ventingVM.addWater(displayPost.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
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
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    return GestureDetector(
      onLongPress: () {
        if (comment.authorId != userVM.userId) {
          _showCommentReportDialog(context, comment, post, ventingVM, userVM);
        }
      },
      child: Column(
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
                    onTap: () =>
                        ventingVM.addWaterToComment(post.id, comment.id),
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
      ),
    );
  }

  void _showReportDialog(BuildContext context, PublicPost post,
      VentingViewModel ventingVM, UserViewModel userVM) {
    String selectedReason = '스팸/부적절한 홍보';
    final List<String> reasons = [
      '스팸/부적절한 홍보',
      '욕설/비하 발언',
      '음란물/유해한 정보',
      '개인정보 노출',
      '기타'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('게시글 신고하기'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신고 사유를 선택해주세요.',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedReason,
                    dropdownColor: const Color(0xFF2A2A2A),
                    isExpanded: true,
                    items: reasons.map((String reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedReason = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ventingVM.reportPost(post.id, selectedReason,
                          userVM.userId ?? 'anonymous');
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신고가 접수되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('신고', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBlock(
      BuildContext context, String userId, VentingViewModel ventingVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('차단하기'),
        content: const Text('이 사용자를 차단하시겠습니까?\n앞으로 이 사용자가 쓴 글이 보이지 않습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ventingVM.blockUser(userId);
              Navigator.pop(context);
              Navigator.pop(context); // Close detail screen as well
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('사용자를 차단했습니다.')),
              );
            },
            child: const Text('차단', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCommentReportDialog(BuildContext context, PublicComment comment,
      PublicPost post, VentingViewModel ventingVM, UserViewModel userVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.report_problem, color: Colors.redAccent),
                title: const Text('댓글 신고하기',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialogForComment(
                      context, comment, post, ventingVM, userVM);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.grey),
                title: const Text('이 사용자 차단하기',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(context, comment.authorId, ventingVM);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialogForComment(BuildContext context, PublicComment comment,
      PublicPost post, VentingViewModel ventingVM, UserViewModel userVM) {
    String selectedReason = '스팸/부적절한 홍보';
    final List<String> reasons = [
      '스팸/부적절한 홍보',
      '욕설/비하 발언',
      '음란물/유해한 정보',
      '개인정보 노출',
      '기타'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('댓글 신고하기'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${comment.content}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('신고 사유를 선택해주세요.',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedReason,
                    dropdownColor: const Color(0xFF2A2A2A),
                    isExpanded: true,
                    items: reasons.map((String reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedReason = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ventingVM.reportPost(
                          post.id,
                          "[댓글 신고: ${comment.content}] $selectedReason",
                          userVM.userId ?? 'anonymous');
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('댓글 신고가 접수되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('신고', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
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
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 8), // Reduced vertical padding
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Centered
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text('$label $count',
                    style: TextStyle(
                        color: color,
                        fontSize: 12, // Reduced font
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Text('보유: $itemCount',
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
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
