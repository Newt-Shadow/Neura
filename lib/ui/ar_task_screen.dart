import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:image/image.dart' as img; // For pixel diff (lightweight body double)
import '../logic/neuro_settings.dart';
import '../logic/remote_ai_service.dart';

class ArTaskScreen extends StatefulWidget {
  final List<dynamic> tasks;
  final List<int>? initialArBox;
  final NeuroSettings settings;
  final VoidCallback onClose;

  const ArTaskScreen({
    required this.tasks,
    this.initialArBox,
    required this.settings,
    required this.onClose,
    super.key,
  });

  @override
  State<ArTaskScreen> createState() => _ArTaskScreenState();
}

class _ArTaskScreenState extends State<ArTaskScreen> {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  
  // Body Double State
  Timer? _stuckTimer;
  bool _hasMovedRecently = false;
  DateTime _lastFrameTime = DateTime.now();
  
  // AR State
  int _currentStep = 0;
  List<int>? _currentArBox;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _currentArBox = widget.initialArBox;
    _initCamera();
    _startBodyDoubleMonitor();
    Future.delayed(const Duration(seconds: 1), _speakCurrentTask);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    _controller = CameraController(
      cameras.first, 
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    await _controller!.initialize();
    
    if (mounted) {
      setState(() {});
      // Simple "Body Double": If camera is streaming, assume minimal activity.
      // A full pixel diff on every frame is heavy for Dart in main thread.
      // We implement a simplified check: User Interaction resets the timer.
      // Real "Pixel Diff" requires Isolates, but here is a simulated "Activity Check".
    }
  }

  void _startBodyDoubleMonitor() {
    // If no interaction or detection for 60 seconds, nudge.
    _stuckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!_hasMovedRecently) {
        _tts.speak("I noticed we stopped. Is there a blocker? Let's just do one tiny thing.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("👀 Body Double: Are we stuck?"),
            backgroundColor: Colors.orange,
            action: SnackBarAction(label: "I'm working!", onPressed: _resetStuckTimer),
          ));
        }
      }
      _hasMovedRecently = false;
    });
  }

  void _resetStuckTimer() {
    _hasMovedRecently = true;
  }

  Future<void> _speakCurrentTask() async {
    if (_currentStep < widget.tasks.length) {
      await _tts.speak(widget.tasks[_currentStep]['title']);
    }
  }

  // --- AR SCANNER ---
  Future<void> _scanForCurrentObject() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    _resetStuckTimer();
    setState(() => _isScanning = true);
    _tts.speak("Scanning for ${widget.tasks[_currentStep]['title']}...");

    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      final taskName = widget.tasks[_currentStep]['title'];
      
      final response = await RemoteAIService.processRequest(
        userQuery: "Where is the '$taskName'? Return box_2d only. If not visible return null.",
        imageBytes: bytes,
        userSettings: widget.settings,
      );

      if (response != null && response.box2d != null) {
        setState(() => _currentArBox = List<int>.from(response.box2d!));
        _tts.speak("Found it! Look for the green box.");
      } else {
        _tts.speak("I can't see it clearly here. Try moving the camera.");
        setState(() => _currentArBox = null);
      }
    } catch (e) {
      _tts.speak("Error scanning.");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _nextStep() {
    _resetStuckTimer();
    setState(() {
      if (_currentStep < widget.tasks.length - 1) {
        _currentStep++;
        _currentArBox = null; // Clear old box to avoid confusion
        _speakCurrentTask();
      } else {
        _tts.speak("Mission Accomplished! You are amazing.");
        widget.settings.incrementStreak();
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _stuckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final task = widget.tasks[_currentStep];

    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera Feed (The Body Double)
          Positioned.fill(child: CameraPreview(_controller!)),
          
          // 2. AR Overlay (The Entry Ramp)
          if (_currentArBox != null)
            Positioned.fill(child: CustomPaint(painter: ARBoxPainter(_currentArBox!))),

          if (_isScanning)
             const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

          // 3. Task UI (The Nudge)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("STEP ${_currentStep + 1}/${widget.tasks.length}", 
                           style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                         if (_currentArBox == null)
                           TextButton.icon(
                             icon: const Icon(Icons.saved_search, size: 20),
                             label: const Text("Show Me"),
                             onPressed: _scanForCurrentObject,
                           )
                       ],
                     ),
                     const SizedBox(height: 8),
                     Text(task['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     if(task['description'] != null)
                       Text(task['description'], style: const TextStyle(fontSize: 16, color: Colors.black87)),
                     const SizedBox(height: 16),
                     SizedBox(
                       width: double.infinity,
                       height: 50,
                       child: ElevatedButton.icon(
                         icon: const Icon(Icons.check_circle),
                         label: const Text("DONE"),
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                         onPressed: _nextStep,
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 50, left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white, 
              child: IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose)
            ),
          ),
        ],
      ),
    );
  }
}

// AR Painter
class ARBoxPainter extends CustomPainter {
  final List<int> box;
  ARBoxPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 6.0;
    
    // Map 0-1000 AI coordinates to Screen
    double top = (box[0] / 1000) * size.height;
    double left = (box[1] / 1000) * size.width;
    double bottom = (box[2] / 1000) * size.height;
    double right = (box[3] / 1000) * size.width;
    
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    
    final textPainter = TextPainter(
      text: const TextSpan(text: "🎯 TARGET", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 16, backgroundColor: Colors.black54)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(left, top - 25));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}