import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart'; 

import '../logic/advanced_logger.dart'; 
import '../logic/remote_ai_service.dart';
import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../logic/pii_masker.dart';
import '../domain/ai_response.dart';
import '../logic/local_llm_service.dart';
import '../logic/offline_vision_service.dart';
import '../data/history_repository.dart';
import 'interactive_task_screen.dart'; // Ensure this is imported for Focus Mode

class TaskBreakdownScreen extends StatefulWidget {
  const TaskBreakdownScreen({super.key});

  @override
  State<TaskBreakdownScreen> createState() => _TaskBreakdownScreenState();
}

class _TaskBreakdownScreenState extends State<TaskBreakdownScreen> {
  // 🔀 TOGGLE STATE: Default to Gamified (true) or Focus (false)
  bool _isGamifiedMode = true; 

  bool _forceTextMode = false;
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _textBeforeListening = "";
  final TextEditingController _textController = TextEditingController();

  Uint8List? _pendingImageBytes;
  Uint8List? _sessionImageBytes;
  bool _isLoading = false;
  String _statusMessage = "";

  double _currentEnergy = 0.5;
  bool _isOverwhelmed = false;
  
  // ✅ GAMIFICATION STATE
  List<Map<String, dynamic>> _steps = []; 
  int _focusIndex = 0;
  AIResponse? _currentAiResponse;
  late ConfettiController _confettiController;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _textController.dispose();
    _confettiController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<String> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;

