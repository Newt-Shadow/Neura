import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/ai_response.dart';

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
  int _currentIndex = 0;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
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
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 SAFETY GUARD
    if (widget.response.actions.isEmpty) {
      return Scaffold(
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
