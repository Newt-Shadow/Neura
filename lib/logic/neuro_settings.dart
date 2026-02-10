import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;

class NeuroSettings extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  
  // --- HARDCODE KEY HERE (As requested) ---
  static const String _hardcodedKey = "YOUR_GEMINI_API_KEY_HERE"; 

  // Encryption
  final _encKey = enc.Key.fromUtf8('MySecretKeyForNeuroApp1234567890');
  final _iv = enc.IV.fromLength(16);

  // State
  String _userApiKey = "";
  Map<String, String> _profile = {};
  List<Map<String, String>> _history = [];
  int _streakCount = 0;

  // --- GETTERS ---
  String get userApiKey => _userApiKey;
  int get streakCount => _streakCount;
  List<Map<String, String>> get history => _history;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get userName => _profile['name'] ?? "Friend";
  String get diagnosis => _profile['diagnosis'] ?? "";
  String get sensorySensitivities => _profile['sensory'] ?? "";
  String get preferredLanguage => _profile['language'] ?? "English";
  
  bool get useDyslexicFont => _profile['font'] == 'dyslexic';
  bool get highContrast => _profile['contrast'] == 'high';
  double get taskGranularity => double.tryParse(_profile['granularity'] ?? "1.0") ?? 1.0;

  // *** THIS FIXES YOUR MAIN.DART ERROR ***
  String? get fontFamily => useDyslexicFont ? 'OpenDyslexic' : null;

  // --- INIT ---
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Key (Prioritize saved, fallback to hardcoded)
    String? savedKey = await _storage.read(key: "gemini_api_key");
    if (savedKey != null && savedKey.isNotEmpty) {
      _userApiKey = savedKey;
    } else {
      _userApiKey = _hardcodedKey;
    }
    
    // 2. Load Local Data
    _streakCount = prefs.getInt('streak') ?? 0;
    String? localProfile = prefs.getString('local_profile');
    if (localProfile != null) _profile = Map<String, String>.from(json.decode(localProfile));
    
    String? localHistory = prefs.getString('local_history');
    if (localHistory != null) {
      List<dynamic> raw = json.decode(localHistory);
      _history = raw.map((e) => Map<String, String>.from(e)).toList();
    }

    if (currentUser != null) await _syncFromCloud();
    notifyListeners();
  }

  // --- UI ACTIONS ---
  void saveProfile({required String name, required String diagnosis, required String sensory, required String language}) {
    updateProfile({'name': name, 'diagnosis': diagnosis, 'sensory': sensory, 'language': language});
  }

  void toggleFont() {
    updateProfile({'font': (_profile['font'] == 'dyslexic') ? 'standard' : 'dyslexic'});
  }

  void toggleContrast() {
    updateProfile({'contrast': (_profile['contrast'] == 'high') ? 'standard' : 'high'});
  }

  void setGranularity(double val) {
    updateProfile({'granularity': val.toString()});
  }

  void incrementStreak() {
    _streakCount++;
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  // --- CORE DATA LOGIC ---
  void updateProfile(Map<String, String> updates) {
    _profile.addAll(updates);
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  void addToHistory(String role, String text) {
    if (_history.length > 50) _history.removeAt(0);
    _history.add({'role': role, 'text': text, 'timestamp': DateTime.now().toIso8601String()});
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _userApiKey = key;
    await _storage.write(key: "gemini_api_key", value: key);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    // Implement Firebase Auth Logic Here
    if (currentUser != null) await _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('encrypted_profile')) _profile = _decryptMap(data['encrypted_profile']);
        if (data.containsKey('streak')) _streakCount = data['streak'];
        _saveToLocal();
        notifyListeners();
      }
    } catch (e) { print("Sync Error: $e"); }
  }

  Future<void> _saveToCloud() async {
    if (currentUser == null) return;
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      String encryptedProfile = encrypter.encrypt(json.encode(_profile), iv: _iv).base64;
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'encrypted_profile': encryptedProfile,
        'streak': _streakCount,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) { print("Cloud Save Error: $e"); }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_profile', json.encode(_profile));
    await prefs.setString('local_history', json.encode(_history));
    await prefs.setInt('streak', _streakCount);
  }

  Map<String, String> _decryptMap(String base64String) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final decrypted = encrypter.decrypt64(base64String, iv: _iv);
      return Map<String, String>.from(json.decode(decrypted));
    } catch (e) { return {}; }
  }

  String generateProfileString() {
    StringBuffer sb = StringBuffer();
    if (_profile.isNotEmpty) {
      sb.writeln("USER PROFILE:");
      _profile.forEach((k, v) => sb.writeln("- $k: $v"));
    }
    return sb.toString();
  }
}