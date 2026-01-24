import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../viewmodels/user_viewmodel.dart';

enum VentingMode { text, voice }

class PublicComment {
  final String id; // Add ID for identification
  final String authorId; // User UUID
  final String nickname;
  final String content;
  final DateTime timestamp;
  int supportCount;
  int comfortCount;
  final List<PublicComment> replies;

  PublicComment({
    String? id,
    required this.authorId,
    required this.nickname,
    required this.content,
    required this.timestamp,
    this.supportCount = 0,
    this.comfortCount = 0,
    List<PublicComment>? replies,
  })  : id = id ??
            DateTime.now().millisecondsSinceEpoch.toString() +
                nickname.hashCode.toString(),
        replies = replies ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
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
      id: map['id'],
      authorId: map['authorId'] ?? '', // Fallback for old comments
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
  final String authorId; // User UUID
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
  final int authorLevel;

  // Recursive comment count getter
  int get totalCommentCount {
    int count = 0;
    for (var comment in comments) {
      count += 1 + _countReplies(comment);
    }
    return count;
  }

  int _countReplies(PublicComment comment) {
    int count = 0;
    for (var reply in comment.replies) {
      count += 1 + _countReplies(reply);
    }
    return count;
  }

  PublicPost({
    required this.id,
    required this.authorId,
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
    this.authorLevel = 1,
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
      'authorLevel': authorLevel,
      'authorId': authorId,
    };
  }

  static Color getLevelColor(int level) {
    if (level >= 90) return const Color(0xFFFFD700); // Gold (Legend)
    if (level >= 70) return const Color(0xFFE91E63); // Pink (Master)
    if (level >= 50) return const Color(0xFF9C27B0); // Purple (Diamond)
    if (level >= 30) return const Color(0xFF2196F3); // Blue (Platinum)
    if (level >= 10) return const Color(0xFF4CAF50); // Green (Gold)
    return Colors.white70; // Default (Beginner)
  }

