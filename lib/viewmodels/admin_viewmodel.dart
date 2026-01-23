import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';
import 'venting_viewmodel.dart'; // For PublicPost model

class AdminViewModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _statusMessage = '';

  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;

  final List<String> _emotions = [
    '분노 (Anger)',
    '슬픔 (Sadness)',
    '짜증 (Annoyance)',
    '불안 (Anxiety)',
    '허무함 (Emptiness)',
    '우울 (Depression)',
    '지침 (Exhaustion)'
  ];

  final List<String> _nicknames = [
    '익명의 다람쥐',
    '지친 회사원',
    '배고픈 곰',
    '잠 못 드는 밤',
    '퇴사가 꿈',
    '월요병 환자',
    '그냥 행인',
    '소심한 관종',
    '분노조절장애',
    '행복하고싶다',
    '로또1등부탁',
    '익명123',
    '감자',
    '고구마',
  ];
  // Fixed tags based on VentingViewModel keys
  final List<String> _tags = ['직장', '관계', '일상', '연애', '건강'];

  List<Map<String, dynamic>> _reportedPosts =
      []; // {postId, reason, reporterId, content...}
  List<Map<String, dynamic>> _blockStats =
      []; // {blockerId, blockedId, timestamp}

  List<Map<String, dynamic>> get reportedPosts => _reportedPosts;
  List<Map<String, dynamic>> get blockStats => _blockStats;

  Future<void> loadAdminStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch all reports
      final reportSnapshot = await _firestore
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .get();

      // 2. Group by postId
      final Map<String, Map<String, dynamic>> groupedReports = {};

      for (var doc in reportSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String;
        final reason = data['reason'] as String? ?? '사유 없음';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (!groupedReports.containsKey(postId)) {
          groupedReports[postId] = {
            'postId': postId,
            'reportCount': 0,
            'reasons': <String>[],
            'latestTimestamp': timestamp,
            'content': '로딩 중...', // Placeholder
            'authorNickname': '알 수 없음',
            'isDeleted': false,
          };
        }

        groupedReports[postId]!['reportCount']++;
        (groupedReports[postId]!['reasons'] as List<String>).add(reason);
        // Keep latest timestamp
        if (timestamp != null &&
            (groupedReports[postId]!['latestTimestamp'] == null ||
                timestamp
                    .isAfter(groupedReports[postId]!['latestTimestamp']))) {
          groupedReports[postId]!['latestTimestamp'] = timestamp;
        }
      }

      // 3. Fetch Post Details for each group
      // Note: fetching one by one might be slow if many, but ok for admin tool for now.
      // Better approach: use `whereIn` chunks if possible, but simplicity first.
      for (var postId in groupedReports.keys) {
        try {
          final postDoc =
              await _firestore.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            final postData = postDoc.data()!;
            groupedReports[postId]!['content'] =
                postData['content'] ?? '채팅 내용이 없습니다.';
            groupedReports[postId]!['authorNickname'] =
                postData['authorNickname'] ?? '익명';
          } else {
            groupedReports[postId]!['content'] = '(삭제된 게시글입니다)';
            groupedReports[postId]!['isDeleted'] = true;
          }
        } catch (e) {
          groupedReports[postId]!['content'] = '불러오기 실패';
        }
      }

      _reportedPosts = groupedReports.values.toList();

      // Sort: Not deleted first, then by count descending
      _reportedPosts.sort((a, b) {
        if (a['isDeleted'] != b['isDeleted']) {
          return a['isDeleted'] ? 1 : -1; // Deleted items go to bottom
        }
        return b['reportCount'].compareTo(a['reportCount']);
      });
    } catch (e) {
      print('Error loading admin stats: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      // Update local state
      final index =
          _reportedPosts.indexWhere((item) => item['postId'] == postId);
      if (index != -1) {
        _reportedPosts[index]['content'] = '(삭제된 게시글입니다)';
        _reportedPosts[index]['isDeleted'] = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  Future<void> generateSeedData(int count) async {
    _isLoading = true;
    _statusMessage = '시드 데이터 생성 시작...';
    notifyListeners();

    int successCount = 0;
    final random = Random();

    for (int i = 0; i < count; i++) {
      try {
        _statusMessage = '글 생성 중... (${i + 1}/$count)';
        notifyListeners();

        final tag = _tags[random.nextInt(_tags.length)];
        // Map tag to topic for AI
        String topic = tag;
        if (tag == '직장')
          topic = '직장 상사/야근/업무';
        else if (tag == '관계')
          topic = '친구/인간관계/싸움';
        else if (tag == '연애')
          topic = '이별/짝사랑/연애고민';
        else if (tag == '건강')
          topic = '다이어트/운동/건강염려';
        else
          topic = '일상의 피곤함/지하철/날씨';

        final emotion = _emotions[random.nextInt(_emotions.length)];

        print('Generating post ${i + 1}/$count - Topic: $topic');
        final content = await AIService.getSeedContent(topic, emotion);
        print(
            'Post content generated: ${content.substring(0, min(10, content.length))}...');

        final nickname = _nicknames[random.nextInt(_nicknames.length)];
        final level = 3 + random.nextInt(7); // 3 ~ 9 (3 + 0..6)
        final angerLevel = random.nextDouble() * 100;

        final now = DateTime.now();
        final timestamp = now.subtract(Duration(
          hours: random.nextInt(48),
          minutes: random.nextInt(60),
        ));

        // Generate Comments
        List<PublicComment> comments = [];
        int commentCount = 2 + random.nextInt(4); // 2 ~ 5
        print('Generating $commentCount comments for post ${i + 1}');

        for (int j = 0; j < commentCount; j++) {
          String commentContent =
              await AIService.getSeedContent("위로/공감/조언", "따뜻함");
          String commentNick = _nicknames[random.nextInt(_nicknames.length)];
          comments.add(PublicComment(
              authorId: 'seed_commenter_$j',
              nickname: commentNick,
              content: commentContent,
              timestamp:
                  timestamp.add(Duration(minutes: 5 + random.nextInt(60))),
              supportCount: random.nextInt(5),
              comfortCount: random.nextInt(5)));
        }
        print('Comments generated for post ${i + 1}');

        final post = PublicPost(
            id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
            authorId: 'seed_generator',
            authorNickname: nickname,
            content: content,
            angerLevel: angerLevel,
            timestamp: timestamp,
            supportCount: random.nextInt(20),
            comfortCount: random.nextInt(20),
            tags: [tag], // Use fixed tag
            authorLevel: level,
            fontName: 'NanumPen',
            comments: comments);

        await _firestore.collection('posts').doc(post.id).set(post.toMap());
        print('Post ${i + 1} saved to Firestore');
        successCount++;
      } catch (e, s) {
        print("Error generating seed post: $e");
        print(s);
      }
    }

    _isLoading = false;
    _statusMessage = '완료! $successCount개의 글이 생성되었습니다.';
    notifyListeners();
  }
}
