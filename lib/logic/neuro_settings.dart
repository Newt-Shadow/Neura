import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;

class NeuroSettings extends ChangeNotifier {
  // ============================================================
  // 🔐 SECURITY
  // ============================================================

  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final enc.Key _encKey =
      enc.Key.fromUtf8('NeuroAppSecureKey123456789012345'); // 32 chars
  final enc.IV _iv = enc.IV.fromLength(16);

  // ============================================================
  // 👤 STATE
  // ============================================================

  String _userApiKey = "";
  Map<String, String> _profile = {};
  List<Map<String, String>> _history = [];
  int _streakCount = 0;

  double _energyLevel = 0.5;
  bool _isOverwhelmed = false;

  bool _isLoading = false;

  bool _useLocalModel = false;

  // ============================================================
  // 📦 GETTERS
  // ============================================================

  String get userApiKey => _userApiKey;
  int get streakCount => _streakCount;
  bool get isLoading => _isLoading;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get userName => _profile['name'] ?? "Friend";
  String get disabilityType => _profile['diagnosis'] ?? "ADHD";
  String get sensoryTriggers => _profile['sensory'] ?? "None";
  String get executiveStruggle =>
      _profile['struggle'] ?? "Task Paralysis";
  String get interest => _profile['interest'] ?? "Focus";
  String get preferredLanguage =>
      _profile['language'] ?? "English";
  

  bool get dyslexiaMode => _profile['font'] == 'dyslexic';
  bool get useDyslexicFont => dyslexiaMode;
  bool get highContrast => _profile['contrast'] == 'high';

  String? get fontFamily =>
      dyslexiaMode ? 'OpenDyslexic' : 'Lexend';

  double get energyLevel => _energyLevel;
  bool get isOverwhelmed => _isOverwhelmed;

  String get diagnosis => disabilityType;
  String get sensorySensitivities => sensoryTriggers;
  bool get useLocalModel => _useLocalModel;

  List<Map<String, String>> get history => _history;

  // ============================================================
  // 🚀 INITIALIZATION
  // ============================================================

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔑 API KEY LOAD ORDER:
    // 1. Secure Storage
    // 2. .env fallback
    final storedKey =
        await _secureStorage.read(key: "gemini_api_key");

    final envKey = dotenv.env['GEMINI_API_KEY'];

    _userApiKey =
        (storedKey != null && storedKey.isNotEmpty)
            ? storedKey
            : (envKey ?? "");

    if (_userApiKey.isEmpty) {
      debugPrint("⚠ GEMINI_API_KEY NOT FOUND");
    } else {
      debugPrint("✅ GEMINI KEY LOADED");
    }

    // Load profile
    final profileJson =
        prefs.getString('local_profile');
    if (profileJson != null) {
      _profile =
          Map<String, String>.from(json.decode(profileJson));
    }

    // Load history
    

    _useLocalModel = prefs.getBool('use_local_model') ?? false;
    _streakCount = prefs.getInt('streak') ?? 0;
    _energyLevel =
        prefs.getDouble('energy_level') ?? 0.5;
    _isOverwhelmed =
        prefs.getBool('is_overwhelmed') ?? false;

    final historyJson =
        prefs.getString('local_history');
    if (historyJson != null) {
      final raw = json.decode(historyJson) as List;
      _history =
          raw.map((e) => Map<String, String>.from(e)).toList();
    }

