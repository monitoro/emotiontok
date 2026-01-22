import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../viewmodels/user_viewmodel.dart';

enum VentingMode { text, doodle, voice }

class PublicComment {
  final String nickname;
  final String content;
  final DateTime timestamp;
  int supportCount;
  int comfortCount;
  final List<PublicComment> replies;

  PublicComment({
    required this.nickname,
    required this.content,
    required this.timestamp,
    this.supportCount = 0,
    this.comfortCount = 0,
    List<PublicComment>? replies,
  }) : replies = replies ?? [];

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'supportCount': supportCount,
      'comfortCount': comfortCount,
      'replies': replies.map((r) => r.toMap()).toList(),
    };
  }

  factory PublicComment.fromMap(Map<String, dynamic> map) {
    return PublicComment(
      nickname: map['nickname'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      supportCount: map['supportCount'] ?? 0,
      comfortCount: map['comfortCount'] ?? 0,
      replies: map['replies'] != null
          ? List<PublicComment>.from(
              (map['replies'] as List).map((x) => PublicComment.fromMap(x)))
          : null,
    );
  }
}

class PublicPost {
  final String id;
  final String authorNickname;
  String content;
  final double angerLevel;
  final DateTime timestamp;
  DateTime? lastModified;
  final String? imagePath;
  int supportCount;
  int comfortCount;
  final List<PublicComment> comments;
  final List<String> tags;
  final String fontName;

  PublicPost({
    required this.id,
    required this.authorNickname,
    required this.content,
    required this.angerLevel,
    required this.timestamp,
    this.lastModified,
    this.imagePath,
    this.supportCount = 0,
    this.comfortCount = 0,
    List<PublicComment>? comments,
    this.tags = const [],
    this.fontName = '나눔 펜 (손글씨)',
  }) : comments = comments ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorNickname': authorNickname,
      'content': content,
      'angerLevel': angerLevel,
      'timestamp': timestamp.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
      'imagePath': imagePath,
      'supportCount': supportCount,
      'comfortCount': comfortCount,
      'comments': comments.map((c) => c.toMap()).toList(),
      'tags': tags,
      'fontName': fontName,
    };
  }

  factory PublicPost.fromMap(Map<String, dynamic> map) {
    return PublicPost(
      id: map['id'],
      authorNickname: map['authorNickname'],
      content: map['content'],
      angerLevel: map['angerLevel'],
      timestamp: DateTime.parse(map['timestamp']),
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'])
          : null,
      imagePath: map['imagePath'],
      supportCount: map['supportCount'] ?? 0,
      comfortCount: map['comfortCount'] ?? 0,
      comments: map['comments'] != null
          ? List<PublicComment>.from(
              (map['comments'] as List).map((x) => PublicComment.fromMap(x)))
          : null,
      tags: List<String>.from(map['tags'] ?? []),
      fontName: map['fontName'] ?? '나눔 펜 (손글씨)',
    );
  }
}

class PrivatePost {
  final String id;
  final String content;
  final double angerLevel;
  final DateTime timestamp;
  final String? imagePath;
  final String? aiResponse;
  final List<String> tags;
  final bool isPublic;

  PrivatePost({
    required this.id,
    required this.content,
    required this.angerLevel,
    required this.timestamp,
    this.imagePath,
    this.aiResponse,
    this.tags = const [],
    this.isPublic = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'angerLevel': angerLevel,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'aiResponse': aiResponse,
      'tags': tags,
      'isPublic': isPublic,
    };
  }

  factory PrivatePost.fromMap(Map<String, dynamic> map) {
    return PrivatePost(
      id: map['id'],
      content: map['content'],
      angerLevel: map['angerLevel'],
      timestamp: DateTime.parse(map['timestamp']),
      imagePath: map['imagePath'],
      aiResponse: map['aiResponse'],
      tags: List<String>.from(map['tags'] ?? []),
      isPublic: map['isPublic'] ?? false,
    );
  }
}

