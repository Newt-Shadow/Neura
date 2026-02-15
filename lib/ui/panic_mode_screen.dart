import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:flutter_animate/flutter_animate.dart';

class PanicModeScreen extends StatefulWidget {
  const PanicModeScreen({super.key});

  @override
  State<PanicModeScreen> createState() => _PanicModeScreenState();
}

class _PanicModeScreenState extends State<PanicModeScreen> {
  int _stepIndex = 0;

  // The 5-4-3-2-1 Grounding Technique
  final List<Map<String, String>> _groundingSteps = [
    {"title": "Breathe", "desc": "Take a deep breath in... and out."},
    {"title": "5 Things", "desc": "Look around. Find 5 things you can see."},
    {"title": "4 Things", "desc": "Find 4 things you can physically touch."},
    {"title": "3 Sounds", "desc": "Listen. Name 3 things you can hear."},
    {"title": "2 Smells", "desc": "Identify 2 things you can smell."},
    {"title": "1 Taste", "desc": "Name 1 thing you can taste."},
    {"title": "Safe", "desc": "You are grounded. You are safe."},
  ];

  void _nextStep() {
    HapticFeedback.mediumImpact(); // Physical grounding
    setState(() {
      if (_stepIndex < _groundingSteps.length - 1) {
        _stepIndex++;
      } else {
        Navigator.pop(context); // Auto-exit when done
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _groundingSteps[_stepIndex];
    final progress = (_stepIndex + 1) / _groundingSteps.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Calming Indigo/Slate
      body: SafeArea(
        child: GestureDetector(
          onTap: _nextStep, // Tap anywhere to progress
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. BACKGROUND PULSE (Subtle)
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.05),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 4.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
              ),

              // 2. CENTER CONTENT
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Step Title
                      Text(
                        step["title"]!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      )
                      // ✅ FIX: Use a unique key prefix so it doesn't clash with the description
                      .animate(key: ValueKey("title_$_stepIndex")) 
                      .fadeIn().slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 20),

                      // Step Instruction
                      Text(
                        step["desc"]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueGrey.shade100,
                          fontSize: 18,
                          height: 1.6,
                        ),
                      )
                      // ✅ FIX: Unique key prefix here too
                      .animate(key: ValueKey("desc_$_stepIndex")) 
                      .fadeIn(delay: 200.ms),

                      const SizedBox(height: 60),

                      // Tap Prompt
                      if (_stepIndex < _groundingSteps.length - 1)
                        Text(
                          "Tap to continue",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 1.seconds).then().fadeOut(duration: 1.seconds),
                    ],
                  ),
                ),
              ),

              // 3. PROGRESS BAR (Top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  color: Colors.tealAccent.withOpacity(0.3),
                  minHeight: 4,
                ),
              ),

              // 4. EXIT BUTTON
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}