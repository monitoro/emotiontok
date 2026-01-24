import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import 'post_detail_screen.dart';
import '../widgets/point_display.dart';
import 'package:vibration/vibration.dart';

class SquareScreen extends StatelessWidget {
  const SquareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타오르는 광장',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: const [
          PointDisplay(),
          SizedBox(width: 16),
        ],
      ),
      body: Consumer2<VentingViewModel, UserViewModel>(
        builder: (context, ventingVM, userVM, child) {
          final posts = ventingVM.publicPosts;

          return Column(
            children: [
              // Filter Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Sort Type
                    _buildFilterChip(
                      context,
                      icon: Icons.sort,
                      label: _getSortLabel(ventingVM.sortType),
                      onSelected: () {
                        _showSortMenu(context, ventingVM);
                      },
                    ),
                    const SizedBox(width: 12),
                    // Tag Filter
                    _buildFilterChip(
                      context,
                      icon: Icons.tag,
                      label: ventingVM.selectedTag ?? '전체',
                      onSelected: () {
                        _showTagMenu(context, ventingVM);
                      },
                    ),
                    const SizedBox(width: 12),
                    // Period Filter
                    _buildFilterChip(
                      context,
                      icon: Icons.calendar_today,
                      label: _getPeriodLabel(ventingVM.filterPeriod),
                      onSelected: () {
                        _showPeriodMenu(context, ventingVM);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: posts.isEmpty
                    ? const Center(
                        child: Text('아직 광장에 올라온 감정이 없습니다.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final timeStr =
                              DateFormat('HH:mm').format(post.timestamp);

                          return GestureDetector(
                            onTap: () async {
                              if (userVM.isVibrationOn &&
                                  await Vibration.hasVibrator() == true) {
                                Vibration.vibrate(duration: 50);
                              }
                              ventingVM.markPostAsRead(post.id); // Mark as read
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: post)),
                              );
                            },
                            onLongPress: () {
                              // Can't block/report myself
                              if (post.authorId != userVM.userId) {
                                _showReportBlockOption(
                                    context, post, ventingVM);
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 6), // 8 -> 6
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10), // 16, 12 -> 14, 10
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius:
                                    BorderRadius.circular(12), // 16 -> 12
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.1), // 그림자 연하게
                                      blurRadius: 4,
                                      offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1st Line: Content & Image
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          post.content,
                                          style: TextStyle(
                                              fontSize: 15,
                                              height: 1.2,
                                              color:
                                                  ventingVM.isPostRead(post.id)
                                                      ? Colors.white38
                                                      : Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (post.imagePath != null) ...[
                                        const SizedBox(width: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: SizedBox(
                                            width: 32, // Smaller thumbnail
                                            height: 32,
                                            child: kIsWeb
                                                ? Image.network(post.imagePath!,
                                                    fit: BoxFit.cover)
                                                : Image.file(
                                                    File(post.imagePath!),
                                                    fit: BoxFit.cover),
                                          ),
                                        ),
                                      ],
                                      // Edit/Delete Buttons (Moved to Right Top) -> Only if author is me
                                      if (userVM.userId != null &&
                                          post.authorId == userVM.userId)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _showEditDialog(
                                                  context, ventingVM, post),
                                              child: const Icon(Icons.edit,
                                                  size: 16, color: Colors.grey),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _confirmDelete(
                                                  context, post.id, ventingVM),
                                              child: const Icon(Icons.delete,
                                                  size: 16, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6), // Tight spacing
                                  // 2nd Line: Meta Info & Stats
                                  Row(
                                    children: [
                                      // Tag
                                      if (post.tags.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: Text(
                                            '[#${post.tags.first}]',
                                            style: const TextStyle(
                                                color: Colors.orangeAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      // Level Badge
                                      // Level Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: PublicPost.getLevelColor(
                                                  post.authorLevel)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: PublicPost.getLevelColor(
                                                  post.authorLevel),
                                              width: 0.5),
                                        ),
                                        child: Text(
                                          'Lv.${post.authorLevel}',
                                          style: TextStyle(
                                            color: PublicPost.getLevelColor(
                                                post.authorLevel),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Author Nickname
                                      Text(
                                        post.authorNickname,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: PublicPost.getLevelColor(
                                                post.authorLevel)),
                                      ),
                                      const SizedBox(width: 6),
                                      // Anger Level
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                        child: Text(
                                            '분노 ${post.angerLevel.toInt()}%',
                                            style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ),

                                      const Spacer(), // Push stats to right

                                      // Right: Stats (Fire, Water, Comment)
                                      _InteractionIcon(
                                        icon: Icons.fireplace,
                                        count: post.supportCount,
                                        color: Colors.orange,
                                        onTap: () async {
                                          if (userVM.isVibrationOn &&
                                              await Vibration.hasVibrator() ==
                                                  true) {
                                            Vibration.vibrate(duration: 50);
                                          }
                                          try {
                                            await ventingVM
                                                .addFirewood(post.id);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(e.toString())),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      _InteractionIcon(
                                        icon: Icons.water_drop,
                                        count: post.comfortCount,
                                        color: Colors.blue,
                                        onTap: () async {
                                          if (userVM.isVibrationOn &&
                                              await Vibration.hasVibrator() ==
                                                  true) {
                                            Vibration.vibrate(duration: 50);
                                          }
                                          try {
                                            await ventingVM.addWater(post.id);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(e.toString())),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.comment,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${post.totalCommentCount}', // Use recursive count
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReportBlockOption(
      BuildContext context, PublicPost post, VentingViewModel ventingVM) {
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
                title:
                    const Text('신고하기', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context, post, ventingVM);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.grey),
                title: const Text('이 사용자의 글 보지 않기 (차단)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(context, post.authorId, ventingVM);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(
      BuildContext context, PublicPost post, VentingViewModel ventingVM) {
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
              title: const Text('신고하기'),
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
                    // Reporter ID needed? UserVM is available via Provider in context usually,
                    // but we can pass it or just use "anonymous" if needed.
                    // Ideally pass UserViewModel too. Assuming VentingVM handles it or we pass a placeholder.
                    // Let's pass 'reporter' string for now or fetch UserVM properly.
                    final userVM =
                        Provider.of<UserViewModel>(context, listen: false);
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

  Widget _buildFilterChip(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onSelected}) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(SquareSortType type) {
    switch (type) {
      case SquareSortType.latest:
        return '최신순';
      case SquareSortType.firewood:
        return '장작순';
      case SquareSortType.water:
        return '물뿌리기순';
      case SquareSortType.comments:
        return '댓글순';
    }
  }

  String _getPeriodLabel(SquareFilterPeriod period) {
    switch (period) {
      case SquareFilterPeriod.all:
        return '전체 기간';
      case SquareFilterPeriod.day:
        return '최근 24시간';
      case SquareFilterPeriod.week:
        return '최근 7일';
      case SquareFilterPeriod.month:
        return '최근 30일';
    }
  }

  void _showSortMenu(BuildContext context, VentingViewModel ventingVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SquareSortType.values.map((type) {
            return ListTile(
              title: Text(_getSortLabel(type),
                  style: TextStyle(
                      color: ventingVM.sortType == type
                          ? const Color(0xFFFF4D00)
                          : Colors.white)),
              trailing: ventingVM.sortType == type
                  ? const Icon(Icons.check, color: Color(0xFFFF4D00))
                  : null,
              onTap: () {
                ventingVM.setSortType(type);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPeriodMenu(BuildContext context, VentingViewModel ventingVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SquareFilterPeriod.values.map((period) {
            return ListTile(
              title: Text(_getPeriodLabel(period),
                  style: TextStyle(
                      color: ventingVM.filterPeriod == period
                          ? const Color(0xFFFF4D00)
                          : Colors.white)),
              trailing: ventingVM.filterPeriod == period
                  ? const Icon(Icons.check, color: Color(0xFFFF4D00))
                  : null,
              onTap: () {
                ventingVM.setFilterPeriod(period);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTagMenu(BuildContext context, VentingViewModel ventingVM) {
    final tags = ['전체', '직장', '관계', '일상', '연애', '건강', '기타'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tags.map((tag) {
            final isSelected = (ventingVM.selectedTag ?? '전체') == tag;
            return ListTile(
              leading: Icon(
                Icons.tag,
                color: isSelected ? const Color(0xFFFF4D00) : _getTagColor(tag),
              ),
              title: Text(tag,
                  style: TextStyle(
                      color:
                          isSelected ? const Color(0xFFFF4D00) : Colors.white)),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFFFF4D00))
                  : null,
              onTap: () {
                ventingVM.setSelectedTag(tag == '전체' ? null : tag);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, VentingViewModel ventingVM, PublicPost post) {
    final controller = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('게시글 수정'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ventingVM.editPost(post.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('수정', style: TextStyle(color: Color(0xFFFF4D00))),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, String postId, VentingViewModel ventingVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('게시글 삭제'),
        content: const Text('정말로 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ventingVM.deletePost(postId);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case '직장':
        return Colors.red;
      case '관계':
        return Colors.orange;
      case '일상':
        return Colors.blue;
      case '연애':
        return Colors.pink;
      case '건강':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _InteractionIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _InteractionIcon({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
// Removed old _InteractionButton clas
