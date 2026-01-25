import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:math' as math; // Import math

enum Persona {
  fighter, // 전투형
  empathy, // 공감형
  factBomb, // 팩폭형
  humor // 유머형
}

class UserViewModel with ChangeNotifier {
  String? _nickname;
  String? _uuid; // Unique User ID
  String? _pin;
  Persona _selectedPersona = Persona.empathy;
  int _totalBurnCount = 0; // Legacy counter, kept for stats

  // New Point System
  int _writingPoints = 0;
  int _receivedPoints = 0;

  bool _isLoggedIn = false;
  bool _isBgmOn = true;
  bool _isSfxOn = true;
  bool _isVibrationOn = true;
  bool _isBiometricEnabled = false;
  String _selectedFont = '푸어 스토리 (동화책)';
  bool _isAdmin = false;
  int _dailyComfortCount = 5;
  String? _lastLoginDate;

  // New: Default Persona (String based to avoid Enum issues if expanded)
  String _defaultPersonaStr = '전투'; // Default to Fighter

  final LocalAuthentication auth = LocalAuthentication();

  // Getters
  String? get nickname => _nickname;
  String? get userId => _uuid;
  Persona get selectedPersona => _selectedPersona;
  bool get isLoggedIn => _isLoggedIn;
  int get totalBurnCount => _totalBurnCount;
  bool get isBgmOn => _isBgmOn;
  bool get isSfxOn => _isSfxOn;
  bool get isVibrationOn => _isVibrationOn;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get selectedFont => _selectedFont;
  bool get isAdmin => _isAdmin;

  int get dailyComfortCount => _dailyComfortCount;
  String get defaultPersonaStr => _defaultPersonaStr;

  // Point System Logic
  int get writingPoints => _writingPoints;
  int get receivedPoints => _receivedPoints;
  int get totalPoints => _writingPoints + _receivedPoints;

  // Level Logic (Piecewise)
  // Lv 1-10: Linear (10 XP per level). Total XP for Lv 11 start is 100.
  // Lv 11+: Quadratic.
  int get level {
    if (totalPoints < 100) {
      // Linear phase: 0-9 -> Lv 1, 10-19 -> Lv 2, ..., 90-99 -> Lv 10
      return (totalPoints / 10).floor() + 1;
    } else {
      int lvl = 10 + (math.sqrt((totalPoints - 100) / 5)).floor();
      return lvl > 50 ? 50 : lvl;
    }
  }

  double get levelProgress {
    int currentLvl = level;
    if (currentLvl >= 50) return 1.0;

    int currentLvlStartXP;
    int nextLvlStartXP;

    if (currentLvl < 10) {
      currentLvlStartXP = (currentLvl - 1) * 10;
      nextLvlStartXP = currentLvl * 10;
    } else if (currentLvl == 10) {
      currentLvlStartXP = 90;
      nextLvlStartXP = 100;
    } else {
      currentLvlStartXP = _getLevelStartXP(currentLvl);
      nextLvlStartXP = _getLevelStartXP(currentLvl + 1);
    }

    if (nextLvlStartXP <= currentLvlStartXP) return 1.0;
    return (totalPoints - currentLvlStartXP) /
        (nextLvlStartXP - currentLvlStartXP);
  }

  int _getLevelStartXP(int lvl) {
    if (lvl <= 11) return (lvl - 1) * 10;
    return 100 + 10 * (lvl - 11) * (lvl - 11);
  }

  String get expString {
    int currentLvl = level;
    if (currentLvl >= 50) return "MAX";

    int nextStart = _getLevelStartXP(currentLvl + 1);
    return "$totalPoints / $nextStart";
  }

  int get remainingXP {
    int currentLvl = level;
    if (currentLvl >= 50) return 0;
    int nextStart = _getLevelStartXP(currentLvl + 1);
    return nextStart - totalPoints;
  }

  // Backward compatibility alias
  int get expProgress => 0;

