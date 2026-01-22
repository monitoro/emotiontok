import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  List<PublicPost> _publicPosts = [];

  final List<PrivatePost> _privateHistory = [];
  DateTime _selectedCalendarDate = DateTime.now();

  VentingViewModel() {
    _loadPrivateHistory();
    // _loadPublicPosts(); // Local persistence replaced by Firestore
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    await _signInAnonymously();
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
      _publicPosts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID matches Document ID
        return PublicPost.fromMap(data);
      }).toList();
      notifyListeners();
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

  Future<bool> addFirewood(String postId) async {
    if (_firewoodCount <= 0) return false;
    try {
      await _firestore.collection('posts').doc(postId).update({
        'supportCount': FieldValue.increment(1),
      });
      _firewoodCount--;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error adding firewood: $e");
      return false;
    }
  }

  Future<bool> addWater(String postId) async {
    if (_waterCount <= 0) return false;
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comfortCount': FieldValue.increment(1),
      });
      _waterCount--;
      notifyListeners();
      return true;
    } catch (e) {
      print("Error adding water: $e");
      return false;
    }
  }

  Future<void> addComment(
      String postId, String nickname, String content) async {
    try {
      final comment = PublicComment(
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

  void finishBurning(Persona persona, String text, UserViewModel userVM,
      {double? angerLevel}) async {
    final extractedTags = _extractTags(text);
    final now = DateTime.now();
    String postId = now.millisecondsSinceEpoch.toString();

    PublicPost? newPublicPost;

    if (_shareToSquare) {
      final docRef = _firestore.collection('posts').doc();
      postId = docRef.id;

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
    if (_shareToSquare && newPublicPost != null && response.isNotEmpty) {
      final aiComment = PublicComment(
        nickname: '마음이 (${_getPersonaName(persona)})',
        content: response,
        timestamp: DateTime.now(),
      );

      try {
        await _firestore.collection('posts').doc(postId).update({
          'comments': FieldValue.arrayUnion([aiComment.toMap()]),
        });
      } catch (e) {
        print("Error adding AI comment: $e");
      }
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
  Future<bool> addFirewoodToComment(String postId, int commentIndex) async {
    // requires reading doc, modifying array, writing back.
    return false;
  }

  Future<bool> addWaterToComment(String postId, int commentIndex) async {
    // requires reading doc, modifying array, writing back.
    return false;
  }

  Future<void> addReply(
      String postId, int commentIndex, String nickname, String content) async {
    final postRef = _firestore.collection('posts').doc(postId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      // Need to parse comments properly
      // This is a bit risky if data structure changes, but assuming strict map adherence:
      List<dynamic> commentsData = data['comments'] ?? [];
      if (commentIndex < commentsData.length) {
        Map<String, dynamic> targetComment = commentsData[commentIndex];
        List<dynamic> replies = targetComment['replies'] ?? [];

        replies.add(PublicComment(
                nickname: nickname, content: content, timestamp: DateTime.now())
            .toMap());

        targetComment['replies'] = replies;
        commentsData[commentIndex] = targetComment;

        transaction.update(postRef, {'comments': commentsData});
      }
    });
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