enum SquareSortType { latest, firewood, water, comments }

enum SquareFilterPeriod { all, day, week, month }

class VentingViewModel with ChangeNotifier {
  VentingMode _currentMode = VentingMode.text;
  bool _isBurning = false;
  String? _lastAiResponse;
  int _todaysBurnCount = 0;
  Uint8List? _doodleData;
  String? _pickedImagePath;
  bool _shareToSquare = false;

  SquareSortType _sortType = SquareSortType.latest;
  SquareFilterPeriod _filterPeriod = SquareFilterPeriod.all;
  String? _selectedTag;

  int _firewoodCount = 3;
  int _waterCount = 3;

  final List<PublicPost> _publicPosts = [
    PublicPost(
      id: '1',
      authorNickname: '익명불사조',
      content: '부당한 대우를 참는 것도 한계가 있네요. 다 타버려라!',
      angerLevel: 90,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      supportCount: 12,
      tags: ['직장'],
      comments: [
        PublicComment(
            nickname: '위로봇',
            content: '정말 힘드시겠어요. 힘내세요!',
            timestamp: DateTime.now()),
      ],
    ),
  ];

  final List<PrivatePost> _privateHistory = [];
  DateTime _selectedCalendarDate = DateTime.now();

  VentingViewModel() {
    _loadPrivateHistory();
    _loadPublicPosts();
  }

