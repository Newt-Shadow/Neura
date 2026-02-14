import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart'; // Added for Provider access
import '../logic/neuro_settings.dart'; // Added for NeuroSettings
import '../domain/ai_response.dart';
import 'body_double_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _completedSteps = List.filled(widget.response.actions.length, false);
    _scrollController = ScrollController();
    _initTts();

    // Only speak if actions exist
    if (widget.response.actions.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _speakCurrentStep();
      });
    }
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

    if (_currentIndex < widget.response.actions.length - 1) {
      setState(() => _currentIndex++);
      _speakCurrentStep();
    } else {
      _tts.stop();
      _showCompletionCelebration(); // Call the celebration dialog instead of popping immediately
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose(); // Dispose controller
    super.dispose();
  }

  // ✅ ADDED: Support Menu Logic
  void _showSupportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Feeling Stuck?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "It happens. Choose what you need right now:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // OPTION 1: BODY DOUBLE
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.people_outline, color: Colors.purple),
              ),
              title: const Text("I need company"),
              subtitle: const Text("Open Body Double mode to work together."),
              onTap: () {
                Navigator.pop(context); // Close menu
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyDoubleScreen()));
              },
            ),
            const SizedBox(height: 10),

            // OPTION 2: PANIC MODE
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.pink.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.volunteer_activism, color: Colors.pink),
              ),
              title: const Text("I'm overwhelmed"),
              subtitle: const Text("Pause everything. Just breathe."),
              onTap: () {
                Navigator.pop(context); // Close menu
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PanicModeScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  // Unused in Single View, but kept as requested to preserve code
  void _toggleStep(int index) {
    setState(() {
      _completedSteps[index] = !_completedSteps[index];
    });
    // ... rest of logic
  }

  void _showCompletionCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Mission Complete! 🎉"),
        content: const Text("You crushed it. Brain dopamine restored."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Go back to dashboard
              context.read<NeuroSettings>().incrementStreak();
            },
            child: const Text("Finish"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // 🔥 SAFETY GUARD
    if (widget.response.actions.isEmpty) {
      return Scaffold(
        appBar: AppBar(), // Allow going back
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.response.coachingMessage ??
                  "I need more information.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    }

    final step = widget.response.actions[_currentIndex];

    return Scaffold(
      // ✅ ADDED: AppBar to access the Support Menu
      appBar: AppBar(
        title: Text(widget.response.missionName ?? "Mission"),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.deepPurple),
            tooltip: "I'm Stuck",
            onPressed: _showSupportMenu,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) /
                    widget.response.actions.length,
                color: Colors.teal,
                minHeight: 8,
              ),
              const SizedBox(height: 60),

              Text(
                step.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontFamily:
                      widget.dyslexiaMode ? 'OpenDyslexic' : 'Lexend',
                ),
              ),

              const SizedBox(height: 20),

              if (step.estimatedSeconds != null)
                Text(
                  "${step.estimatedSeconds}s",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal),
                  onPressed: _completeStep,
                  child: const Text(
                    "DONE",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}