  factory PublicPost.fromMap(Map<String, dynamic> map) {
    return PublicPost(
      id: map['id'],
      authorId: map['authorId'] ?? '', // Fallback for old posts
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
      authorLevel: map['authorLevel'] ?? 1,
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  VentingMode _currentMode = VentingMode.text;
  bool _isBurning = false;
  String? _lastAiResponse;
  int _todaysBurnCount = 0;

  String? _pickedImagePath;
  bool _shareToSquare = false;

  SquareSortType _sortType = SquareSortType.latest;
  SquareFilterPeriod _filterPeriod = SquareFilterPeriod.all;
  String? _selectedTag;

  int _firewoodCount = 3;
  int _waterCount = 3;

  List<PublicPost> _publicPosts = [];

  final List<PrivatePost> _privateHistory = [];

  final Set<String> _readPostIds = {}; // Track read posts
  final Set<String> _blockedUserIds = {}; // Blocked user IDs
  DateTime _selectedCalendarDate = DateTime.now();

  VentingViewModel() {
    _loadPrivateHistory();
    _loadReadPostIds(); // Load read state
    _loadBlockedUsers(); // Load blocked users
    _initFirebase();
  }

  Future<void> _loadReadPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? ids = prefs.getStringList('read_post_ids');
    if (ids != null) {
      _readPostIds.addAll(ids);
      notifyListeners();
    }
  }

  Future<void> markPostAsRead(String postId) async {
    if (!_readPostIds.contains(postId)) {
      _readPostIds.add(postId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_post_ids', _readPostIds.toList());
      notifyListeners();
    }
  }

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? ids = prefs.getStringList('blocked_user_ids');
    if (ids != null) {
      _blockedUserIds.addAll(ids);
      notifyListeners();
    }
  }

  Future<void> blockUser(String userId) async {
    if (!_blockedUserIds.contains(userId)) {
      _blockedUserIds.add(userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
      notifyListeners();
    }
  }

  bool isUserBlocked(String userId) {
    return _blockedUserIds.contains(userId);
  }

  // Admin / Settings functionality
  Set<String> get blockedUserIds => _blockedUserIds;

  Future<void> unblockUser(String userId) async {
    if (_blockedUserIds.contains(userId)) {
      _blockedUserIds.remove(userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
      notifyListeners();
    }
  }

  Future<void> unblockAllUsers() async {
    if (_blockedUserIds.isNotEmpty) {
      _blockedUserIds.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('blocked_user_ids');
      notifyListeners();
    }
  }

  final Set<String> _reportedPostIds = {};
  final Map<String, DateTime> _postInteractionTimestamps = {};

  Future<void> _loadInteractionLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? reported = prefs.getStringList('reported_post_ids');
    if (reported != null) {
      _reportedPostIds.addAll(reported);
    }

    final String? timestampsJson = prefs.getString('interaction_timestamps');
    if (timestampsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(timestampsJson);
      decoded.forEach((key, value) {
        _postInteractionTimestamps[key] = DateTime.parse(value);
      });
    }
  }

  Future<void> _saveInteractionLimits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reported_post_ids', _reportedPostIds.toList());

    final Map<String, String> encodedTimestamps = {};
    _postInteractionTimestamps.forEach((key, value) {
      encodedTimestamps[key] = value.toIso8601String();
    });
    await prefs.setString(
        'interaction_timestamps', jsonEncode(encodedTimestamps));
  }

  bool canInteract(String postId) {
    if (!_postInteractionTimestamps.containsKey(postId)) return true;
    final lastTime = _postInteractionTimestamps[postId]!;
    return DateTime.now().difference(lastTime) >= const Duration(minutes: 5);
  }

  Future<void> reportPost(
      String postId, String reason, String reporterId) async {
    if (_reportedPostIds.contains(postId)) {
      throw '이미 신고한 게시글입니다.'; // Throw exception for UI
    }

    try {
      await _firestore.collection('reports').add({
        'postId': postId,
        'reason': reason,
        'reporterId': reporterId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _reportedPostIds.add(postId);
      await _saveInteractionLimits();
      notifyListeners();
    } catch (e) {
      print("Error reporting post: $e");
      rethrow;
    }
  }

  bool isPostRead(String postId) {
    return _readPostIds.contains(postId);
  }

  Future<void> _initFirebase() async {
    await _signInAnonymously();
    _loadInteractionLimits(); // Load limits
    _subscribeToPosts();
  }

  Future<void> _signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      if (kDebugMode) {
        print("Firebase Auth Error: $e");
      }
    }
  }

  void _subscribeToPosts() {
    _firestore.collection('posts').snapshots().listen((snapshot) {
      print(
          'DEBUG: Firestore snapshot received. Docs count: ${snapshot.docs.length}');
      final List<PublicPost> posts = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          posts.add(PublicPost.fromMap(data));
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
        }
      }
      _publicPosts = posts;
      print('DEBUG: Parsed public posts count: ${_publicPosts.length}');
      notifyListeners();
    }, onError: (e) {
      print('Firestore stream error: $e');
    });
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

  VentingMode get currentMode => _currentMode;
  bool get isBurning => _isBurning;
  String? get lastAiResponse => _lastAiResponse;
  int get todaysBurnCount => _todaysBurnCount;

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
    print(
        'DEBUG: publicPosts getter called. Total: ${_publicPosts.length}, Filter: Period=$_filterPeriod, Tag=$_selectedTag, Blocked=${_blockedUserIds.length}');

    // Filter by tag
    if (_selectedTag != null && _selectedTag != '전체') {
      filteredList =
          filteredList.where((p) => p.tags.contains(_selectedTag)).toList();
    }