  Future<void> _loadPrivateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('private_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _privateHistory.clear();
      _privateHistory
          .addAll(decoded.map((e) => PrivatePost.fromMap(e)).toList());
      notifyListeners();
    }
  }

  Future<void> _savePrivateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_privateHistory.map((p) => p.toMap()).toList());
    await prefs.setString('private_history', encoded);
  }

  Future<void> _loadPublicPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? postsJson = prefs.getString('public_posts');
    if (postsJson != null) {
      final List<dynamic> decoded = jsonDecode(postsJson);
      _publicPosts.clear();
      _publicPosts.addAll(decoded.map((e) => PublicPost.fromMap(e)).toList());
      notifyListeners();
    }
  }

  Future<void> _savePublicPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_publicPosts.map((p) => p.toMap()).toList());
    await prefs.setString('public_posts', encoded);
  }

  VentingMode get currentMode => _currentMode;
  bool get isBurning => _isBurning;
  String? get lastAiResponse => _lastAiResponse;
  int get todaysBurnCount => _todaysBurnCount;
  Uint8List? get doodleData => _doodleData;
  String? get pickedImagePath => _pickedImagePath;
  bool get shareToSquare => _shareToSquare;
  int get firewoodCount => _firewoodCount;
  int get waterCount => _waterCount;
  SquareSortType get sortType => _sortType;
  SquareFilterPeriod get filterPeriod => _filterPeriod;
  DateTime get selectedCalendarDate => _selectedCalendarDate;
  String? get selectedTag => _selectedTag;

  List<PrivatePost> get myHistory => _privateHistory;

  List<PrivatePost> get myPostsForSelectedDate {
    return _privateHistory.where((p) {
      return p.timestamp.year == _selectedCalendarDate.year &&
          p.timestamp.month == _selectedCalendarDate.month &&
          p.timestamp.day == _selectedCalendarDate.day;
    }).toList();
  }

  void setSelectedCalendarDate(DateTime date) {
    _selectedCalendarDate = date;
    notifyListeners();
  }

  Map<String, int> get topKeywords {
    final Map<String, int> counts = {};
    for (var post in _privateHistory) {
      for (var tag in post.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries.take(5));
  }

  List<PublicPost> get publicPosts {
    List<PublicPost> filteredList = _publicPosts;

    // Filter by tag
    if (_selectedTag != null && _selectedTag != '전체') {
      filteredList =
          filteredList.where((p) => p.tags.contains(_selectedTag)).toList();
    }

    // Filter by period
    if (_filterPeriod != SquareFilterPeriod.all) {
      final now = DateTime.now();
      Duration duration;
      switch (_filterPeriod) {
        case SquareFilterPeriod.day:
          duration = const Duration(days: 1);
          break;
        case SquareFilterPeriod.week:
          duration = const Duration(days: 7);
          break;
        case SquareFilterPeriod.month:
          duration = const Duration(days: 30);
          break;
        default:
          duration = const Duration(days: 999);
      }
      filteredList = filteredList
          .where((p) => now.difference(p.timestamp) < duration)
          .toList();
    }
    final List<PublicPost> sortedList = List.from(filteredList);
    switch (_sortType) {
      case SquareSortType.latest:
        sortedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SquareSortType.firewood:
        sortedList.sort((a, b) => b.supportCount.compareTo(a.supportCount));
        break;
      case SquareSortType.water:
        sortedList.sort((a, b) => b.comfortCount.compareTo(a.comfortCount));
        break;
      case SquareSortType.comments:
        sortedList
            .sort((a, b) => b.comments.length.compareTo(a.comments.length));
        break;
    }
    return sortedList;
  }

  void setSortType(SquareSortType type) {
    _sortType = type;
    notifyListeners();
  }

  void setFilterPeriod(SquareFilterPeriod period) {
    _filterPeriod = period;
    notifyListeners();
  }

  void setSelectedTag(String? tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  void setMode(VentingMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  void setShareToSquare(bool value) {
    _shareToSquare = value;
    notifyListeners();
  }

  void setDoodleData(Uint8List? data) {
    _doodleData = data;
    notifyListeners();
  }

  void setPickedImagePath(String? path) {
    _pickedImagePath = path;
    notifyListeners();
  }

  void startBurning() {
    _isBurning = true;
    _lastAiResponse = null;
    notifyListeners();
  }

  bool addFirewood(String postId) {
    if (_firewoodCount <= 0) return false;
    final index = _publicPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _publicPosts[index].supportCount++;
      _firewoodCount--;
      _savePublicPosts();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool addWater(String postId) {
    if (_waterCount <= 0) return false;
    final index = _publicPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _publicPosts[index].comfortCount++;
      _waterCount--;
      _savePublicPosts();
      notifyListeners();
      return true;
    }
    return false;
  }

  void addComment(String postId, String nickname, String content) {
    final index = _publicPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _publicPosts[index].comments.add(
            PublicComment(
                nickname: nickname,
                content: content,
                timestamp: DateTime.now()),
          );
      _savePublicPosts();
      notifyListeners();
    }
  }

  String? validateContent(String text) {
    // 욕설 필터링 제거: 시원하게 욕해도 되는 컨셉
    return null;
  }

  void finishBurning(Persona persona, String text, UserViewModel userVM,
      {double? angerLevel}) async {
    final extractedTags = _extractTags(text);
    final now = DateTime.now();
    final postId = now.millisecondsSinceEpoch.toString();

    PublicPost? newPublicPost;

    if (_shareToSquare) {
      newPublicPost = PublicPost(
        id: postId,
        authorNickname: userVM.nickname ?? '익명',
        content: text,
        angerLevel: angerLevel ?? 50,
        timestamp: now,
        imagePath: _pickedImagePath,
        tags: extractedTags,
        fontName: userVM.selectedFont,
      );
      _publicPosts.insert(0, newPublicPost);
      _savePublicPosts();
    }

    _privateHistory.insert(
      0,
      PrivatePost(
        id: postId,
        content: text,
        angerLevel: angerLevel ?? 50,
        timestamp: now,
        imagePath: _pickedImagePath,
        aiResponse: null,
        tags: extractedTags,
        isPublic: _shareToSquare,
      ),
    );
    _savePrivateHistory(); // Save initial post

    _isBurning = false;
    _todaysBurnCount++;
    _pickedImagePath = null;
    userVM.incrementBurnCount();
    _firewoodCount++;
    _waterCount++;
    notifyListeners();

    final response = await AIService.getResponse(persona, text);
    _lastAiResponse = response;

    // Update private history with AI response
    final lastPrivateIndex = _privateHistory
        .indexWhere((p) => p.aiResponse == null && p.content == text);
    if (lastPrivateIndex != -1) {
      _privateHistory[lastPrivateIndex] = PrivatePost(
        id: _privateHistory[lastPrivateIndex].id,
        content: _privateHistory[lastPrivateIndex].content,
        angerLevel: _privateHistory[lastPrivateIndex].angerLevel,
        timestamp: _privateHistory[lastPrivateIndex].timestamp,
        imagePath: _privateHistory[lastPrivateIndex].imagePath,
        aiResponse: response,
        tags: extractedTags,
        isPublic: _privateHistory[lastPrivateIndex].isPublic,
      );
      _savePrivateHistory(); // Save updated post with AI response
    }

    // Add AI Response as a comment to the captured public post
    if (newPublicPost != null && response.isNotEmpty) {
      newPublicPost.comments.insert(
        0,
        PublicComment(
          nickname: '마음이 (${_getPersonaName(persona)})',
          content: response,
          timestamp: DateTime.now(),
        ),
      );
      _savePublicPosts();
      notifyListeners();
    }
    notifyListeners();
  }

  String _getPersonaName(Persona persona) {
    switch (persona) {
      case Persona.fighter:
        return '불사조';
      case Persona.empathy:
        return '천사';
      case Persona.factBomb:
        return '분석가';
      case Persona.humor:
        return '광대';
    }
  }

  List<String> _extractTags(String content) {
    final Map<String, List<String>> keywordMap = {
      '직장': ['회사', '상사', '업무', '야근', '출근', '퇴근', '동료', '월급'],
      '관계': ['친구', '싸움', '오해', '절교', '비난', '모임'],
      '일상': ['교통', '지하철', '날씨', '점심', '피곤'],
      '연애': ['이별', '다툼', '서운', '짝사랑'],
      '건강': ['아픔', '스트레스', '불면', '운동'],
    };

    final List<String> tags = [];
    keywordMap.forEach((tag, keywords) {
      for (var kw in keywords) {
        if (content.contains(kw)) {
          tags.add(tag);
          break;
        }
      }
    });

    if (tags.isEmpty) tags.add('기타');
    return tags;
  }

  void editPost(String postId, String newContent) {
    final index = _publicPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _publicPosts[index].content = newContent;
      _publicPosts[index].lastModified = DateTime.now();
      _savePublicPosts();
      notifyListeners();
    }
  }

  void deletePost(String postId) {
    _publicPosts.removeWhere((p) => p.id == postId);
    _savePublicPosts();
    notifyListeners();
  }

  bool addFirewoodToComment(String postId, int commentIndex) {
    if (_firewoodCount <= 0) return false;
    final postIndex = _publicPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1 &&
        commentIndex < _publicPosts[postIndex].comments.length) {
      _publicPosts[postIndex].comments[commentIndex].supportCount++;
      _firewoodCount--;
      _savePublicPosts();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool addWaterToComment(String postId, int commentIndex) {
    if (_waterCount <= 0) return false;
    final postIndex = _publicPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1 &&
        commentIndex < _publicPosts[postIndex].comments.length) {
      _publicPosts[postIndex].comments[commentIndex].comfortCount++;
      _waterCount--;
      _savePublicPosts();
      notifyListeners();
      return true;
    }
    return false;
  }

  void addReply(
      String postId, int commentIndex, String nickname, String content) {
    final postIndex = _publicPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1 &&
        commentIndex < _publicPosts[postIndex].comments.length) {
      _publicPosts[postIndex].comments[commentIndex].replies.add(
            PublicComment(
              nickname: nickname,
              content: content,
              timestamp: DateTime.now(),
            ),
          );
      _savePublicPosts();
      notifyListeners();
    }
  }

  PublicPost? getPublicPost(String id) {
    try {
      return _publicPosts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearAiResponse() {
    _lastAiResponse = null;
    notifyListeners();
  }
}
