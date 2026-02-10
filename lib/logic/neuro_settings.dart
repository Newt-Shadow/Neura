import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NeuroSettings extends ChangeNotifier {
  
  // Visual
  bool _useDyslexicFont = false;
  bool _highContrast = false;
  
  // Cognitive
  double _taskGranularity = 0.5; // 0.0=Micro, 0.5=Standard, 1.0=Detailed
  
  // Personal Profile
  String _userName = "";
  String _diagnosis = ""; // e.g., ADHD, Autism, Dyslexia
  String _sensorySensitivities = ""; // e.g., Loud noises, Bright lights
  String _preferredLanguage = "English"; // English, Hindi, Hinglish, etc.
  
  // Gamification
  int _streakCount = 0;

  // Getters
  bool get useDyslexicFont => _useDyslexicFont;
  bool get highContrast => _highContrast;
  double get taskGranularity => _taskGranularity;
  String get userName => _userName;
  String get diagnosis => _diagnosis;
  String get sensorySensitivities => _sensorySensitivities;
  String get preferredLanguage => _preferredLanguage;
  int get streakCount => _streakCount;

  String? get fontFamily => _useDyslexicFont ? 'OpenDyslexic' : null;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useDyslexicFont = prefs.getBool('neuro_dyslexic_font') ?? false;
    _highContrast = prefs.getBool('neuro_high_contrast') ?? false;
    _taskGranularity = prefs.getDouble('neuro_granularity') ?? 0.5;
    
    _userName = prefs.getString('user_name') ?? '';
    _diagnosis = prefs.getString('user_diagnosis') ?? '';
    _sensorySensitivities = prefs.getString('user_sensory') ?? '';
    _preferredLanguage = prefs.getString('user_language_pref') ?? 'English';
    
    _streakCount = prefs.getInt('user_streak') ?? 0;
    notifyListeners();
  }

  Future<void> toggleFont() async {
    _useDyslexicFont = !_useDyslexicFont;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('neuro_dyslexic_font', _useDyslexicFont);
    notifyListeners();
  }

  Future<void> toggleContrast() async {
    _highContrast = !_highContrast;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('neuro_high_contrast', _highContrast);
    notifyListeners();
  }

  Future<void> setGranularity(double val) async {
    _taskGranularity = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('neuro_granularity', _taskGranularity);
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String diagnosis,
    required String sensory,
    required String language,
  }) async {
    _userName = name;
    _diagnosis = diagnosis;
    _sensorySensitivities = sensory;
    _preferredLanguage = language;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_diagnosis', diagnosis);
    await prefs.setString('user_sensory', sensory);
    await prefs.setString('user_language_pref', language);
    notifyListeners();
  }

  Future<void> incrementStreak() async {
    _streakCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_streak', _streakCount);
    notifyListeners();
  }

  Map<String, String> _learnedTraits = {};

  // Called by RemoteAIService when AI learns something new
  Future<void> updateProfile(Map<String, String> newTraits) async {
    _learnedTraits.addAll(newTraits);
    notifyListeners();
    // TODO: Save _learnedTraits to SharedPreferences
  }

  // Used to inject into the Prompt
  String generateProfileString() {
    if (_learnedTraits.isEmpty) return "No specific details known.";
    
    return _learnedTraits.entries
        .map((e) => "- ${e.key}: ${e.value}")
        .join("\n");
  }
}