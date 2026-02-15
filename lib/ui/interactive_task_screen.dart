import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';
import '../domain/ai_response.dart';
import 'panic_mode_screen.dart'; 

class InteractiveTaskScreen extends StatefulWidget {
  final AIResponse response;
  final bool dyslexiaMode;

  const InteractiveTaskScreen({
    super.key,
    required this.response,
    required this.dyslexiaMode,
  });

  @override
  State<InteractiveTaskScreen> createState() =>
      _InteractiveTaskScreenState();
}

class _InteractiveTaskScreenState extends State<InteractiveTaskScreen> {
  late List<bool> _completedSteps;
  late ScrollController _scrollController;
  int _currentIndex = 0;
  final FlutterTts _tts = FlutterTts();

 
  bool _isBodyDoubleActive = false;
  Timer? _bodyDoubleMonitor;
  final Stopwatch _stepStopwatch = Stopwatch();
  int _interventionLevel = 0; 

  // Level 1: Gentle Comfort
  final List<String> _comfortNudges = [
    "I'm here.",
    "Just this one step.",
    "Breathe.",
    "Take your time.",
  ];

  // Level 2: Tactical Advice
  final List<String> _tacticalNudges = [
    "Just do the first 5 seconds.",
    "Can you just touch the object?",
    "Don't finish, just start.",
  ];

  // Level 3: Permission
  final List<String> _permissionNudges = [
    "It's okay to skip this.",
    "Good enough is perfect.",
    "Let's move on.",
  ];

  @override
  void initState() {
    super.initState();
    _completedSteps = List.filled(widget.response.actions.length, false);
    _scrollController = ScrollController();
    _initTts();

    _stepStopwatch.start();
    _startSmartMonitor();

    if (widget.response.actions.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _speakCurrentStep();
      });
    }
  }

  void _startSmartMonitor() {
    _bodyDoubleMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isBodyDoubleActive || widget.response.actions.isEmpty) return;

      final currentStep = widget.response.actions[_currentIndex];
      final limitSeconds = currentStep.estimatedSeconds;
      // Default to 60s if null, just to have a baseline
      final safeLimit = limitSeconds ?? 60;
      
      final elapsed = _stepStopwatch.elapsed.inSeconds;

      if (_interventionLevel == 0 && elapsed > (safeLimit * 1.5)) {
         _triggerSmartIntervention(1);
      }
      else if (_interventionLevel == 1 && elapsed > (safeLimit * 3.0)) {
         _triggerSmartIntervention(2);
      }
      else if (_interventionLevel == 2 && elapsed > (safeLimit * 5.0)) {
         _triggerSmartIntervention(3);
      }
    });
  }

  void _triggerSmartIntervention(int level) async {
     setState(() => _interventionLevel = level);

     String msg = "";
     // 🎨 CALM COLORS: No bright warnings. Just Grey/Teal.
     Color bgColor = Colors.grey.shade800; 

     if (level == 1) {
       msg = _comfortNudges[Random().nextInt(_comfortNudges.length)];
     } else if (level == 2) {
       msg = _tacticalNudges[Random().nextInt(_tacticalNudges.length)];
     } else {
       msg = _permissionNudges[Random().nextInt(_permissionNudges.length)];
     }

     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
         backgroundColor: bgColor,
         behavior: SnackBarBehavior.floating, // Floating is less obtrusive
         width: 300, // Small width
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         duration: const Duration(seconds: 5),
         action: level == 3 
            ? SnackBarAction(label: "Skip", textColor: Colors.tealAccent, onPressed: _completeStep) 
            : null,
       )
     );

     await _tts.speak(msg);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  Future<void> _speakCurrentStep() async {
    if (widget.response.actions.isEmpty) return;
    final step = widget.response.actions[_currentIndex];
    await _tts.stop();
    await _tts.speak(step.instruction);
  }

  void _completeStep() {
    if (widget.response.actions.isEmpty) return;

    HapticFeedback.mediumImpact();
    _stepStopwatch.reset(); 
    setState(() => _interventionLevel = 0);

    if (_currentIndex < widget.response.actions.length - 1) {
      setState(() => _currentIndex++);
      _speakCurrentStep();
    } else {
      _tts.stop();
      // ✅ AWARD XP & STREAK AT END OF FOCUS MODE
      final settings = context.read<NeuroSettings>();
      settings.awardXp(50); 
      settings.incrementStreak();
      
      _showCompletionCelebration();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose();
    _bodyDoubleMonitor?.cancel();
    _stepStopwatch.stop();
    super.dispose();
  }

  void _showSupportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Support", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            SwitchListTile(
              secondary: const Icon(Icons.people_outline, color: Colors.teal),
              title: const Text("Buddy"),
              subtitle: const Text("Quietly monitoring time."),
              value: _isBodyDoubleActive,
              activeColor: Colors.teal,
              onChanged: (val) {
                Navigator.pop(context);
                setState(() => _isBodyDoubleActive = val);
                if (val) {
                  _tts.speak("I'm active.");
                  _stepStopwatch.reset();
                  setState(() => _interventionLevel = 0);
                }
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.health_and_safety, color: Colors.grey),
              title: const Text("Panic Mode"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PanicModeScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Done. ✅"),
        content: const Text("Task complete. +50 XP!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Close", style: TextStyle(color: Colors.teal)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.response.actions.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Loading...")));
    }

    final step = widget.response.actions[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white, // ✅ ZEN WHITE BACKGROUND
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✅ MINIMALIST INDICATOR
          if (_isBodyDoubleActive)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.people, color: Colors.teal, size: 20), // Static, calming Teal
            ),

          IconButton(
            icon: const Icon(Icons.tune, color: Colors.grey), // "Tune" implies adjustment, less alarming than "Help"
            onPressed: _showSupportMenu,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32), // More whitespace
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Center everything
            children: [
              // ✅ THIN, UNIFIED PROGRESS BAR
              LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.response.actions.length,
                color: Colors.teal, // Always Teal
                backgroundColor: Colors.grey.shade100,
                minHeight: 4, // Thinner
              ),
              
              const Spacer(flex: 2),

              // ✅ MAIN INSTRUCTION (Clean Typography)
              Text(
                step.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28, // Slightly smaller for less shouting
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontFamily: widget.dyslexiaMode ? 'OpenDyslexic' : 'Lexend',
                ),
              ),

              const SizedBox(height: 24),

              // ✅ SUBTLE TIME GOAL
              if (step.estimatedSeconds > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "${step.estimatedSeconds}s",
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),

              const Spacer(flex: 3),

              // ✅ BIG, SIMPLE BUTTON
              SizedBox(
                width: 200, // Fixed width helps muscle memory
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // Consistent Teal
                    elevation: 0, // Flat design = Less noise
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _completeStep,
                  child: const Icon(Icons.check, size: 32, color: Colors.white),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}