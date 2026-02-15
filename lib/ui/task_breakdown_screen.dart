import 'dart:async';
import 'dart:math';
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
import 'package:audioplayers/audioplayers.dart';

import '../logic/task_classifier.dart'; 
import '../logic/advanced_logger.dart'; 
import '../logic/remote_ai_service.dart';
import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../logic/pii_masker.dart';
import '../domain/ai_response.dart';
import '../logic/local_llm_service.dart';
import '../logic/offline_vision_service.dart';
import '../data/history_repository.dart';
import 'panic_mode_screen.dart';

class TaskBreakdownScreen extends StatefulWidget {
  const TaskBreakdownScreen({super.key});

  @override
  State<TaskBreakdownScreen> createState() => _TaskBreakdownScreenState();
}

class _TaskBreakdownScreenState extends State<TaskBreakdownScreen> {
  // 🔀 TOGGLE STATE
  bool _isGamifiedMode = false; 
  bool _isBodyDoubleActive = true;
  final AudioPlayer _musicPlayer = AudioPlayer();

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
  
  // ✅ DATA STATE
  List<Map<String, dynamic>> _steps = []; 
  int _focusIndex = 0;
  AIResponse? _currentAiResponse;
  
  // ✅ ANIMATION & TTS
  late ConfettiController _confettiController;
  final FlutterTts _tts = FlutterTts();
  
  // 🧠 SMART INTERVENTION STATE
  Timer? _bodyDoubleMonitor;
  final Stopwatch _stepStopwatch = Stopwatch(); 
  int _interventionLevel = 0;
  
  // 📊 ADAPTIVE PACE TRACKER
  final List<double> _paceHistory = [];
  double _currentPaceFactor = 1.0; 