    const storage = FlutterSecureStorage();
    String? deviceId = await storage.read(key: 'device_user_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await storage.write(key: 'device_user_id', value: deviceId);
    }
    return deviceId;
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _textBeforeListening = _textController.text; 
        });
        
        _speech.listen(
          onResult: (val) {
            setState(() {
              String spacer = (_textBeforeListening.isNotEmpty && !_textBeforeListening.endsWith(' ')) ? " " : "";
              _textController.text = "$_textBeforeListening$spacer${val.recognizedWords}";
              
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length)
              );
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickAttachment() async {
    if (_isLoading) return;
    final XFile? media = await _picker.pickImage(source: ImageSource.camera);
    if (media == null) return;
    final bytes = await media.readAsBytes();
    final compressed = await _compressImage(bytes);
    setState(() {
      _pendingImageBytes = compressed;
      _forceTextMode = false;
    });
  }

  Future<Uint8List> _compressImage(Uint8List rawBytes) async {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final resized = img.copyResize(decoded, width: 800);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }

  void _sendMessage() {
    if (_isLoading) return;
    final text = _textController.text.trim();

    if (text.isEmpty && _pendingImageBytes == null) return;

    if (_pendingImageBytes != null) {
      _sessionImageBytes = _pendingImageBytes;
    }

    if (text.toLowerCase().contains("overwhelmed") ||
        text.toLowerCase().contains("stuck")) {
      _isOverwhelmed = true;
    }

    AdvancedLogger().log(
      LogType.user, 
      "User Input", 
      text.isEmpty ? "[Image Only]" : text, 
      jsonContent: {
        "hasImage": _pendingImageBytes != null,
        "isVoice": _isListening, 
        "isOverwhelmed": context.read<NeuroSettings>().isOverwhelmed,
        "energyLevel": context.read<NeuroSettings>().energyLevel
      }
    );

    _processTaskRequest(
      textInput: text,
      imageBytes: _forceTextMode ? null : _pendingImageBytes,
    );

    _textController.clear();
    setState(() {
      _pendingImageBytes = null;
    });
  }

  // ==========================================================
  // 🧠 CORE LOGIC (HANDLES BOTH MODES)
  // ==========================================================

  Future<void> _processTaskRequest({
    String? textInput,
    Uint8List? imageBytes,
  }) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing...";
      _steps.clear(); 
    });

    try {
      final settings = context.read<NeuroSettings>();
      String finalQuery = PIIMasker.mask(textInput ?? "");
      String visualContext = "";

      if (imageBytes != null) {
        setState(() => _statusMessage = "Scanning objects (Offline)...");
        try {
          final detectedObjects = await OfflineVisionService.analyzeImage(imageBytes);
          if (detectedObjects.isNotEmpty) {
            visualContext = detectedObjects.join(', ');
            finalQuery += "\n\n[Visual Context]: I see $visualContext";
          }
        } catch (e) {
          debugPrint("Vision Error: $e");
        }
      } 

      AIResponse? aiResponse;
      final useLocal = context.read<NeuroSettings>().useLocalModel;

      if (useLocal && (imageBytes == null || visualContext.isNotEmpty)) {
        try {
           setState(() => _statusMessage = "Thinking (Offline)...");
           final localText = await LocalLLMService.generateResponse(
             "You are a helpful planner. Output valid JSON for this goal: $finalQuery"
           );

           if (localText != null && localText.contains("{")) {
             final startIndex = localText.indexOf('{');
             final endIndex = localText.lastIndexOf('}');
             final jsonStr = localText.substring(startIndex, endIndex + 1);
             aiResponse = AIResponse.fromJson(json.decode(jsonStr));
           }
        } catch (e) {
           debugPrint("Local LLM Failed: $e");
        }
      }

      if (aiResponse == null) {
        setState(() => _statusMessage = "Connecting to Cloud...");
        aiResponse = await RemoteAIService.processRequest(
          userQuery: finalQuery,
          imageBytes: imageBytes,
          userSettings: settings,
          energy: settings.energyLevel,
          isOverwhelmed: settings.isOverwhelmed,
        );
      }

      if (!mounted) return;

      if (aiResponse!.mode == "clarification") {
        _showClarificationDialog(aiResponse, finalQuery);
      } else if (aiResponse.actions.isNotEmpty) {
        _saveToHistorySafely(finalQuery, aiResponse, imageBytes);
        
        // 🔀 FORK IN THE ROAD: Check which mode we are in!
        setState(() {
          _currentAiResponse = aiResponse;
          _steps = aiResponse!.actions.map((action) => {
            "text": action.instruction, 
            "done": false,
            "seconds": action.estimatedSeconds ?? 60
          }).toList();
        });
      }
    } catch (e) {
      _showErrorMessage("Connection failed. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToHistorySafely(String query, AIResponse response, Uint8List? imageBytes) async {
    try {
       final userId = await _getUserId();
       HistoryRepository().saveInteraction(
         userId: userId,
         userPrompt: query,
         aiResponse: "Generated ${response.actions.length} steps: ${response.missionName}",
         imageBytes: imageBytes,
       );
    } catch (e) {
      debugPrint("History Save Error: $e");
    }
  }

  // ==========================================================
  // ✅ GAMIFICATION LOGIC (XP & CONFETTI)
  // ==========================================================

  void _toggleStep(int index, bool? value) {
    setState(() {
      _steps[index]['done'] = value;
    });

    if (value == true) {
      final settings = context.read<NeuroSettings>();
      settings.awardXp(10);
      _confettiController.play(); 
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✨ Awesome! +10 XP (Total: ${settings.xp + 10})"),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    
    if (_steps.every((s) => s['done'] == true)) {
       context.read<NeuroSettings>().awardXp(50);
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text("🏆 MISSION COMPLETE! +50 XP"), 
           backgroundColor: Colors.purple,
         )
       );
    }
  }

  void _completeStep(int index) {
    setState(() {
      _steps[index]['done'] = true;
    });

    // Gamification Rewards
    final settings = context.read<NeuroSettings>();
    settings.awardXp(10);
    _confettiController.play(); 
    
    // Feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ Awesome! +10 XP (Total: ${settings.xp + 10})"),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Auto-advance in focus mode
    if (!_isGamifiedMode && _focusIndex < _steps.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if(mounted) {
          setState(() => _focusIndex++);
          _tts.speak(_steps[_focusIndex]['text']);
        }
      });
    }

    if (_steps.every((s) => s['done'] == true)) {
       context.read<NeuroSettings>().awardXp(50);
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text("🏆 MISSION COMPLETE! +50 XP"), 
           backgroundColor: Colors.purple,
         )
       );
    }
  }

  void _showClarificationDialog(AIResponse response, String contextText) {
    final dynamicOptions = _generateDynamicOptions(response.options, contextText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                const Icon(Icons.help_outline, size: 40, color: Colors.teal),
                const SizedBox(height: 10),
                Text(
                  response.question ??  "What would you like to do?",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ...dynamicOptions.map((option) => ListTile(
                  title: Text(option),
                  onTap: () {
                    Navigator.pop(context);
                    if (option == "I will type my goal") {
                      setState(() {
                        _forceTextMode = true;
                        _pendingImageBytes = null;
                        _sessionImageBytes = null;
                      });
                      return;
                    }
                    String combinedContext = "Context: The AI asked '${response.question}'. User replied: '$option'. Create a plan.";
                    _processTaskRequest(textInput: combinedContext, imageBytes: _sessionImageBytes);
                  },
                )).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _generateDynamicOptions(List<String>? aiOptions, String contextText) {
    final options = <String>[];
    if (aiOptions != null && aiOptions.isNotEmpty) options.addAll(aiOptions);
    if (!options.contains("I will type my goal")) options.add("I will type my goal");
    return options.toSet().toList();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_pendingImageBytes!, height: 60, width: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text("Image attached - Ready to send")),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => setState(() => _pendingImageBytes = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CONSUMER TO WATCH XP UPDATES LIVE
    final xp = context.select<NeuroSettings, int>((s) => s.xp);
    final level = context.select<NeuroSettings, int>((s) => s.level);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Tasks!"),
            actions: [
              // 🔀 MODE SWITCHER
              Row(
                children: [
                   Icon(
                     _isGamifiedMode ? Icons.casino : Icons.self_improvement, 
                     color: _isGamifiedMode ? Colors.purple : Colors.teal,
                     size: 20,
                   ),
                   Switch(
                     value: _isGamifiedMode,
                     activeColor: Colors.purple,
                     activeTrackColor: Colors.purple.shade100,
                     inactiveThumbColor: Colors.teal,
                     inactiveTrackColor: Colors.teal.shade100,
                     onChanged: (val) {
                       setState(() {
                         _isGamifiedMode = val;
                         // Clear steps if switching to focus mode so it doesn't look cluttered
                         if (!val && _steps.isNotEmpty) {
                           // Speak first step when switching to focus
                           _tts.speak(_steps[_focusIndex]['text']);
                         }
                       });
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                         content: Text(val ? "🎲 Gamified Mode: Checklist + XP" : "🧘 Focus Mode: Step-by-Step Guide"),
                         duration: const Duration(seconds: 1),
                       ));
                     },
                   ),
                ],
              ),
              
              // 🏆 LIVE XP COUNTER (Only show in Gamified Mode?)
              // Actually, showing it always is nice motivation
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Chip(
                  avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                  label: Text("Lvl $level"),
                  backgroundColor: Colors.teal.shade50,
                ),
              )
            ],
          ),
          body: Column(
            children: [
              // 🖥️ DYNAMIC BODY BASED ON MODE
              Expanded(
                child: _isLoading
                    ? Center(child: Text(_statusMessage))
                    : _buildMainContent(),
              ),
              if (_pendingImageBytes != null) _buildImagePreview(),
              _buildInputBar(),
            ],
          ),
        ),
        
        // 🎉 CONFETTI (Only overlays if in Gamified Mode)
        if (_isGamifiedMode)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
      ],
    );
  }

  // 📄 BUILD CONTENT BASED ON MODE
 
    Widget _buildMainContent() {
    if (_steps.isEmpty) {
      return _buildPlaceholder();
    }

    if (_isGamifiedMode) {
      return _buildListView();
    } else {
      return _buildFocusView();
    }
  }

  Widget _buildFocusView() {
    // Safety check
    if (_focusIndex >= _steps.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text("All Done!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() => _focusIndex = 0),
              child: const Text("Restart"),
            )
          ],
        ),
      );
    }

    final step = _steps[_focusIndex];
    final isDone = step['done'] == true;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: (_focusIndex + 1) / _steps.length,
            backgroundColor: Colors.grey.shade200,
            color: Colors.teal,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 10),
          Text("Step ${_focusIndex + 1} of ${_steps.length}", style: TextStyle(color: Colors.grey.shade600)),
          
          const Spacer(),
          
          Text(
            step['text'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26, 
              fontWeight: FontWeight.bold, 
              height: 1.3
            ),
          ),
          
          const SizedBox(height: 20),
          if (step['seconds'] != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.grey, size: 18),
                const SizedBox(width: 5),
                Text("${step['seconds']}s estimated", style: const TextStyle(color: Colors.grey)),
              ],
            ),

          const Spacer(),

          // ✅ BIG FOCUS BUTTON
          SizedBox(
            width: double.infinity,
            height: 70,
            child: ElevatedButton(
              onPressed: isDone ? null : () => _completeStep(_focusIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? Colors.grey : Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: isDone 
                ? const Text("Completed", style: TextStyle(fontSize: 20, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 28, color: Colors.white),
                      SizedBox(width: 10),
                      Text("Mark Done", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 10),
          // Navigation controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _focusIndex > 0 ? () => setState(() => _focusIndex--) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _focusIndex < _steps.length - 1 ? () => setState(() => _focusIndex++) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 📋 LIST VIEW (Gamified)
  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _steps.length,
      separatorBuilder: (_,__) => const Divider(),
      itemBuilder: (ctx, index) {
        final step = _steps[index];
        return CheckboxListTile(
          title: Text(step['text'], 
            style: TextStyle(
              decoration: step['done'] ? TextDecoration.lineThrough : null,
              color: step['done'] ? Colors.grey : Colors.black,
            ),
          ),
          value: step['done'],
          activeColor: Colors.teal,
          onChanged: (val) {
            setState(() {
              step['done'] = val;
            });
            if (val == true) {
              _completeStep(index);
            }
          },
        ).animate().fadeIn(delay: (index * 50).ms).slideX();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isGamifiedMode ? Icons.checklist : Icons.filter_center_focus, 
            size: 64, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 10),
          Text(
            " I am Iron Man!", 
            style: TextStyle(fontSize: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_a_photo), onPressed: _pickAttachment),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(hintText: "What's the goal?", border: InputBorder.none),
              ),
            ),
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.grey),
              onPressed: _toggleListening,
            ),
            FloatingActionButton(
              mini: true,
              onPressed: _sendMessage,
              backgroundColor: Colors.teal,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}