  UserViewModel() {
    // Constructor
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('nickname');
    _uuid = prefs.getString('user_uuid');
    if (_uuid == null) {
      _uuid = _generateUuid();
      await prefs.setString('user_uuid', _uuid!);
    }
    _pin = prefs.getString('pin');
    _totalBurnCount = prefs.getInt('total_burn_count') ?? 0;
    _writingPoints = prefs.getInt('writing_points') ?? 0; // Load writing points

    final personaIndex = prefs.getInt('persona_index') ?? 1;
    _selectedPersona = Persona.values[personaIndex];
    _isBgmOn = prefs.getBool('isBgmOn') ?? true;
    _isSfxOn = prefs.getBool('isSfxOn') ?? true;
    _isVibrationOn = prefs.getBool('isVibrationOn') ?? true;
    _isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;

    _selectedFont = prefs.getString('selectedFont') ?? '나눔 펜 (손글씨)';
    _defaultPersonaStr = prefs.getString('default_persona_str') ?? '전투';

    _isLoggedIn = _nickname != null;
    _isAdmin = prefs.getBool('is_admin') ?? false;

    _dailyComfortCount = prefs.getInt('daily_comfort_count') ?? 5;
    _lastLoginDate = prefs.getString('last_login_date');
    await _checkDailyLogin(prefs);

    notifyListeners();
  }

  bool _justRecharged = false;

  Future<void> _checkDailyLogin(SharedPreferences prefs) async {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    if (_lastLoginDate != todayStr) {
      if (_lastLoginDate != null) {
        _dailyComfortCount += 10; // Recharge 10
        _justRecharged = true; // Set flag
      } else {
        // First login ever - maybe give some initial bonus? Current logic does nothing specific.
        // Let's give initial 10 too? No, keep existing behavior or as requested.
        // User said: "When logging in every day... today's hearts are recharged".
        // Usually first install starts with 5 (default). Let's stick to update logic for existing users.
      }

      _lastLoginDate = todayStr;
      await prefs.setString('last_login_date', todayStr);
      await prefs.setInt('daily_comfort_count', _dailyComfortCount);
    }
  }

  bool get isJustRecharged => _justRecharged;

  void consumeRechargeFlag() {
    _justRecharged = false;
    // notifyListeners(); // Not strictly needed if consumed in build, but good practice.
    // However, calling notifyListeners during build might error.
  }

  Future<bool> consumeComfortCount() async {
    if (_dailyComfortCount > 0) {
      _dailyComfortCount--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_comfort_count', _dailyComfortCount);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> addComfortCounts(int amount) async {
    _dailyComfortCount += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_comfort_count', _dailyComfortCount);
    notifyListeners();
  }

  Future<bool> verifyAdminPassword(String input) async {
    const adminPassword = "admin1234";
    if (input == adminPassword) {
      _isAdmin = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin', true);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Point Methods
  Future<void> addWritingPoints(int amount) async {
    _writingPoints += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('writing_points', _writingPoints);
    notifyListeners();
  }

  // Only called by UI when fetching remote stats
  void updateReceivedPoints(int points) {
    if (_receivedPoints != points) {
      _receivedPoints = points;
    }
  }

  // Deprecated/Alias for backward compat (used in simple burn)
  Future<void> addPoints(int amount) async {
    await addWritingPoints(amount);
  }

  Future<void> incrementBurnCount() async {
    _totalBurnCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_burn_count', _totalBurnCount);
    notifyListeners();
  }

  Future<void> setNickname(String name) async {
    _nickname = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', name);
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _pin = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin', pin);
    notifyListeners();
  }

  Future<void> setPersona(Persona persona) async {
    _selectedPersona = persona;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('persona_index', persona.index);
    notifyListeners();
  }

  Future<void> setDefaultPersona(String personaStr) async {
    _defaultPersonaStr = personaStr;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_persona_str', personaStr);
    notifyListeners();
  }

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> toggleBgm(bool value) async {
    _isBgmOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBgmOn', value);
    notifyListeners();
  }

  Future<void> toggleSfx(bool value) async {
    _isSfxOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSfxOn', value);
    notifyListeners();
  }

  Future<void> toggleVibration(bool value) async {
    _isVibrationOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isVibrationOn', value);
    notifyListeners();
  }

  Future<void> toggleBiometric(bool value) async {
    _isBiometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBiometricEnabled', value);
    notifyListeners();
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: '앱에 로그인하려면 인증해주세요.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric Auth Error: $e');
      return false;
    }
  }

  Future<void> setFont(String fontName) async {
    _selectedFont = fontName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedFont', fontName);
    notifyListeners();
  }

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'user_${now}_$random';
  }

  Future<void> resetAllData() async {
    _nickname = null;
    _pin = null;
    _selectedPersona = Persona.empathy;
    _isBgmOn = true;
    _isSfxOn = true;
    _isVibrationOn = true;
    _isBiometricEnabled = false;
    _totalBurnCount = 0;
    _writingPoints = 0;
    _receivedPoints = 0;
    _selectedFont = '나눔 펜 (손글씨)';
    _isAdmin = false;
    _dailyComfortCount = 5;
    _lastLoginDate = null;
    _defaultPersonaStr = '전투';

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}