  // 🎓 DYNAMIC STUDY MODE STATE (NEW)
  bool _isFocusAudioPlaying = false;
  String _currentFocusAudio = "Brown Noise"; // ADHD Favorite
  bool _isPodcastLoading = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _initTts();
    _startSmartBodyDouble(); 
  }

  Future<void> _initTts() async {
    // UX FIX: Allow audio to mix with others
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers
    ]);

    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true); 
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      final settings = context.read<NeuroSettings>();
      final String selectedLangName = settings.preferredLanguage.toLowerCase();
      String locale = "en-US"; 

      if (selectedLangName.contains("italiano")) {
        locale = "it-IT";
      } else if (selectedLangName.contains("hindi")) {
        locale = "hi-IN"; 
      } else if (selectedLangName.contains("español") || selectedLangName.contains("spanish")) {
        locale = "es-ES";
      } else if (selectedLangName.contains("deutsch") || selectedLangName.contains("german")) {
        locale = "de-DE";
      } else if (selectedLangName.contains("français") || selectedLangName.contains("french")) {
        locale = "fr-FR";
      }

      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
      await _tts.setLanguage("en-US");
      await _tts.speak(text);
    }
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    _textController.dispose();
    _confettiController.dispose();
    _tts.stop();
    _bodyDoubleMonitor?.cancel();
    _stepStopwatch.stop();
    super.dispose();
  }

  // 🧠 SMART LOOP
  void _startSmartBodyDouble() {
    _bodyDoubleMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isBodyDoubleActive || _steps.isEmpty || _isLoading || _focusIndex >= _steps.length) return;

      final currentStep = _steps[_focusIndex];
      final int baseEstimate = currentStep['seconds'] ?? 45;
      final double adjustedLimit = baseEstimate * _currentPaceFactor;
      final int elapsed = _stepStopwatch.elapsed.inSeconds;

      if (_interventionLevel == 0 && elapsed > (adjustedLimit * 1.5)) {
        _triggerIntervention(1); 
      } else if (_interventionLevel == 1 && elapsed > (adjustedLimit * 2.5)) {
        _triggerIntervention(2); 
      } else if (_interventionLevel == 2 && elapsed > (adjustedLimit * 4.0)) {
        _triggerIntervention(3); 
      }
    });
  }

  void _triggerIntervention(int level) async {
    setState(() => _interventionLevel = level);
    final currentStep = _steps[_focusIndex];
    String msg = _getSmartBodyDoubleMessage(level, currentStep);
    await _speak(msg);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [const Icon(Icons.support_agent, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(msg))]),
          backgroundColor: Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: level == 3 ? SnackBarAction(label: "Skip", textColor: Colors.tealAccent, onPressed: () => _completeStep(_focusIndex)) : null,
        ),
      );
    }
  }

  String _getSmartBodyDoubleMessage(int level, Map<String, dynamic> step) {
    final text = step['text'].toString();
    final seconds = step['seconds'] as int? ?? 60;
    final settings = context.read<NeuroSettings>();
    
    final TaskType type = TaskClassifier.classify(text);
    final String subject = _extractTaskSubject(text); 

    final bool isLowEnergy = settings.energyLevel < 0.4;
    final bool isOverwhelmed = settings.isOverwhelmed;
    final bool isHighEnergy = settings.energyLevel > 0.8;
    final bool isQuick = seconds <= 45;
    final bool isLong = seconds >= 120;

    if (isOverwhelmed) {
      if (level == 1) return "I know it feels loud right now. Just breathe. I am holding the space for you.";
      if (level == 2) return "Forget the outcome. Just do the smallest, tiniest part of '$subject'.";
      return "This is too much for right now. Let's skip it and protect your peace.";
    }

    if (level == 1) {
      if (isHighEnergy && type == TaskType.physical) {
        return _random(["You've got momentum! Crush this ${isQuick ? 'quick ' : ''}step.", "Keep that energy up. $subject is almost done.", "Speed run mode: Let's finish this in 20 seconds."]);
      }
      if (isLowEnergy) {
        return _random(["I know energy is low. We are moving slowly, and that is okay.", "Gentle focus. Just look at the $subject.", "No rush. One breath, one movement."]);
      }
      switch (type) {
        case TaskType.social: return "Social tasks drain battery. Draft it now, send it later.";
        case TaskType.cognitive: return "If the brain fog is creeping in, just read the first sentence.";
        case TaskType.physical: return "Action creates motivation. Just move your hands towards the $subject.";
        default: return "I'm still here. We are focusing on: $text.";
      }
    }

    if (level == 2) {
      if (type == TaskType.physical) return _random(["Let's make it weird. Try doing this step standing on one leg.", "Can you do this step with your non-dominant hand?", "Don't 'clean' the $subject. Just touch it."]);
      if (type == TaskType.cognitive) return _random(["Analysis paralysis? Pick the FIRST option you see.", "Don't try to be perfect. Be messy.", "Your brain is resisting. Trick it: Do only 10%."]);
      if (type == TaskType.social) return "I'm right here. Write the 'ugly draft'. No one has to see it yet.";
      return "We are stuck. Let's reset: Stand up, shake your arms, sit back down.";
    }

    if (level == 3) {
      if (isLong) return "This step is too big for today's brain. Let's skip it and stay winning.";
      return _random(["It seems like a wall. It is 100% okay to skip this and move on.", "Perfectionism is the enemy. Mark it 'done enough' and let's go.", "We are not going to freeze here. Skipping is a strategic victory."]);
    }
    return "You are doing great.";
  }

  // ==========================================================
  // 🎓 DYNAMIC STUDY MODE FEATURES
  // ==========================================================

  // 1. 🎵 FOCUS AUDIO (Simulated)
  // Replace your existing dummy _toggleFocusAudio with this:
Future<void> _toggleFocusAudio() async {
  setState(() => _isFocusAudioPlaying = !_isFocusAudioPlaying);
  
  if (_isFocusAudioPlaying) {
    String url = "https://ia800300.us.archive.org/1/items/brown-noise-2-hours/Brown%20Noise%202%20Hours.mp3"; // Default Brown Noise
    // Simple switch for other tracks based on _currentFocusAudio string
    if (_currentFocusAudio.contains("White")) url = "https://ia800504.us.archive.org/13/items/pink-noise-60-minutes/Pink%20Noise%2060%20minutes.mp3"; 
    
    await _musicPlayer.play(UrlSource(url));
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
  } else {
    await _musicPlayer.stop();
  }
}

  // 2. 🎧 PODCAST MODE LOGIC
  Future<void> _activatePodcastMode() async {
    String contextText = "";
    if (_steps.isNotEmpty) {
      contextText = "The current task step is: ${_steps[_focusIndex]['text']}.";
    } else if (_textController.text.isNotEmpty) {
      contextText = "The topic is: ${_textController.text}.";
    } else {
      _showInputForPodcast(); 
      return;
    }

    Navigator.pop(context); // Close sheet
    setState(() => _isPodcastLoading = true);
    
    try {
      final String prompt = """
      You are a friendly, energetic podcast host. 
      Take the following text and rewrite it as a short, engaging 30-second podcast script.
      Use simple language, maybe a metaphor, and make it sound exciting to learn/do.
      TEXT: $contextText
      """;

      final aiResponse = await RemoteAIService.processRequest(
        userQuery: prompt, 
        userSettings: context.read<NeuroSettings>(), 
        energy: _currentEnergy, 
        isOverwhelmed: false
      );

      final script = aiResponse.missionName ?? "I couldn't generate a script."; 
      
      setState(() => _isPodcastLoading = false);
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("🎙️ Podcast Mode"),
          content: SingleChildScrollView(child: Text(script)),
          actions: [TextButton(onPressed: () => _tts.stop(), child: const Text("Stop"))],
        ),
      );

      await _tts.setSpeechRate(0.55); 
      await _speak(script);

    } catch (e) {
      setState(() => _isPodcastLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Podcast generation failed.")));
    }
  }

  void _showInputForPodcast() {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text("Paste Study Text"),
          content: TextField(controller: c, maxLines: 5, decoration: const InputDecoration(hintText: "Paste notes here...")),
          actions: [
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _textController.text = c.text; 
              _activatePodcastMode();
            }, child: const Text("Make Podcast"))
          ],
        );
      }
    );
  }

  // ==========================================================
  // ⚙️ MISSION CONTROL (UPDATED UI)
  // ==========================================================
  void _showTaskSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Mission Control 🎛️", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // --- 1. VIEW MODES ---
                    SwitchListTile(
                      title: const Text("Gamified List View"),
                      subtitle: const Text("Show all tasks at once"),
                      value: _isGamifiedMode,
                      activeColor: Colors.purple,
                      secondary: Icon(_isGamifiedMode ? Icons.list : Icons.filter_center_focus),
                      onChanged: (val) {
                        setSheetState(() => _isGamifiedMode = val);
                        setState(() => _isGamifiedMode = val);
                      },
                    ),
                    const Divider(),

                    // --- 2. Buddy ---
                    SwitchListTile(
                      title: const Text("Smart Buddy"),
                      subtitle: Text(_isBodyDoubleActive ? "Adaptive Monitoring On" : "Disabled"),
                      value: _isBodyDoubleActive,
                      activeColor: Colors.teal,
                      secondary: const Icon(Icons.record_voice_over),
                      onChanged: (val) {
                        setSheetState(() => _isBodyDoubleActive = val);
                        setState(() {
                          _isBodyDoubleActive = val;
                          if (val) {
                            _stepStopwatch.start();
                            if (_steps.isNotEmpty) _speak("I'm monitoring.");
                          } else {
                            _stepStopwatch.stop();
                            _tts.stop();
                          }
                        });
                      },
                    ),

                    const Divider(),

                    // --- 3. 🎓 STUDY TOOLS (NEW) ---
                    const Text("Dynamic Study Mode", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    // Focus Audio
                    ListTile(
                      leading: Icon(_isFocusAudioPlaying ? Icons.volume_up : Icons.volume_off, color: Colors.brown),
                      title: const Text("Focus Audio"),
                      subtitle: Text(_currentFocusAudio),
                      trailing: DropdownButton<String>(
                        value: _currentFocusAudio,
                        underline: Container(),
                        items: ["Brown Noise", "White Noise", "Lo-Fi Beats"].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => _currentFocusAudio = val!);
                          setState(() => _currentFocusAudio = val!);
                          if (_isFocusAudioPlaying) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to $val")));
                          }
                        },
                      ),
                      onTap: () {
                        _toggleFocusAudio();
                        Navigator.pop(context);
                        setSheetState(() {}); 
                      },
                    ),

                    // Podcast Mode
                    ListTile(
                      leading: const Icon(Icons.headphones, color: Colors.blueAccent),
                      title: const Text("Podcast Mode"),
                      subtitle: const Text("Turn text into a fun audio script."),
                      onTap: () => _activatePodcastMode(),
                    ),

                    const Divider(),

                    // --- 4. EMERGENCY ---
                    ListTile(
                      leading: const Icon(Icons.health_and_safety, color: Color.fromARGB(255, 109, 233, 255)),
                      title: const Text("Panic Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 109, 233, 255))),
                      subtitle: const Text("Immediate sensory reduction."),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PanicModeScreen()));
                      },
                    ),
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }

  // ------------------------------------------------------------------------
  // HELPER METHODS (Preserved)
  // ------------------------------------------------------------------------

  String _extractTaskSubject(String text) {
    final words = text.split(' ');
    if (words.isEmpty) return "task";
    String longest = words.reduce((a, b) => a.length > b.length ? a : b);
    return longest.replaceAll(RegExp(r'[^\w\s]'), '');
  }

  String _random(List<String> options) {
    return options[Random().nextInt(options.length)];
  }

  void _updateUserModel(int stepIndex) {
    final step = _steps[stepIndex];
    final int estimated = step['seconds'] ?? 45;
    final int actual = _stepStopwatch.elapsed.inSeconds;
    
    if (estimated > 0) {
      double ratio = actual / estimated;
      ratio = ratio.clamp(0.5, 3.0); 
      _paceHistory.add(ratio);
      double sum = _paceHistory.fold(0, (p, c) => p + c);
      setState(() {
        _currentPaceFactor = sum / _paceHistory.length;
      });
    }
    _stepStopwatch.reset();
    _interventionLevel = 0;
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
        onStatus: (val) { if (val == 'done' || val == 'notListening') setState(() => _isListening = false); },
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() { _isListening = true; _textBeforeListening = _textController.text; });
        _speech.listen(onResult: (val) {
          setState(() {
            String spacer = (_textBeforeListening.isNotEmpty && !_textBeforeListening.endsWith(' ')) ? " " : "";
            _textController.text = "$_textBeforeListening$spacer${val.recognizedWords}";
            _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
          });
        });
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
    setState(() { _pendingImageBytes = compressed; _forceTextMode = false; });
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
    if (_pendingImageBytes != null) _sessionImageBytes = _pendingImageBytes;

    final settings = context.read<NeuroSettings>();
    if (text.toLowerCase().contains("overwhelmed") || text.toLowerCase().contains("stuck")) {
      _isOverwhelmed = true;
    } else {
      _isOverwhelmed = settings.isOverwhelmed;
    }
    _currentEnergy = settings.energyLevel;

    AdvancedLogger().log(LogType.user, "User Input", text.isEmpty ? "[Image Only]" : text, 
      jsonContent: { "hasImage": _pendingImageBytes != null, "isVoice": _isListening, "isOverwhelmed": _isOverwhelmed, "energyLevel": _currentEnergy }
    );

    _processTaskRequest(textInput: text, imageBytes: _forceTextMode ? null : _pendingImageBytes);
    _textController.clear();
    setState(() => _pendingImageBytes = null);
  }

  Future<void> _processTaskRequest({String? textInput, Uint8List? imageBytes}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing...";
      _steps.clear(); 
      _focusIndex = 0;
      _paceHistory.clear(); 
      _currentPaceFactor = 1.0;
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
           final localText = await LocalLLMService.generateResponse("You are a helpful planner. Output valid JSON for this goal: $finalQuery");
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
          energy: _currentEnergy,
          isOverwhelmed: _isOverwhelmed,
        );
      }

      if (!mounted) return;

      if (aiResponse!.mode == "clarification") {
        _showClarificationDialog(aiResponse, finalQuery);
      } else if (aiResponse.actions.isNotEmpty) {
        _saveToHistorySafely(finalQuery, aiResponse, imageBytes);
        
        setState(() {
          _currentAiResponse = aiResponse;
          _steps = aiResponse!.actions.map((action) => {
            "text": action.instruction, 
            "done": false,
            "seconds": action.estimatedSeconds ?? 60
          }).toList();
        });

        if (_isBodyDoubleActive) {
          _stepStopwatch.start();
          _speak("I'm monitoring. Let's start: ${_steps[0]['text']}");
        }
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

  void _toggleStep(int index, bool? value) {
    setState(() { _steps[index]['done'] = value; });
    if (value == true) _onStepCompleted(index);
  }

  void _completeStep(int index) {
    setState(() { _steps[index]['done'] = true; });
    _onStepCompleted(index);
  }

  void _onStepCompleted(int index) {
    _updateUserModel(index);

    final settings = context.read<NeuroSettings>();
    settings.awardXp(10);
    _confettiController.play(); 
    
    if (!_isGamifiedMode && _focusIndex < _steps.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if(mounted) {
          setState(() => _focusIndex++);
          if (_isBodyDoubleActive) _speak(_steps[_focusIndex]['text']);
          _stepStopwatch.start(); 
        }
      });
    }

    if (_steps.every((s) => s['done'] == true)) {
       context.read<NeuroSettings>().awardXp(50);
       _showCompletionCelebration();
       _stepStopwatch.stop();
    }
  }

  void _showCompletionCelebration() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Mission Complete! 🚀 +50 XP"),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _showClarificationDialog(AIResponse response, String contextText) {
    final dynamicOptions = _generateDynamicOptions(response.options, contextText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                const Icon(Icons.help_outline, size: 40, color: Colors.teal),
                const SizedBox(height: 10),
                Text(response.question ?? "What would you like to do?", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ...dynamicOptions.map((option) => ListTile(
                  title: Text(option),
                  onTap: () {
                    Navigator.pop(context);
                    if (option == "I will type my goal") {
                      setState(() { _forceTextMode = true; _pendingImageBytes = null; _sessionImageBytes = null; });
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
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_pendingImageBytes!, height: 60, width: 60, fit: BoxFit.cover)),
          const SizedBox(width: 12),
          const Expanded(child: Text("Image attached - Ready to send")),
          IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _pendingImageBytes = null)),
        ],
      ),
    );
  }

  Widget _buildXpHeader() {
    final xp = context.watch<NeuroSettings>().xp;
    final level = context.watch<NeuroSettings>().level;
    final progress = context.watch<NeuroSettings>().levelProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
            child: Center(child: Text("$level", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Level $level", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("$xp XP", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Tasks"),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.tune), onPressed: _showTaskSettings),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _buildXpHeader(),
              
              if (_isPodcastLoading) 
                const LinearProgressIndicator(color: Colors.blueAccent),

              Expanded(
                child: _isLoading ? Center(child: Text(_statusMessage)) : _buildMainContent(),
              ),
              if (_pendingImageBytes != null) _buildImagePreview(),
              _buildInputBar(),
            ],
          ),
        ),
        if (_isGamifiedMode)
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop: false, colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple])),
      ],
    );
  }

  Color _getProgressColor(double percent) {
    if (percent >= 1.0) return Colors.green;
    if (percent > 0.6) return Colors.lightGreen;
    if (percent > 0.3) return Colors.amber;
    return Colors.orange;
  }

  Widget _buildMainContent() {
    if (_steps.isEmpty) return _buildPlaceholder();
    if (_isGamifiedMode) return _buildListView();
    return _buildFocusView();
  }

  Widget _buildFocusView() {
    if (_focusIndex >= _steps.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text("All Done!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _showCompletionCelebration, child: const Text("Finish Mission"))
          ],
        ),
      );
    }

    final step = _steps[_focusIndex];
    final isDone = step['done'] == true;
    final progress = (_focusIndex + 1) / _steps.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      color: _getProgressColor(progress),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 10),
                    Text("Step ${_focusIndex + 1} of ${_steps.length}", style: TextStyle(color: Colors.grey.shade600)),
                    
                    const SizedBox(height: 40), 

                    Text(
                      step['text'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
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
                    
                    const SizedBox(height: 40),

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
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.check_circle_outline, size: 28, color: Colors.white),
                                SizedBox(width: 10),
                                Text("Mark Done", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                              ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: _focusIndex > 0 ? () => setState(() => _focusIndex--) : null),
                        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _focusIndex < _steps.length - 1 ? () => setState(() => _focusIndex++) : null),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _steps.length,
      separatorBuilder: (_,__) => const Divider(),
      itemBuilder: (ctx, index) {
        final step = _steps[index];
        return CheckboxListTile(
          title: Text(step['text'], style: TextStyle(decoration: step['done'] ? TextDecoration.lineThrough : null, color: step['done'] ? Colors.grey : Colors.black)),
          value: step['done'],
          activeColor: Colors.teal,
          onChanged: (val) => _toggleStep(index, val),
        ).animate().fadeIn(delay: (index * 50).ms).slideX();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("I am Iron Man!", style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
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
            Expanded(child: TextField(controller: _textController, decoration: const InputDecoration(hintText: "What's the goal?", border: InputBorder.none))),
            IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.grey), onPressed: _toggleListening),
            FloatingActionButton(mini: true, onPressed: _sendMessage, backgroundColor: Colors.teal, child: const Icon(Icons.arrow_upward, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}