    // Filter blocked users
    if (_blockedUserIds.isNotEmpty) {
      print('DEBUG: Blocking users: $_blockedUserIds');
      filteredList = filteredList.where((p) {
        final isBlocked = _blockedUserIds.contains(p.authorId);
        if (isBlocked) {
          print('DEBUG: Post ${p.id} by ${p.authorId} blocked.');
        }
        return !isBlocked;
      }).toList();
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
    print('DEBUG: Filtered list count: ${filteredList.length}');
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

  void setPickedImagePath(String? path) {
    _pickedImagePath = path;
    notifyListeners();
  }

  void startBurning() {
    _isBurning = true;
    _lastAiResponse = null;
    notifyListeners();
  }

  Future<void> addFirewood(String postId) async {
    if (_firewoodCount <= 0) throw '장작이 부족합니다.';
    if (!canInteract(postId)) throw '5분 뒤에 다시 위로할 수 있습니다.';

    try {
      await _firestore.collection('posts').doc(postId).update({
        'supportCount': FieldValue.increment(1),
      });
      _firewoodCount--;

      _postInteractionTimestamps[postId] = DateTime.now();
      await _saveInteractionLimits();

      notifyListeners();
    } catch (e) {
      print("Error adding firewood: $e");
      rethrow;
    }
  }

  Future<void> addWater(String postId) async {
    if (_waterCount <= 0) throw '물방울이 부족합니다.';
    if (!canInteract(postId)) throw '5분 뒤에 다시 위로할 수 있습니다.';

    try {
      await _firestore.collection('posts').doc(postId).update({
        'comfortCount': FieldValue.increment(1),
      });
      _waterCount--;

      _postInteractionTimestamps[postId] = DateTime.now();
      await _saveInteractionLimits();

      notifyListeners();
    } catch (e) {
      print("Error adding water: $e");
      rethrow;
    }
  }

  Future<void> addComment(
      String postId, String nickname, String content, String authorId) async {
    try {
      final comment = PublicComment(
        authorId: authorId,
        nickname: nickname,
        content: content,
        timestamp: DateTime.now(),
      );
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([comment.toMap()]),
      });
    } catch (e) {
      print("Error adding comment: $e");
    }
  }

  String? validateContent(String text) {
    // 욕설 필터링 제거: 시원하게 욕해도 되는 컨셉
    return null;
  }

  void finishBurning(
      Persona persona, String text, String userId, String nickname,
      {double? angerLevel, String? manualTag}) async {
    final extractedTags = _extractTags(text, manualTag: manualTag);
    final now = DateTime.now();
    String postId = now.millisecondsSinceEpoch.toString();

    PublicPost? newPublicPost;

    if (_shareToSquare) {
      final docRef = _firestore.collection('posts').doc();
      postId = docRef.id;

      newPublicPost = PublicPost(
        id: postId,
        authorNickname: nickname,
        content: text,
        angerLevel: angerLevel ?? 50,
        timestamp: now,
        imagePath: _pickedImagePath,
        tags: extractedTags,
        fontName: '나눔 펜 (손글씨)', // Default or pass font name if needed
        authorLevel:
            1, // Default or pass level if crucial, but display uses local usually
        authorId: userId,
      );
      await docRef.set(newPublicPost.toMap());
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
    // Rewards handled in UI (HomeScreen) based on text length
    notifyListeners();

    // AI 위로는 광장 공유하지 않는 글에만 제공
    if (!_shareToSquare) {
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
    }

    notifyListeners();
  }

  static const Map<String, List<String>> keywordMap = {
    '직장': ['회사', '상사', '업무', '야근', '출근', '퇴근', '동료', '월급'],
    '관계': ['친구', '싸움', '오해', '절교', '비난', '모임'],
    '일상': ['교통', '지하철', '날씨', '점심', '피곤'],
    '연애': ['이별', '다툼', '서운', '짝사랑'],
    '건강': ['아픔', '스트레스', '불면', '운동'],
  };

  List<String> get availableTags => keywordMap.keys.toList();

  List<String> _extractTags(String content, {String? manualTag}) {
    final List<String> tags = [];

    // 1. Manual Tag Priority
    if (manualTag != null && manualTag != '자동') {
      tags.add(manualTag);
      return tags; // If manual tag is selected, use only that one (or you can add others too)
    }

    // 2. Auto Extraction
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

  Future<void> editPost(String postId, String newContent) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'content': newContent,
        'lastModified': DateTime.now()
            .toIso8601String(), // Store as string if possible or update PublicPost.fromMap to handle Timestamp
      });
      // PublicPost.fromMap handles String for lastModified based on current code: DateTime.parse(map['lastModified'])
      // So we should save ISO String.
    } catch (e) {
      print("Error editing post: $e");
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print("Error deleting post: $e");
    }
  }

  // Not implemented in MVP for nested deep interactions on arrays
  // Recursive Helper to find and update comment
  bool _findAndUpdateComment(List<dynamic> comments, String targetId,
      Function(Map<String, dynamic>) updateAction) {
    for (var i = 0; i < comments.length; i++) {
      Map<String, dynamic> comment = comments[i];
      if (comment['id'] == targetId) {
        updateAction(comment);
        comments[i] = comment; // Save back
        return true;
      }
      // Recursive check replies
      if (comment['replies'] != null) {
        List<dynamic> replies = comment['replies'];
        if (_findAndUpdateComment(replies, targetId, updateAction)) {
          comment['replies'] = replies; // Save back updated replies
          comments[i] = comment;
          return true;
        }
      }
    }
    return false;
  }

  Future<void> addReplyToComment(String postId, String parentCommentId,
      String nickname, String content, String authorId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      List<dynamic> commentsData = List.from(data['comments'] ?? []);

      bool found =
          _findAndUpdateComment(commentsData, parentCommentId, (targetComment) {
        List<dynamic> replies = targetComment['replies'] ?? [];
        replies.add(PublicComment(
          authorId: authorId,
          nickname: nickname,
          content: content,
          timestamp: DateTime.now(),
        ).toMap());
        targetComment['replies'] = replies;
      });

      if (found) {
        transaction.update(postRef, {'comments': commentsData});
      }
    });
  }

  Future<bool> addFirewoodToComment(String postId, String commentId) async {
    if (_firewoodCount <= 0) return false;
    final postRef = _firestore.collection('posts').doc(postId);
    bool success = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      List<dynamic> commentsData =
          List.from(snapshot.data()!['comments'] ?? []);

      bool found =
          _findAndUpdateComment(commentsData, commentId, (targetComment) {
        targetComment['supportCount'] =
            (targetComment['supportCount'] ?? 0) + 1;
      });

      if (found) {
        transaction.update(postRef, {'comments': commentsData});
        success = true;
      }
    });

    if (success) {
      _firewoodCount--;
      notifyListeners();
      return true;
    }
    return false;
  }

  void gainItems() {
    _firewoodCount++;
    _waterCount++;
    notifyListeners();
  }

  Future<Map<String, int>> getMyInteractionStats(String userId) async {
    int totalFirewood = 0;
    int totalWater = 0;

    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        totalFirewood += (data['supportCount'] as int? ?? 0);
        totalWater += (data['comfortCount'] as int? ?? 0);
      }
    } catch (e) {
      print("Error fetching stats: $e");
    }

    return {
      'firewood': totalFirewood,
      'water': totalWater,
    };
  }

  Future<bool> addWaterToComment(String postId, String commentId) async {
    if (_waterCount <= 0) return false;
    final postRef = _firestore.collection('posts').doc(postId);
    bool success = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      List<dynamic> commentsData =
          List.from(snapshot.data()!['comments'] ?? []);

      bool found =
          _findAndUpdateComment(commentsData, commentId, (targetComment) {
        targetComment['comfortCount'] =
            (targetComment['comfortCount'] ?? 0) + 1;
      });

      if (found) {
        transaction.update(postRef, {'comments': commentsData});
        success = true;
      }
    });

    if (success) {
      _waterCount--;
      notifyListeners();
      return true;
    }
    return false;
  }

  PublicPost? getPublicPost(String id) {
    try {
      return _publicPosts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearAiResponse() {
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _privateHistory.clear();
    _readPostIds.clear();
    _blockedUserIds.clear();
    _reportedPostIds.clear();
    _postInteractionTimestamps.clear();

    _firewoodCount = 3;
    _waterCount = 3;
    _todaysBurnCount = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('private_history');
    await prefs.remove('read_post_ids');
    await prefs.remove('blocked_user_ids');
    await prefs.remove('reported_post_ids');
    await prefs.remove('interaction_timestamps');

    notifyListeners();
  }
}
