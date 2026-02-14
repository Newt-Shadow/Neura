import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:universal_io/io.dart'; // For Platform check
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;

class NeuroSettings extends ChangeNotifier {
  // ============================================================
  // 🔐 SECURITY
  // ============================================================

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final enc.Key _encKey = enc.Key.fromUtf8(
    'NeuroAppSecureKey123456789012345',
  ); // 32 chars
  final enc.IV _iv = enc.IV.fromUtf8('NeuroAppIV123456');

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
  String get executiveStruggle => _profile['struggle'] ?? "Task Paralysis";
  String get interest => _profile['interest'] ?? "Focus";
  String get preferredLanguage => _profile['language'] ?? "English";

  bool get dyslexiaMode => _profile['font'] == 'dyslexic';
  bool get useDyslexicFont => dyslexiaMode;
  bool get highContrast => _profile['contrast'] == 'high';

  String? get fontFamily => dyslexiaMode ? 'OpenDyslexic' : 'Lexend';

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
    final storedKey = await _secureStorage.read(key: "gemini_api_key");

    final envKey = dotenv.env['GEMINI_API_KEY'];

    _userApiKey = (storedKey != null && storedKey.isNotEmpty)
        ? storedKey
        : (envKey ?? "");

    if (_userApiKey.isEmpty) {
      debugPrint("⚠ GEMINI_API_KEY NOT FOUND");
    } else {
      debugPrint("✅ GEMINI KEY LOADED");
    }

    // Load profile
    final profileJson = prefs.getString('local_profile');
    if (profileJson != null) {
      _profile = Map<String, String>.from(json.decode(profileJson));
    }

    _useLocalModel = prefs.getBool('use_local_model') ?? false;
    _streakCount = prefs.getInt('streak') ?? 0;
    _energyLevel = prefs.getDouble('energy_level') ?? 0.5;
    _isOverwhelmed = prefs.getBool('is_overwhelmed') ?? false;

    final historyJson = prefs.getString('local_history');
    if (historyJson != null) {
      final raw = json.decode(historyJson) as List;
      _history = raw.map((e) => Map<String, String>.from(e)).toList();
    }

    // Auto sync on login
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        startCloudListener();
      }
    });

    notifyListeners();
  }

  // ============================================================
  // 🔑 API KEY
  // ============================================================

  Future<void> setApiKey(String key) async {
    _userApiKey = key;
    await _secureStorage.write(key: "gemini_api_key", value: key);
    notifyListeners();
  }

  // ============================================================
  // 🧠 ENERGY
  // ============================================================

  void setEnergy(double value) async {
    _energyLevel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('energy_level', value);
    notifyListeners();
  }

  void setOverwhelm(bool value) async {
    _isOverwhelmed = value;
    final prefs = await SharedPreferences.getInstance();
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

  void updateProfile(Map<String, String> updates) {
    _profile.addAll(updates);
    notifyListeners();
    _saveToLocal();
    _saveToCloud();
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

    final prefs = await SharedPreferences.getInstance();
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

      if (!doc.exists ||
          doc.data() == null ||
          doc.data()!['encrypted_profile'] == null ||
          doc.data()!['encrypted_profile'] == '') {
        print("☁️ No cloud profile found");
        return;
      }

      final data = doc.data()!;

      _profile = _decryptMap(data['encrypted_profile']);
      _streakCount = data['streak'] ?? 0;

      await _saveToLocal();
      notifyListeners();

      print("☁️ Pulled Profile from Cloud (Cloud is source of truth)");
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
  }

  Future<void> _saveToCloud() async {
    if (currentUser == null) return;
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final encryptedProfile = encrypter
          .encrypt(json.encode(_profile), iv: _iv)
          .base64;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
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
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('local_profile', json.encode(_profile));

    await prefs.setString('local_history', json.encode(_history));

    await prefs.setInt('streak', _streakCount);
    print("💾 Settings Saved Locally: $_profile");
  }

  // ============================================================
  // 🔐 CRYPTO
  // ============================================================

  Map<String, String> _decryptMap(String base64String) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final decrypted = encrypter.decrypt64(base64String, iv: _iv);
      return Map<String, String>.from(json.decode(decrypted));
    } catch (_) {
      return {};
    }
  }

  List<dynamic> _decryptList(String base64String) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_encKey));
      final decrypted = encrypter.decrypt64(base64String, iv: _iv);
      return json.decode(decrypted) as List<dynamic>;
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

      UserCredential userCredential;

      if (kIsWeb) {
        // 🌐 WEB LOGIN (Popup prevents manual URI headache)
        final provider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // 📱 MOBILE LOGIN
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          _setLoading(false);
          return null;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // 🔥 CRITICAL: Pull existing data BEFORE auto-save kicks in
      await _forceInitialPullFromCloud(userCredential.user!.uid);
      
      // Start Real-time sync
      startCloudListener();

      _setLoading(false);
      return userCredential.user;
    } catch (e) {
      print("Sign in error: $e");
      _setLoading(false);
      return null;
    }
  }

  Future<void> _forceInitialPullFromCloud(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('encrypted_profile')) {
          // EXISTING USER: Restore from Cloud
          _profile = _decryptMap(data['encrypted_profile']);
          _streakCount = data['streak'] ?? 0;
          await _saveToLocal(); // Cache immediately
          notifyListeners();
          print("📥 Existing profile found and restored from Cloud.");
        }
      } else {
        print("🌱 New User (or empty cloud). Keeping defaults.");
      }
    } catch (e) {
      print("⚠️ Error checking cloud profile: $e");
    }
  }

  void startCloudListener() {
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['encrypted_profile'] == null ||
            data['encrypted_profile'] == '') return;

        final remoteProfile = _decryptMap(data['encrypted_profile']);

        // Only update if remote is actually different to avoid infinite loops
        if (json.encode(_profile) != json.encode(remoteProfile)) {
          _profile = remoteProfile;
          _streakCount = data['streak'] ?? _streakCount;
          _saveToLocal();
          notifyListeners();
          print("🔄 Devices Synced in Real-time.");
        }
      }
    }, onError: (e) {
       print("⚠️ Stream Error: $e");
    });
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    _profile = {}; // Clear sensitive data from RAM on logout
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}