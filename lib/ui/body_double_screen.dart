import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../logic/neuro_settings.dart';
import '../logic/task_classifier.dart'; // ✅ Uses the shared brain

class BodyDoubleScreen extends StatefulWidget {
  const BodyDoubleScreen({super.key});

  @override
  State<BodyDoubleScreen> createState() => _BodyDoubleScreenState();
}

class _BodyDoubleScreenState extends State<BodyDoubleScreen> with TickerProviderStateMixin {
  final TextEditingController _taskController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  late ConfettiController _confettiController;
  
  // 🧠 SMART STATE
  bool _isActive = false;
  final Stopwatch _sessionStopwatch = Stopwatch();
  Timer? _monitorTimer;
  
  int _targetChunkMinutes = 20; 
  int _interventionLevel = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _taskController.dispose();
    _confettiController.dispose();
    _monitorTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _toggleSession() {
    if (_isActive) {
      _stopSession();
    } else {
      if (_taskController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please type what you are doing first!")));
        return;
      }
      _startSession();
    }
  }

  void _startSession() async {
    FocusScope.of(context).unfocus();
    
    // 🧠 1. INITIAL CLASSIFICATION
    final taskText = _taskController.text;
    final TaskType type = TaskClassifier.classify(taskText);
    
    // Auto-tune duration based on type
    setState(() {
      _isActive = true;
      _interventionLevel = 0;
      if (type == TaskType.physical) _targetChunkMinutes = 15;
      else if (type == TaskType.cognitive) _targetChunkMinutes = 25;
      else _targetChunkMinutes = 20;
    });
    
    _sessionStopwatch.start();
    
    // 🧠 2. SMART START MESSAGE
    String startMsg = "I'm focusing on \"$taskText\" with you.";
    if (type == TaskType.physical) startMsg += " Let's move.";
    if (type == TaskType.cognitive) startMsg += " Deep breath. Focus mode on.";
    if (type == TaskType.social) startMsg += " You are not alone.";
    
    await _tts.speak(startMsg);
    _startMonitoringLoop();
  }

  void _stopSession() {
    _sessionStopwatch.stop();
    _sessionStopwatch.reset();
    _monitorTimer?.cancel();
    _tts.stop();
    setState(() => _isActive = false);
  }

  void _startMonitoringLoop() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isActive) return;

      final elapsedMinutes = _sessionStopwatch.elapsed.inMinutes;
      
      if (elapsedMinutes >= _targetChunkMinutes && _interventionLevel == 0) {
        _triggerIntervention(1);
      } else if (elapsedMinutes >= (_targetChunkMinutes * 1.5) && _interventionLevel == 1) {
        _triggerIntervention(2);
      }
    });
  }

  void _triggerIntervention(int level) async {
    setState(() => _interventionLevel = level);
    
    // ✅ CALL THE ADVANCED ENGINE
    String msg = _generateSmartNudge(level);

    await _tts.speak(msg);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.teal.shade900,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: "I'm Good", onPressed: _resetCheckIn),
        )
      );
    }
  }

  // 🧠 THE PSYCHOLOGICAL ENGINE (Adapted for Long Sessions)
  String _generateSmartNudge(int level) {
    final text = _taskController.text;
    final type = TaskClassifier.classify(text);
    final subject = _extractTaskSubject(text);
    final settings = context.read<NeuroSettings>();

    // 1. STATE ANALYSIS
    if (settings.isOverwhelmed) {
      return "We've been working for a while. Remember to breathe. You are safe.";
    }
    
    // 2. LEVEL 1: GENTLE CHECK-IN (Maintenance)
    if (level == 1) {
      if (settings.energyLevel > 0.8) {
        return "You are crushing this $subject session. Keep the flow.";
      }
      
      switch (type) {
        case TaskType.cognitive:
          return "Check in. Is your brain drifting? Bring it back to the $subject.";
        case TaskType.physical:
          return "We are still moving. Don't sit down yet.";
        case TaskType.social:
          return "You're doing great. Connection takes energy, take a sip of water.";
        default:
          return "I'm still here watching the time. Focus on $subject.";
      }
    }

    // 3. LEVEL 2: TACTICAL RESET (Drift Detected)
    if (level == 2) {
      switch (type) {
        case TaskType.cognitive:
          return "We might be stuck in a loop. Stand up, stretch, and reset your eyes.";
        case TaskType.physical:
          return "Fatigue check. Do 2 more minutes, then we earn a break.";
        case TaskType.social:
          return "If you are overthinking the reply, just send the draft.";
        default:
          return "Let's reset. Shake your hands out. 3... 2... 1... Back to $subject.";
      }
    }

    return "Check in.";
  }

  void _resetCheckIn() {
    setState(() {
      _targetChunkMinutes += 10; // Extend focus time
      _interventionLevel = 0;
    });
    _tts.speak("Got it. Keep going.");
  }

  void _finishSession() {
    _stopSession();
    _confettiController.play();
    context.read<NeuroSettings>().awardXp(100);
    _taskController.clear();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Session Complete 🧠"),
        content: const Text("You sustained focus! +100 XP"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      )
    );
  }

  // 🛠️ HELPER: Extracts the noun 
  String _extractTaskSubject(String text) {
    final words = text.split(' ');
    if (words.isEmpty) return "task";
    // Heuristic: Longest word usually carries meaning
    String longest = words.reduce((a, b) => a.length > b.length ? a : b);
    return longest.replaceAll(RegExp(r'[^\w\s]'), ''); 
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Body Double"),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Icon(Icons.circle, color: _isActive ? Colors.green : Colors.grey, size: 12)
                    .animate(target: _isActive ? 1 : 0)
                    .fadeIn().then().shimmer(duration: 2000.ms),
              )
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Visual Anchor
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isActive ? Colors.teal.shade50 : Colors.grey.shade50,
                      border: Border.all(
                        color: _isActive ? Colors.teal : Colors.grey.shade300, 
                        width: 4
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isActive ? Icons.face : Icons.face_retouching_off,
                        size: 80,
                        color: _isActive ? Colors.teal : Colors.grey.shade400,
                      ),
                    ),
                  ).animate(target: _isActive ? 1 : 0).scale(duration: 500.ms),

                  const SizedBox(height: 40),

                  if (!_isActive)
                    TextField(
                      controller: _taskController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "I am working on...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.black26),
                      ),
                    ).animate().fadeIn()
                  else
                    Column(
                      children: [
                        Text(
                          _taskController.text,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<int>(
                          stream: Stream.periodic(const Duration(seconds: 1), (i) => _sessionStopwatch.elapsed.inSeconds),
                          builder: (context, snapshot) {
                            final secs = snapshot.data ?? 0;
                            final m = (secs ~/ 60).toString().padLeft(2, '0');
                            final s = (secs % 60).toString().padLeft(2, '0');
                            return Text("$m:$s", style: const TextStyle(fontSize: 18, color: Colors.grey, fontFamily: 'monospace'));
                          },
                        ),
                      ],
                    ).animate().fadeIn(),

                  const Spacer(),

                  if (!_isActive)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Start Session"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _toggleSession,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                              onPressed: _toggleSession,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Give Up"),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _finishSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Done!"),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.orange],
          ),
        ),
      ],
    );
  }
}