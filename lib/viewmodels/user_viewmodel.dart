import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? get nickname => _nickname;
  Persona get selectedPersona => _selectedPersona;
  bool get isLoggedIn => _isLoggedIn;
  int get totalBurnCount => _totalBurnCount;
  int get level => (_totalBurnCount / 5).floor() + 1; // Level up Every 5 burns
  int get expProgress => _totalBurnCount % 5;

  UserViewModel() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('nickname');
    _pin = prefs.getString('pin');
    _totalBurnCount = prefs.getInt('total_burn_count') ?? 0;
    final personaIndex = prefs.getInt('persona_index') ?? 1;
    _selectedPersona = Persona.values[personaIndex];
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
}
