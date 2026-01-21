import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final ventingVM = Provider.of<VentingViewModel>(context);

    // Auto-expand last item when date changes or initially
    if (_lastSelectedDate == null ||
        !isSameDay(_lastSelectedDate, ventingVM.selectedCalendarDate)) {
      _lastSelectedDate = ventingVM.selectedCalendarDate;
      final posts = ventingVM.myPostsForSelectedDate;
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
          _buildKeywordStats(ventingVM),
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
      margin: const EdgeInsets.all(16),
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
            _expandedIndex = null; // Will be reset in build
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

  Widget _buildKeywordStats(VentingViewModel ventingVM) {
    final keywords = ventingVM.topKeywords;
    if (keywords.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('가장 많이 비운 키워드',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords.entries
                .map((e) => _KeywordChip(
                    label: e.key, count: e.value, color: _getTagColor(e.key)))
                .toList(),
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
                      Text(
                        post.content,
                        style: AppFonts.getFont(
                          Provider.of<UserViewModel>(context).selectedFont,
                          textStyle: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ),
                      if (post.aiResponse != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 14, color: Color(0xFFFF4D00)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  post.aiResponse!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      height: 1.4),
                                ),
                              ),
                            ],
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

class _KeywordChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _KeywordChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '#$label $count회',
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
