import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:image/image.dart' as img; 
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

class _ArTaskScreenState extends State<ArTaskScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  
  Timer? _stuckTimer;
  bool _hasMovedRecently = false;
  
  int _currentStep = 0;
  List<int>? _currentArBox;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Detect app backgrounding
    _currentArBox = widget.initialArBox;
    _initCamera();
    
    if (widget.tasks.isNotEmpty) {
      _startBodyDoubleMonitor();
      Future.delayed(const Duration(seconds: 1), _speakCurrentTask);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stuckTimer?.cancel();
    _controller?.dispose(); // Clean up camera
    super.dispose();
  }

  // Fix Camera Freeze on App Switch
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final controller = CameraController(
        cameras.first, 
        ResolutionPreset.medium, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await controller.initialize();
      if (mounted) {
        setState(() => _controller = controller);
      }
    } catch (e) {
      print("Camera Init Error: $e");
    }
  }

  void _startBodyDoubleMonitor() {
    _stuckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!_hasMovedRecently && mounted) {
        _tts.speak("I noticed we stopped. Is there a blocker? Let's just do one tiny thing.");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("👀 Buddy: Are we stuck?"),
          backgroundColor: Colors.orange,
          action: SnackBarAction(label: "I'm working!", onPressed: _resetStuckTimer),
        ));
      }
      _hasMovedRecently = false;
    });
  }

  void _resetStuckTimer() {
    _hasMovedRecently = true;
  }

  Future<void> _speakCurrentTask() async {
    if (widget.tasks.isNotEmpty && _currentStep < widget.tasks.length) {
      await _tts.speak(widget.tasks[_currentStep]['title']);
    }
  }

  Future<void> _scanForCurrentObject() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.tasks.isEmpty) return;
    
    _resetStuckTimer();
    setState(() => _isScanning = true);
    _tts.speak("Scanning for ${widget.tasks[_currentStep]['title']}...");

    try {
      // 1. Take Picture
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      
      // 2. Check if user left the screen while we were taking the picture
      if (!mounted) return;

      final taskName = widget.tasks[_currentStep]['title'];
      
      // 3. Ask AI
      final response = await RemoteAIService.processRequest(
        userQuery: "Where is the '$taskName'? Return box_2d only. If not visible return null.",
        imageBytes: bytes,
        userSettings: widget.settings,
      );

      // 4. Update UI (Only if still on screen)
      
    } catch (e) {
      if (mounted) _tts.speak("Error scanning.");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _nextStep() {
    _resetStuckTimer();
    setState(() {
      if (_currentStep < widget.tasks.length - 1) {
        _currentStep++;
        _currentArBox = null;
        _speakCurrentTask();
      } else {
        _tts.speak("Mission Accomplished! You are amazing.");
        widget.settings.incrementStreak();
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text("No tasks generated.", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onClose,
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading spinner if camera isn't ready
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final task = widget.tasks[_currentStep];

    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera Preview
          Positioned.fill(child: CameraPreview(_controller!)),
          
          // 2. AR Overlay
          if (_currentArBox != null)
            Positioned.fill(child: CustomPaint(painter: ARBoxPainter(_currentArBox!))),

          // 3. Scanning Indicator
          if (_isScanning)
             const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

          // 4. Task UI Card
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
                     Text(task['title'] ?? "Task", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
          
          // 5. Back Button
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

class ARBoxPainter extends CustomPainter {
  final List<int> box;
  ARBoxPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 6.0;
    
    if (box.length < 4) return;

    // Normalize coordinates (0-1000) to screen size
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