    // Auto sync on login
    FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
      if (user != null) {
        _syncFromCloud();
      }
    });

    notifyListeners();
  }

  // ============================================================
  // 🔑 API KEY
  // ============================================================

  Future<void> setApiKey(String key) async {
    _userApiKey = key;
    await _secureStorage.write(
        key: "gemini_api_key", value: key);
    notifyListeners();
  }

  // ============================================================
  // 🧠 ENERGY
  // ============================================================

  void setEnergy(double value) async {
    _energyLevel = value;
    final prefs =
        await SharedPreferences.getInstance();
    await prefs.setDouble('energy_level', value);
    notifyListeners();
  }

  void setOverwhelm(bool value) async {
    _isOverwhelmed = value;
    final prefs =
        await SharedPreferences.getInstance();
    await prefs.setBool('is_overwhelmed', value);
    notifyListeners();
  }

  // 🆕 Toggle Local LLM
  void toggleLocalModel(bool value) async {
    _useLocalModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_local_model', value);
    notifyListeners();
  }

  // ============================================================
  // 👤 PROFILE
  // ============================================================

  void saveProfile({
    required String name,
    required String diagnosis,
    required String sensory,
    required String language,
    String? struggle,
    String? interest,
  }) {
    final newMap = {
      ..._profile,
      'name': name,
      'diagnosis': diagnosis,
      'sensory': sensory,
      'language': language,
      if (struggle != null) 'struggle': struggle,
      if (interest != null) 'interest': interest,
    };
    
    updateProfile(newMap);
  }

  void updateProfile(
      Map<String, String> updates) {
    _profile.addAll(updates);
    notifyListeners();
    _saveToLocal();
    _saveToCloud();
    
  }

  void toggleFont() {
    updateProfile({
      'font': (_profile['font'] == 'dyslexic')
          ? 'standard'
          : 'dyslexic',
    });
  }

  void toggleContrast() {
    updateProfile({
      'contrast': (_profile['contrast'] == 'high')
          ? 'standard'
          : 'high',
    });
  }

  void incrementStreak() {
    _streakCount++;
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  // ============================================================
  // 💬 HISTORY
  // ============================================================

  void addToHistory(String role, String text) {
    if (_history.length > 100) {
      _history.removeAt(0);
    }

    _history.add({
      'role': role,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _history.clear();
    _profile.clear();
    _streakCount = 0;

    final prefs =
        await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  // ============================================================
  // ☁️ CLOUD SYNC
  // ============================================================

  Future<void> _syncFromCloud() async {
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
if (_profile.isEmpty) {
             if (data.containsKey('encrypted_profile')) {
                _profile = _decryptMap(data['encrypted_profile']);
                print("☁️ Downloaded Profile from Cloud");
             }
             if (data.containsKey('streak')) {
                _streakCount = data['streak'];
             }
             _saveToLocal(); // Update local cache
             notifyListeners();
        } else {
          // Local has data -> Push to Cloud (Trust Local)
          print("☁️ Local data found. Syncing UP to Cloud.");
          _saveToCloud();
        }
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
  }

  Future<void> _saveToCloud() async {
    if (currentUser == null) return;
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final encryptedProfile = encrypter.encrypt(json.encode(_profile), iv: _iv).base64;

      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'encrypted_profile': encryptedProfile,
        'streak': _streakCount,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print("☁️ Saved Profile to Cloud");
    } catch (e) {
      debugPrint("Cloud Save Error: $e");
    }
  }

  // ============================================================
  // 💾 LOCAL SAVE
  // ============================================================

  Future<void> _saveToLocal() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
        'local_profile', json.encode(_profile));

    await prefs.setString(
        'local_history', json.encode(_history));

    await prefs.setInt('streak', _streakCount);
    print("💾 Settings Saved Locally: $_profile");  
  }

  // ============================================================
  // 🔐 CRYPTO
  // ============================================================

  Map<String, String> _decryptMap(
      String base64String) {
    try {
      final encrypter =
          enc.Encrypter(enc.AES(_encKey));
      final decrypted =
          encrypter.decrypt64(base64String, iv: _iv);
      return Map<String, String>.from(
          json.decode(decrypted));
    } catch (_) {
      return {};
    }
  }

  List<dynamic> _decryptList(
      String base64String) {
    try {
      final encrypter =
          enc.Encrypter(enc.AES(_encKey));
      final decrypted =
          encrypter.decrypt64(base64String, iv: _iv);
      return json.decode(decrypted)
          as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // 🧾 PROFILE STRING FOR PROMPT
  // ============================================================

  String generateProfileString() {
    return """
USER PROFILE:
- Name: $userName
- Diagnosis: $disabilityType
- Struggle: $executiveStruggle
- Sensory: $sensoryTriggers
- Interest: $interest
""";
  }

  // ============================================================
  // 🔐 AUTH
  // ============================================================

  Future<User?> signInWithGoogle() async {
    try {
      _setLoading(true);

      final googleUser =
          await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return null;
      }

      final googleAuth =
          await googleUser.authentication;

      final credential =
          GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(credential);

      await _syncFromCloud();

      _setLoading(false);
      return userCredential.user;
    } catch (_) {
      _setLoading(false);
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
