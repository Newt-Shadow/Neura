import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart'; 
import 'dart:async';
import 'package:provider/provider.dart';

import '../logic/neuro_settings.dart';

class InteractiveTaskScreen extends StatefulWidget {
  // CHANGED: Accept processed data directly
  final List<dynamic> initialTasks;
  final String motivation;
  final VoidCallback onReset; // Kept this for your navigation logic

  const InteractiveTaskScreen({
    required this.initialTasks, 
    required this.motivation, 
    required this.onReset, 
    super.key
  });

  @override
  State<InteractiveTaskScreen> createState() => _InteractiveTaskScreenState();
}

class _InteractiveTaskScreenState extends State<InteractiveTaskScreen> {
  int _currentStep = 0;
  List<dynamic> _actions = [];
  
  final FlutterTts _tts = FlutterTts();
  late ConfettiController _confettiController;
  
  double _buttonFill = 0.0;
  bool _isHolding = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _actions = widget.initialTasks; // Load data directly
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initTts();
    
    // Auto-speak first step
    if (_actions.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), _speakCurrentStep);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _holdTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    if (!mounted) return;
    final settings = context.read<NeuroSettings>();
    if (settings.preferredLanguage.contains("Hindi")) {
       try { await _tts.setLanguage("hi-IN"); } catch(_) {}
    }
  }

  // Removed _parseJson() because data is already parsed!

  Future<void> _speakCurrentStep() async {
    if (_actions.isEmpty) return;
    final step = _actions[_currentStep];
    String text = "${step['title']}. ${step['description'] ?? ''}";
    await _tts.speak(text); 
  }

  void _startHolding() {
    setState(() => _isHolding = true);
    HapticFeedback.lightImpact();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _buttonFill += 0.02; 
        if (_buttonFill >= 1.0) {
          _buttonFill = 1.0;
          _finishStep(true); 
          timer.cancel();
        }
      });
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    if (_buttonFill < 1.0) {
      setState(() {
        _buttonFill = 0.0;
        _isHolding = false;
      });
    }
  }

  void _finishStep(bool highDopamine) {
    if (highDopamine) {
      HapticFeedback.heavyImpact(); 
      _confettiController.play();
    } else {
      HapticFeedback.mediumImpact();
    }
    
    setState(() {
      _isHolding = false;
      _buttonFill = 0.0;
    });

    if (_currentStep < _actions.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _currentStep++);
          _speakCurrentStep();
        }
      });
    } else {
      if (mounted) {
        context.read<NeuroSettings>().incrementStreak();
        _showVictoryScreen();
      }
    }
  }

  void _showVictoryScreen() {
    _tts.speak("Mission Complete! ${widget.motivation}");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 400,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            const Text("MISSION ACCOMPLISHED!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            Text(widget.motivation, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close Sheet
                widget.onReset();       // Close Screen
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
            ))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_actions.isEmpty) return const Scaffold(body: Center(child: Text("Data Error")));
    final stepData = _actions[_currentStep];
    final progress = (_currentStep) / _actions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Mission"), // Simplified title
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onReset),
      ),
      body: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive)),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Task HP: ${((1-progress)*100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 1.0 - progress, 
                        minHeight: 16,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.redAccent,
                      ),
                    ).animate(target: 1.0-progress).shakeX(amount: 5), 
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 30, offset: const Offset(0,10))],
                      border: Border.all(color: _isHolding ? Colors.teal : Colors.grey.shade200, width: 2),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Step ${_currentStep + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 12),
                          Text(
                            stepData['title'] ?? stepData['action'] ?? "", 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)
                          ),
                          const SizedBox(height: 16),
                          if (stepData['description'] != null)
                            Text(
                              stepData['description'], 
                              textAlign: TextAlign.center, 
                              style: const TextStyle(fontSize: 18, color: Colors.black87)
                            ),
                          const SizedBox(height: 24),
                          if (stepData['substeps'] != null)
                            ...List<dynamic>.from(stepData['substeps']).map((sub) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(sub.toString(), style: const TextStyle(fontSize: 16, color: Colors.black54))),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                  ).animate(target: _isHolding ? 1 : 0).scale(end: const Offset(1.02, 1.02)),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => _startHolding(),
                      onTapUp: (_) => _stopHolding(),
                      onTapCancel: _stopHolding,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: _isHolding ? Colors.teal.withOpacity(0.3) : Colors.transparent, blurRadius: 20)]
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: _buttonFill,
                              child: Container(decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(24))),
                            ),
                            Center(
                              child: Text(
                                _isHolding ? "CHARGING..." : "HOLD TO COMPLETE",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _buttonFill > 0.5 ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _finishStep(false), 
                      icon: const Icon(Icons.check, color: Colors.grey),
                      label: const Text("Just mark as done", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}