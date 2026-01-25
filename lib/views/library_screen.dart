import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emotiontok/views/post_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../viewmodels/venting_viewmodel.dart';
import '../widgets/point_display.dart';
import '../viewmodels/user_viewmodel.dart';
import '../utils/app_fonts.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  int? _expandedIndex;
  DateTime? _lastSelectedDate;

  @override
  Widget build(BuildContext context) {
    print('DEBUG: LibraryScreen.build called');
    final ventingVM = Provider.of<VentingViewModel>(context);
    final userVM = Provider.of<UserViewModel>(context);

    final posts = ventingVM.myPostsForSelectedDate;
    print(
        'DEBUG: LibraryScreen Build. SelectedDate: ${ventingVM.selectedCalendarDate}');
    print('DEBUG: myPostsForSelectedDate Count: ${posts.length}');

    // Auto-expand last item when date changes or initially
    if (_lastSelectedDate == null ||
        !isSameDay(_lastSelectedDate, ventingVM.selectedCalendarDate)) {
      _lastSelectedDate = ventingVM.selectedCalendarDate;
      // The 'posts' variable is already declared above, so we don't need to redeclare it here.
      if (posts.isNotEmpty) {
        _expandedIndex = posts.length - 1;
      } else {
        _expandedIndex = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('감정 보관함', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: const [
          PointDisplay(),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(ventingVM),
          Consumer<UserViewModel>(
            builder: (context, userVM, child) {
              return Column(
                children: [
                  _buildLevelSection(userVM),
                  _buildStatSummary(ventingVM, userVM),
                ],
              );
            },
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: _buildPostList(ventingVM),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(VentingViewModel ventingVM) {
    return Container(
      margin: const EdgeInsets.all(8), // Reduced from 16
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: ventingVM.selectedCalendarDate,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) =>
            isSameDay(ventingVM.selectedCalendarDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          ventingVM.setSelectedCalendarDate(selectedDay);
          setState(() {
            _expandedIndex = null;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          titleTextStyle:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          formatButtonTextStyle: TextStyle(color: Color(0xFFFF4D00)),
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFFF4D00))),
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: Color(0xFFFF4D00),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          defaultTextStyle: TextStyle(color: Colors.white70),
          weekendTextStyle: TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildLevelSection(UserViewModel userVM) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 2), // Reduced vert from 8
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lv.${userVM.level}',
                  style: const TextStyle(
                      color: Color(0xFFFF4D00),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4), // Reduced from 8
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: userVM.levelProgress,
              backgroundColor: Colors.white10,
              color: const Color(0xFFFF4D00),
              minHeight: 6, // Reduced from 10
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '다음 레벨까지 ${userVM.remainingXP} XP',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(VentingViewModel ventingVM, UserViewModel userVM) {
    return FutureBuilder<Map<String, int>>(
      future: ventingVM.getMyInteractionStats(userVM.userId ?? ''),
      builder: (context, snapshot) {
        final firewood = snapshot.data?['firewood'] ?? 0;
        final water = snapshot.data?['water'] ?? 0;
        // final receivedPoints = firewood + water; // Unused
        final writingPoints = userVM.writingPoints;

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4), // Reduced vert from 8
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16), // Reduced vert pad from 16
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Text('경험치 획득 내역',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12)), // Reduced font 14->12
                    const SizedBox(height: 8), // Reduced from 16
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('글 작성', '$writingPoints', Icons.edit,
                            const Color(0xFF4CAF50)),
                        _buildContainerLine(),
                        _buildStatItem('받은 장작', '$firewood', Icons.fireplace,
                            Colors.orange),
                        _buildContainerLine(),
                        _buildStatItem(
                            '받은 물', '$water', Icons.water_drop, Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 6), // Reduced from 12
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContainerLine() {
    return Container(
      height: 30, // Reduced from 40
      width: 1,
      color: Colors.white10,
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20), // Reduced from 24
        const SizedBox(height: 4), // Reduced from 8
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16, // Reduced from 18
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2), // Reduced from 4
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 11)), // Reduced from 12
      ],
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

  Widget _buildPostList(VentingViewModel ventingVM) {
    final posts = ventingVM.myPostsForSelectedDate;

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              '${DateFormat('MM월 dd일').format(ventingVM.selectedCalendarDate)}에 비운 감정이 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final isExpanded = index == _expandedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? null : index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isExpanded
                      ? const Color(0xFFFF4D00).withOpacity(0.5)
                      : Colors.white.withOpacity(0.05)),
            ),
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(post.timestamp),
                            style: const TextStyle(
                                color: Color(0xFFFF4D00),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '분노 ${post.angerLevel.toInt()}%',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (post.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          children: post.tags
                              .map((tag) => Text('#$tag',
                                  style: TextStyle(
                                      color: _getTagColor(tag).withOpacity(0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Chat History Layout
                      // Chat History Layout
                      if (post.chatHistory.isNotEmpty) ...[
                        ...post.chatHistory.map((msg) {
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: isUser
                                ? // User Bubble
                                Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 12, left: 40),
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF4D00),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(2),
                                      ),
                                    ),
                                    child: Text(
                                      msg['content'] ?? '',
                                      style: AppFonts.getFont(
                                        Provider.of<UserViewModel>(context)
                                            .selectedFont,
                                        textStyle: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : // AI Bubble
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.white10,
                                        child: Icon(Icons.auto_awesome,
                                            size: 16, color: Color(0xFFFF4D00)),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: const BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                              bottomLeft: Radius.circular(2),
                                              bottomRight: Radius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            msg['content'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        }),
                      ] else ...[
                        // Legacy Fallback
                        // 1. User Message (Right)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12, left: 40),
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4D00),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(2),
                              ),
                            ),
                            child: Text(
                              post.content,
                              style: AppFonts.getFont(
                                Provider.of<UserViewModel>(context)
                                    .selectedFont,
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. AI Response (Left) if exists
                        if (post.aiResponse != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white10,
                                  child: Icon(Icons.auto_awesome,
                                      size: 16, color: Color(0xFFFF4D00)),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(2),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      post.aiResponse!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],

                      if (post.isPublic) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              final publicPost =
                                  ventingVM.getPublicPost(post.id);
                              if (publicPost != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: publicPost),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('광장에서 삭제되었거나 찾을 수 없는 글입니다.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.public,
                                size: 16, color: Color(0xFFFF4D00)),
                            label: const Text('광장에서 보기',
                                style: TextStyle(
                                    color: Color(0xFFFF4D00), fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              backgroundColor:
                                  const Color(0xFFFF4D00).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(post.timestamp),
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          post.content.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey, size: 16),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
