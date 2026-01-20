import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import 'post_detail_screen.dart';
import '../widgets/point_display.dart';

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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: post)),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${post.authorNickname} • $timeStr',
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                            if (post.lastModified != null)
                                              Text(
                                                  '수정됨: ${DateFormat('HH:mm').format(post.lastModified!)}',
                                                  style: TextStyle(
                                                      color: Colors.orange
                                                          .withOpacity(0.6),
                                                      fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(
                                                '분노 ${post.angerLevel.toInt()}%',
                                                style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          if (post.authorNickname ==
                                              userVM.nickname)
                                            _buildPostMenu(
                                                context, ventingVM, post),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          post.content,
                                          style: const TextStyle(
                                              fontSize: 15, height: 1.4),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (post.imagePath != null) ...[
                                        const SizedBox(width: 12),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: kIsWeb
                                                ? Image.network(post.imagePath!,
                                                    fit: BoxFit.cover)
                                                : Image.file(
                                                    File(post.imagePath!),
                                                    fit: BoxFit.cover),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (post.tags.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: post.tags
                                          .map((tag) => Text('#$tag',
                                              style: TextStyle(
                                                  color: _getTagColor(tag)
                                                      .withOpacity(0.7),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)))
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _InteractionButton(
                                        icon: Icons.fireplace,
                                        label: '장작 넣기',
                                        count: post.supportCount,
                                        itemCount: ventingVM.firewoodCount,
                                        color: Colors.orange,
                                        onTap: () {
                                          if (!ventingVM.addFirewood(post.id)) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      '장작이 부족합니다! 감정을 태워 충전하세요.')),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      _InteractionButton(
                                        icon: Icons.water_drop,
                                        label: '물 뿌리기',
                                        count: post.comfortCount,
                                        itemCount: ventingVM.waterCount,
                                        color: Colors.blue,
                                        onTap: () {
                                          if (!ventingVM.addWater(post.id)) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      '물이 부족합니다! 감정을 태워 충전하세요.')),
                                            );
                                          }
                                        },
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(Icons.comment,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${post.comments.length}',
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

  Widget _buildPostMenu(
      BuildContext context, VentingViewModel ventingVM, PublicPost post) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditDialog(context, ventingVM, post);
        } else if (value == 'delete') {
          ventingVM.deletePost(post.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('수정')),
        const PopupMenuItem(
            value: 'delete',
            child: Text('삭제', style: TextStyle(color: Colors.red))),
      ],
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

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int itemCount;
  final Color color;
  final VoidCallback onTap;

  const _InteractionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text('$label $count',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text('($itemCount)',
                style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
