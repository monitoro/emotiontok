import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../viewmodels/venting_viewmodel.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminViewModel(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('관리자 모드'),
            backgroundColor: Colors.redAccent.withOpacity(0.1),
            bottom: const TabBar(
              tabs: [
                Tab(text: '시드 생성'),
                Tab(text: '신고 목록'),
                Tab(text: '차단 현황'),
              ],
            ),
          ),
          body: Consumer<AdminViewModel>(
            builder: (context, adminVM, child) {
              return TabBarView(
                children: [
                  // Tab 1: Seed Generation
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 64, color: Colors.orange),
                          const SizedBox(height: 24),
                          const Text(
                            '초기 데이터 생성 도구',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'AI를 사용하여 가짜 사용자 게시글을 생성합니다.\n(레벨 3~9, 댓글 2~5개 자동 포함)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 48),
                          if (adminVM.isLoading)
                            const CircularProgressIndicator()
                          else
                            Column(
                              children: [
                                _buildGenerateButton(context, adminVM, 1),
                                const SizedBox(height: 16),
                                _buildGenerateButton(context, adminVM, 5),
                                const SizedBox(height: 16),
                                _buildGenerateButton(context, adminVM, 10),
                              ],
                            ),
                          const SizedBox(height: 24),
                          Text(
                            adminVM.statusMessage,
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab 2: Reports
                  _buildReportsTab(adminVM),

                  // Tab 3: Blocks
                  _buildBlocksTab(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBlocksTab(BuildContext context) {
    // Note: We need VentingViewModel here to Access local block list
    return Consumer<VentingViewModel>(
      builder: (context, ventingVM, child) {
        final blockedUsers = ventingVM.blockedUserIds.toList();

        if (blockedUsers.isEmpty) {
          return const Center(
            child: Text(
              "차단된 사용자가 없습니다.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("총 ${blockedUsers.length}명 차단됨",
                      style: const TextStyle(color: Colors.white70)),
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('전체 차단 해제',
                              style: TextStyle(color: Colors.white)),
                          content: const Text('모든 사용자의 차단을 해제하시겠습니까?',
                              style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소')),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                child: const Text('해제')),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ventingVM.unblockAllUsers();
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, color: Colors.orange),
                    label: const Text("전체 해제",
                        style: TextStyle(color: Colors.orange)),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: blockedUsers.length,
                itemBuilder: (context, index) {
                  final userId = blockedUsers[index];
                  return ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: Text(userId,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: const Text('로컬 차단됨',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.grey),
                      onPressed: () => ventingVM.unblockUser(userId),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportsTab(AdminViewModel adminVM) {
    if (adminVM.isLoading)
      return const Center(child: CircularProgressIndicator());

    if (adminVM.reportedPosts.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("신고된 게시글이 없습니다.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: () => adminVM.loadAdminStats(),
              child: const Text("새로고침"))
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: () => adminVM.loadAdminStats(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: adminVM.reportedPosts.length,
        itemBuilder: (context, index) {
          final item = adminVM.reportedPosts[index];
          final isDeleted = item['isDeleted'] == true;
          final reasons =
              (item['reasons'] as List).cast<String>().toSet().toList();

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          '신고 ${item['reportCount']}회',
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isDeleted)
                        const Text('(삭제됨)',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item['content'] ?? '',
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : Colors.white,
                      fontSize: 16,
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '작성자: ${item['authorNickname']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: reasons
                        .map((r) => Chip(
                              label:
                                  Text(r, style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.white10,
                              padding: EdgeInsets.zero,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isDeleted)
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2A2A2A),
                                title: const Text('게시글 삭제',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text('정말 이 게시글을 삭제하시겠습니까?',
                                    style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('취소')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('삭제',
                                          style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await adminVM.deletePost(item['postId']);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('게시글이 삭제되었습니다.')));
                              }
                            }
                          },
                          icon: const Icon(Icons.delete,
                              color: Colors.grey, size: 20),
                          label: const Text('삭제',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      const SizedBox(width: 8),
                      // 상세 내용을 다이얼로그로 표시
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text('상세 내용',
                                  style: TextStyle(color: Colors.white)),
                              content: SingleChildScrollView(
                                child: Text(item['content'] ?? '',
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('닫기'))
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 20),
                        label: const Text('상세 보기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenerateButton(
      BuildContext context, AdminViewModel adminVM, int count) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => adminVM.generateSeedData(count),
        icon: const Icon(Icons.auto_awesome),
        label: Text('$count개 생성하기'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
