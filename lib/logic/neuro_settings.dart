import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // REQUIRED
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NeuroSettings extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  List<Map<String, String>> _chatHistory = [];
  List<Map<String, String>> _taskHistory = [];

  List<Map<String, String>> get chatHistory => _chatHistory;
  List<Map<String, String>> get taskHistory => _taskHistory;
  void addToChatHistory(String role, String text) {
    if (_chatHistory.length > 50) _chatHistory.removeAt(0);
    _chatHistory.add({'role': role, 'text': text, 'timestamp': DateTime.now().toIso8601String()});
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  void addToTaskHistory(String role, String text) {
    if (_taskHistory.length > 20) _taskHistory.removeAt(0);
    _taskHistory.add({'role': role, 'text': text, 'timestamp': DateTime.now().toIso8601String()});
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  // --- HARDCODE KEY HERE (Fallback) ---
  // --- HARDCODE KEY HERE (Fallback) ---
  // Runtime-loaded fallback API key (from .env)
  static String? _envApiKey;

  // Encryption Configuration
  final _encKey = enc.Key.fromUtf8(
    'MySecretKeyForNeuroApp1234567890',
  ); // 32 chars
  final _iv = enc.IV.fromLength(16);

  // State
  String _userApiKey = "";
  Map<String, String> _profile = {};
  List<Map<String, String>> _history = [];
  int _streakCount = 0;
  bool _isLoading = false;

  // --- GETTERS ---
  String get userApiKey => _userApiKey;
  int get streakCount => _streakCount;
  List<Map<String, String>> get history => _history;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isLoading => _isLoading;

  String get userName => _profile['name'] ?? "Friend";
  String get diagnosis => _profile['diagnosis'] ?? "";
  String get sensorySensitivities => _profile['sensory'] ?? "";
  String get preferredLanguage => _profile['language'] ?? "English";

  bool get useDyslexicFont => _profile['font'] == 'dyslexic';
  bool get highContrast => _profile['contrast'] == 'high';
  double get taskGranularity =>
      double.tryParse(_profile['granularity'] ?? "1.0") ?? 1.0;
  String? get fontFamily => useDyslexicFont ? 'OpenDyslexic' : null;

  // --- INIT ---
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedKey = await _storage.read(key: "gemini_api_key");

    // 1. Load API Key
    _envApiKey ??= dotenv.env['GEMINI_API_KEY'];
    _userApiKey = (savedKey != null && savedKey.isNotEmpty)
        ? savedKey
        : (_envApiKey ?? "");

    if (_userApiKey.isEmpty) {
      debugPrint("⚠️ GEMINI_API_KEY missing");
    }

    // 2. Load Local Data (Guest Mode)
    _streakCount = prefs.getInt('streak') ?? 0;
    String? localProfile = prefs.getString('local_profile');
    if (localProfile != null) _profile = Map<String, String>.from(json.decode(localProfile));

    _chatHistory = _loadSanitizedList(prefs.getString('local_chat_history'));
    _taskHistory = _loadSanitizedList(prefs.getString('local_task_history'));

    String? localHistory = prefs.getString('local_history');
    if (localHistory != null) {
      List<dynamic> raw = json.decode(localHistory);
      _history = raw.map((e) => Map<String, String>.from(e)).toList();
    }

    // 3. Listen to Auth Changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _syncFromCloud(); // Auto-sync on login
      }
      notifyListeners();
    });
  }

  List<Map<String, String>> _loadSanitizedList(String? jsonString) {
    if (jsonString == null) return [];
    try {
      final List<dynamic> raw = json.decode(jsonString);
      return raw.map((e) {
        // Ensure strictly Map<String, String> and no nulls
        final map = Map<String, String>.from(e);
        if (map['role'] == null || map['text'] == null) return null;
        return map;
      }).whereType<Map<String, String>>().toList();
    } catch (e) {
      print("Found corrupted history, discarding: $e");
      return [];
    }
  }

  Future<void> clearAllData() async {
    _chatHistory.clear();
    _taskHistory.clear();
    _profile.clear();
    _streakCount = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Wipes local storage
    
    notifyListeners();
  }

  // --- AUTHENTICATION ---

  Future<User?> signInWithGoogle() async {
    try {
      _setLoading(true);

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return null; // User canceled
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google User
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // Sync data after successful login
      await _syncFromCloud();

      _setLoading(false);
      return userCredential.user;
    } catch (e) {
      print("Google Sign In Error: $e");
      _setLoading(false);
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();

    // Optional: Clear local data on sign out?
    // Usually better to keep it or clear it depending on privacy needs.
    // For now, we keep local data so they can continue as guest.
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // --- DATA MANAGEMENT ---

  void saveProfile({
    required String name,
    required String diagnosis,
    required String sensory,
    required String language,
  }) {
    updateProfile({
      'name': name,
      'diagnosis': diagnosis,
      'sensory': sensory,
      'language': language,
    });
  }

  void toggleFont() {
    updateProfile({
      'font': (_profile['font'] == 'dyslexic') ? 'standard' : 'dyslexic',
    });
  }

  void toggleContrast() {
    updateProfile({
      'contrast': (_profile['contrast'] == 'high') ? 'standard' : 'high',
    });
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

  void updateProfile(Map<String, String> updates) {
    _profile.addAll(updates);
    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  void addToHistory(String role, String text) {
    // Keep last 100 messages
    if (_history.length > 100) _history.removeAt(0);

    _history.add({
      'role': role,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _saveToLocal();
    _saveToCloud(); // Auto-save to cloud
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _userApiKey = key;
    await _storage.write(key: "gemini_api_key", value: key);
    notifyListeners();
  }

  // --- SYNC ENGINE (SECURE) ---

  Future<void> _syncFromCloud() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('encrypted_profile')) _profile.addAll(_decryptMap(data['encrypted_profile']));
        
        if (data.containsKey('encrypted_chat_history')) {
           _chatHistory = _sanitizeDecryptedList(_decryptList(data['encrypted_chat_history']));
        }
        if (data.containsKey('encrypted_task_history')) {
           _taskHistory = _sanitizeDecryptedList(_decryptList(data['encrypted_task_history']));
        }
        if (data.containsKey('streak')) _streakCount = data['streak'];
        _saveToLocal();
        notifyListeners();
      }
    } catch (e) { print("Sync Error: $e"); }
  }

  // Helper for Cloud Data
  List<Map<String, String>> _sanitizeDecryptedList(List<dynamic> list) {
    return list.map((e) {
      try {
        final map = Map<String, String>.from(e);
        if (map['text'] == null) return null;
        return map;
      } catch (_) { return null; }
    }).whereType<Map<String, String>>().toList();
  }

  Future<void> _saveToCloud() async {
    if (currentUser == null) return;
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      String encProfile = encrypter.encrypt(json.encode(_profile), iv: _iv).base64;
      String encChat = encrypter.encrypt(json.encode(_chatHistory), iv: _iv).base64;
      String encTask = encrypter.encrypt(json.encode(_taskHistory), iv: _iv).base64;

      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'encrypted_profile': encProfile,
        'encrypted_chat_history': encChat,
        'encrypted_task_history': encTask,
        'streak': _streakCount,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) { print("Cloud Save Error: $e"); }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_profile', json.encode(_profile));
    await prefs.setString('local_chat_history', json.encode(_chatHistory));
    await prefs.setString('local_task_history', json.encode(_taskHistory));
    await prefs.setInt('streak', _streakCount);
  }

  // --- CRYPTO HELPERS ---

  Map<String, String> _decryptMap(String base64String) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final decrypted = encrypter.decrypt64(base64String, iv: _iv);
      return Map<String, String>.from(json.decode(decrypted));
    } catch (e) {
      return {};
    }
  }

  List<dynamic> _decryptList(String base64String) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final decrypted = encrypter.decrypt64(base64String, iv: _iv);
      return json.decode(decrypted) as List<dynamic>;
    } catch (e) {
      return [];
    }
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
