import 'dart:convert';
import 'dart:math' as math; // ✅ Required for max() logic
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; 
import 'package:universal_io/io.dart'; 
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
  ); 
  // ✅ STATIC IV: Ensures data can be decrypted after app restart/reinstall
  final enc.IV _iv = enc.IV.fromUtf8('NeuroAppIV123456');

  // ============================================================
  // 👤 STATE
  // ============================================================

  String _userApiKey = "";
  Map<String, String> _profile = {};
  List<Map<String, String>> _history = [];
  
  // 🎮 Gamification State
  int _streakCount = 0;
  int _xp = 0;
  int _level = 1;
  bool _showLevelUpAnimation = false;

  // 🧠 Brain State
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

  // 🎮 Gamification Getters
  int get xp => _xp;
  int get level => _level;
  bool get showLevelUpAnimation => _showLevelUpAnimation;
  
  int get xpToNextLevel => _level * 100;
  double get levelProgress => (_xp / xpToNextLevel).clamp(0.0, 1.0);

  // ============================================================
  // 🚀 INITIALIZATION
  // ============================================================

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final storedKey = await _secureStorage.read(key: "gemini_api_key");
    final envKey = dotenv.env['GEMINI_API_KEY'];

    _userApiKey = (storedKey != null && storedKey.isNotEmpty)
        ? storedKey
        : (envKey ?? "");

    // Load profile
    final profileJson = prefs.getString('local_profile');
    if (profileJson != null) {
      _profile = Map<String, String>.from(json.decode(profileJson));
    }

    // Sync Energy/Overwhelm from profile map if exists
    if (_profile.isNotEmpty) {
      _parseDynamicState();
    }

    _useLocalModel = prefs.getBool('use_local_model') ?? false;
    _streakCount = prefs.getInt('streak') ?? 0;
    
    // Load Gamification
    _xp = prefs.getInt('user_xp') ?? 0;
    _level = prefs.getInt('user_level') ?? 1;

    // Load Brain State
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

  // ✅ Helper to parse strings back to numbers/bools from the profile map
  void _parseDynamicState() {
    if (_profile.containsKey('energy')) {
      _energyLevel = double.tryParse(_profile['energy']!) ?? 0.5;
    }
    if (_profile.containsKey('overwhelmed')) {
      _isOverwhelmed = _profile['overwhelmed'] == 'true';
    }
    notifyListeners();
  }

  // ============================================================
  // 🎮 GAMIFICATION LOGIC
  // ============================================================

  void awardXp(int amount) {
    _xp += amount;
    
    // Check for Level Up
    if (_xp >= xpToNextLevel) {
      _xp -= xpToNextLevel; 
      _level++;
      _showLevelUpAnimation = true;
      
      // Auto-hide animation after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _showLevelUpAnimation = false; 
        notifyListeners();
      });
    }

    _saveToLocal();
    _saveToCloud();
    notifyListeners();
  }

  void consumeLevelUpEvent() {
    _showLevelUpAnimation = false;
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
  // 🧠 ENERGY & ADAPTATION
  // ============================================================

  void setEnergy(double value) {
    _energyLevel = value.clamp(0.0, 1.0);
    _profile['energy'] = _energyLevel.toString();
    
    // Auto-trigger overwhelm if energy drops too low
    if (_energyLevel < 0.2) _isOverwhelmed = true;
    
    notifyListeners();
    _saveToLocal();
    _saveToCloud();
  }

  void setOverwhelm(bool value) {
    _isOverwhelmed = value;
    _profile['overwhelmed'] = value.toString();
    notifyListeners();
    _saveToLocal();
    _saveToCloud();
  }

  void adaptToTaskPerformance({required int estimatedSec, required int actualSec}) {
    // 1. If user was 2x slower than expected -> Drop Energy
    if (actualSec > (estimatedSec * 2)) {
      setEnergy(_energyLevel - 0.1); 
      print("📉 Slow progress detected. Energy lowered to $_energyLevel");
    } 
    // 2. If user was fast (used < 80% of time) -> Boost Energy (Momentum)
    else if (actualSec < (estimatedSec * 0.8)) {
      setEnergy(_energyLevel + 0.05);
      print("🚀 Momentum detected. Energy boosted to $_energyLevel");
    }
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
    _xp = 0;
    _level = 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  // ============================================================
  // ☁️ CLOUD SYNC
  // ============================================================

  Future<void> _syncFromCloud() async {
    // This method is legacy/backup. Real logic is in startCloudListener
    // Kept to satisfy older calls
    if (currentUser == null) return;
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
            'xp': _xp,
            'level': _level,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      print("☁️ Saved Profile & Stats to Cloud");
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
    // Save Gamification
    await prefs.setInt('user_xp', _xp);
    await prefs.setInt('user_level', _level);
    // Save Brain State
    await prefs.setDouble('energy_level', _energyLevel);
    await prefs.setBool('is_overwhelmed', _isOverwhelmed);
    print("💾 Settings Saved Locally");
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
  // 🔐 AUTH & CLOUD LISTENER (FIXED)
  // ============================================================

  Future<User?> signInWithGoogle() async {
    try {
      _setLoading(true);
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
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

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

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
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('encrypted_profile')) {
          _profile = _decryptMap(data['encrypted_profile']);
          _streakCount = data['streak'] ?? 0;
          _xp = data['xp'] ?? 0;
          _level = data['level'] ?? 1;
          
          _parseDynamicState(); // Load energy/overwhelm

          await _saveToLocal();
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

  // ✅ FIXED LISTENER: Correctly checks XP/Level/Streak AND Profile changes
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
        final remoteXp = data['xp'] ?? _xp;
        final remoteLevel = data['level'] ?? _level;
        final remoteStreak = data['streak'] ?? _streakCount;

        bool changed = false;

        // Check if remote stats are better/newer
        // Using Math.max logic implicitly by checking greater than
        if (remoteXp > _xp) { _xp = remoteXp; changed = true; }
        if (remoteLevel > _level) { _level = remoteLevel; changed = true; }
        if (remoteStreak > _streakCount) { _streakCount = remoteStreak; changed = true; }

        // Check if profile map changed
        if (json.encode(_profile) != json.encode(remoteProfile)) {
          _profile = remoteProfile;
          _parseDynamicState(); // Update energy/overwhelm from new profile
          changed = true;
        }

        if (changed) {
          _saveToLocal();
          notifyListeners();
          print("🔄 Devices synced (Stats or Profile updated)");
        }
      }
    }, onError: (e) {
       print("⚠️ Stream Error: $e");
    });
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    _profile = {}; // Clear sensitive data
    _xp = 0;
    _level = 1;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}