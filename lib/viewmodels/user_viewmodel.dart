import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

enum Persona {
  fighter, // 전투형
  empathy, // 공감형
  factBomb, // 팩폭형
  humor // 유머형
}

class UserViewModel with ChangeNotifier {
  String? _nickname;
  String? _pin;
  Persona _selectedPersona = Persona.empathy;
  int _totalBurnCount = 0;
  bool _isLoggedIn = false;
  bool _isBgmOn = true;
  bool _isSfxOn = true;
  bool _isVibrationOn = true;
  bool _isBiometricEnabled = false;
  String _selectedFont = '나눔 펜 (손글씨)'; // Default font

  final LocalAuthentication auth = LocalAuthentication();

  String? get nickname => _nickname;
  Persona get selectedPersona => _selectedPersona;
  bool get isLoggedIn => _isLoggedIn;
  int get totalBurnCount => _totalBurnCount;
  int get level => (_totalBurnCount / 5).floor() + 1; // Level up Every 5 burns
  int get expProgress => _totalBurnCount % 5;
  bool get isBgmOn => _isBgmOn;
  bool get isSfxOn => _isSfxOn;
  bool get isVibrationOn => _isVibrationOn;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get selectedFont => _selectedFont;

  UserViewModel() {
    // Constructor no longer automatically loads data.
    // Explicit call required via loadUserData()
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('nickname');
    _pin = prefs.getString('pin');
    _totalBurnCount = prefs.getInt('total_burn_count') ?? 0;
    final personaIndex = prefs.getInt('persona_index') ?? 1;
    _selectedPersona = Persona.values[personaIndex];
    _isBgmOn = prefs.getBool('isBgmOn') ?? true;
    _isSfxOn = prefs.getBool('isSfxOn') ?? true;
    _isVibrationOn = prefs.getBool('isVibrationOn') ?? true;
    _isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;
    _selectedFont = prefs.getString('selectedFont') ?? '나눔 펜 (손글씨)';
    _isLoggedIn = _nickname != null;
    notifyListeners();
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
}
