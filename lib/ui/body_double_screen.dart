import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:audioplayers/audioplayers.dart';

import '../logic/neuro_settings.dart';
import '../logic/task_classifier.dart';
import '../logic/remote_ai_service.dart';
import '../logic/studio_prompt_builder.dart';
import '../logic/remote_studio_service.dart';

class BodyDoubleScreen extends StatefulWidget {
  const BodyDoubleScreen({super.key});

  @override
  State<BodyDoubleScreen> createState() => _BodyDoubleScreenState();
}

class _BodyDoubleScreenState extends State<BodyDoubleScreen>
    with TickerProviderStateMixin {
  final TextEditingController _taskController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  late ConfettiController _confettiController;
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _musicPlayer = AudioPlayer();

  // 🧠 SMART STATE
  bool _isActive = false;
  final Stopwatch _sessionStopwatch = Stopwatch();
  Timer? _monitorTimer;
  int _targetChunkMinutes = 20;
  int _interventionLevel = 0;

  // 🏷️ DYNAMIC CONTEXT
  TaskType _currentContext = TaskType.general;

  // 🎭 PERSONA STATE
  String _selectedPersona = "Buddy";
  final Map<String, String> _personas = {
    "Buddy": "a supportive friend",
    "RPG Master": "a Dungeon Master",
    "Drill Sergeant": "a tough coach",
    "Zen Guide": "a meditation teacher",
    "Professor": "an intellectual",
  };

  // 🎨 PERSONA COLORS
  Color _getPersonaColor() {
    switch (_selectedPersona) {
      case "RPG Master":
        return Colors.deepPurple;
      case "Drill Sergeant":
        return Colors.deepOrange;
      case "Zen Guide":
        return Colors.teal;
      case "Professor":
        return Colors.indigo;
      default:
        return Colors.blue;
    }
  }

  // 🎵 AUDIO STATE
  bool _isPlayingMusic = false;
  String _currentTrackName = "Brown Noise";

  final Map<String, String> _tracks = {
    "Brown Noise (Focus)":
        "https://raw.githubusercontent.com/anars/blank-audio/master/10-minutes-of-silence.mp3", // Replace with valid direct stream if needed
    "Lo-Fi Beats (Chill)":
        "https://codeskulptor-demos.commondatastorage.googleapis.com/GalaxyInvaders/theme_01.mp3",
    "RPG Dungeon (Dark)":
        "https://commondatastorage.googleapis.com/codeskulptor-assets/sounddogs/soundtrack.mp3",
    "Forest Rain (Calm)": "https://luan.xyz/files/audio/ambient_c_motion.mp3",
    "Pink Noise (Calm)": "https://www.soundjay.com/nature/rain-01.mp3",
  };

  // 🚀 QUICK ACTIONS
  final List<Map<String, dynamic>> _quickActions = [
    {
      "label": "Deep Work",
      "icon": Icons.code,
      "track": "Brown Noise (Focus)",
      "persona": "Buddy",
    },
    {
      "label": "Cleaning",
      "icon": Icons.cleaning_services,
      "track": "Lo-Fi Beats (Chill)",
      "persona": "RPG Master",
    },
    {
      "label": "Reading",
      "icon": Icons.menu_book,
      "track": "Forest Rain (Calm)",
      "persona": "Professor",
    },
    {
      "label": "Workout",
      "icon": Icons.fitness_center,
      "track": "Lo-Fi Beats (Chill)",
      "persona": "Drill Sergeant",
    },
  ];

  // 📸 PODCAST STATE
  Uint8List? _podcastImageBytes;
  bool _isGeneratingPodcast = false;
  bool _isPodcastPlaying = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _initTts();
    _musicPlayer.setReleaseMode(ReleaseMode.loop);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPodcastPlaying = false);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ]);
  }

  Future<void> _setPersonaVoice() async {
    switch (_selectedPersona) {
      case "Drill Sergeant":
        await _tts.setSpeechRate(0.6);
        await _tts.setPitch(0.8);
        break;
      case "Zen Guide":
        await _tts.setSpeechRate(0.35);
        await _tts.setPitch(1.1);
        break;
      case "Professor":
        await _tts.setSpeechRate(0.45);
        await _tts.setPitch(1.0);
        break;
      case "RPG Master":
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(0.6);
        break;
      default:
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _confettiController.dispose();
    _monitorTimer?.cancel();
    _tts.stop();
    _musicPlayer.dispose();
    super.dispose();
  }

  // 🧠 START SESSION LOGIC
  void _startSession([
    String? quickTask,
    String? quickTrack,
    String? quickPersona,
  ]) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    if (quickTask != null) _taskController.text = quickTask;
    if (quickTrack != null) _currentTrackName = quickTrack;
    if (quickPersona != null) _selectedPersona = quickPersona;

    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("What are we focusing on?")));
      return;
    }

    _analyzeContext(_taskController.text);

    // Auto-Dynamic Tuning
    if (quickTask == null) {
      if (_currentContext == TaskType.physical) {
        _selectedPersona = "Drill Sergeant";
        _currentTrackName = "Lo-Fi Beats (Chill)";
      } else {
        _selectedPersona = "Professor";
        _currentTrackName = "Brown Noise (Focus)";
      }
    }

    setState(() {
      _isActive = true;
      _interventionLevel = 0;
    });
    _sessionStopwatch.start();

    _toggleMusic(_currentTrackName);
    _speakAI(
      "Starting session: ${_taskController.text}. Mode: $_selectedPersona. Let's begin.",
    );
    _startMonitoringLoop();
  }

  void _analyzeContext(String task) {
    _currentContext = TaskClassifier.classify(task);
    if (_currentContext == TaskType.physical)
      _targetChunkMinutes = 15;
    else if (_currentContext == TaskType.cognitive)
      _targetChunkMinutes = 25;
    else
      _targetChunkMinutes = 20;
  }

  void _stopSession() {
    HapticFeedback.heavyImpact();
    _sessionStopwatch.stop();
    _sessionStopwatch.reset();
    _monitorTimer?.cancel();
    _tts.stop();
    _musicPlayer.stop();
    setState(() {
      _isActive = false;
      _isPlayingMusic = false;
    });
  }

  Future<void> _speakAI(String rawText, {bool isPrompt = false}) async {
    await _setPersonaVoice();
    String textToSpeak = rawText;

    if (isPrompt) {
      if (_selectedPersona == "RPG Master")
        textToSpeak = "Hero! Are you still battling the task?";
      if (_selectedPersona == "Drill Sergeant")
        textToSpeak = "Sound off! Are you working or slacking?";
      if (_selectedPersona == "Zen Guide")
        textToSpeak = "Notice your distraction. Gently return to focus.";
    }

    if (_isPlayingMusic) await _musicPlayer.setVolume(0.2);
    await _tts.speak(textToSpeak);
    Future.delayed(const Duration(seconds: 4), () {
      if (_isPlayingMusic && mounted) _musicPlayer.setVolume(1.0);
    });
  }

  void _startMonitoringLoop() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isActive) return;
      if (_sessionStopwatch.elapsed.inSeconds > 20 && _interventionLevel == 0) {
        _triggerIntervention(1);
      }
    });
  }

  void _triggerIntervention(int level) async {
    setState(() => _interventionLevel = level);
    _speakAI("Checking in.", isPrompt: true);
  }

  // =================================================================
  // 🎵 AUDIO PLAYER (SINGLE DEFINITION)
  // =================================================================
  Future<void> _toggleMusic(String trackName) async {
    final url = _tracks[trackName];
    if (url == null) return;

    if (_currentTrackName == trackName && _isPlayingMusic) {
      await _musicPlayer.pause();
      setState(() => _isPlayingMusic = false);
    } else {
      try {
        await _musicPlayer.stop();
        await _musicPlayer.play(UrlSource(url));
        setState(() {
          _currentTrackName = trackName;
          _isPlayingMusic = true;
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("▶️ Playing $trackName")));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Audio stream failed.")),
          );
      }
    }
  }

  void _showMusicSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🎧 Soundscapes",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._tracks.keys.map(
                (track) => ListTile(
                  leading: Icon(
                    _currentTrackName == track && _isPlayingMusic
                        ? Icons.graphic_eq
                        : Icons.play_arrow,
                    color: _getPersonaColor(),
                  ),
                  title: Text(track),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMusic(track);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // 🎙️ PRO PODCAST PLAYER UI (Improved)
  // =================================================================
  void _openPodcastMenu() {
    TextEditingController textInput = TextEditingController();
    _podcastImageBytes = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AI Studio",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          "Podcast with $_selectedPersona",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.mic_none, size: 32, color: _getPersonaColor()),
                  ],
                ),
              ),
              const Divider(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_podcastImageBytes != null)
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: MemoryImage(_podcastImageBytes!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => setSheetState(
                                    () => _podcastImageBytes = null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().scale(),

                      if (_podcastImageBytes == null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 40,
                                color: Colors.amber,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "I can turn your study notes into a podcast. Just paste text or snap a photo.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textInput,
                              maxLines: 4,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: "Paste text or topic here...",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _pickPodcastImage(setSheetState),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _getPersonaColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: _getPersonaColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  10,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isGeneratingPodcast
                        ? null
                        : () {
                            String promptText = textInput.text.trim();

                            // Fallback if text is empty but image is present
                            if (promptText.isEmpty &&
                                _podcastImageBytes != null) {
                              promptText = "The content in this image";
                            }

                            if (promptText.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please enter a topic or snap a photo.",
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context); // Close the input menu
                            _generateAndPlayPodcast(promptText);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPersonaColor(),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isGeneratingPodcast
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            "Generate Audio",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update this method in your BodyDoubleScreen class
  void _generateAndPlayPodcast(String textInput) async {
    setState(() => _isGeneratingPodcast = true);

    // 1. Ensure we tell the AI exactly what to look at if text is empty
    String finalTopic = textInput.trim();
    if (finalTopic.isEmpty && _podcastImageBytes != null) {
      finalTopic =
          "Analyze the provided image in extreme detail, transcribing any text or code and explaining its full purpose and logic.";
    }

    final prompt = StudioPromptBuilder.buildPodcastPrompt(
      topic: finalTopic,
      personaName: _selectedPersona,
      personaDescription: _personas[_selectedPersona]!,
      settings: context.read<NeuroSettings>(),
    );

    try {
      final script = await RemoteStudioService.generateStudioContent(
        prompt: prompt,
        imageBytes: _podcastImageBytes,
      );

      if (mounted) {
        // 2. STOP everything else immediately
        await _tts.stop();
        if (_isPlayingMusic) await _musicPlayer.setVolume(0.1);

        setState(() {
          _isGeneratingPodcast = false;
          _isPodcastPlaying = true;
        });

        _showActivePlayer(script);
        _playPodcastAudio(script);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPodcast = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection failed. Check API key.")),
        );
      }
    }
  }

  // Ensure the actual audio play call is awaited and clean
  void _playPodcastAudio(String script) async {
    await _tts.stop(); // Double-check stop
    await _setPersonaVoice();
    if (script.isNotEmpty) {
      await _tts.speak(script);
    }
  }

  void _showActivePlayer(String script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // ✅ Ensures it stays above the Android nav bar
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Container(
        // Allow the sheet to be tall enough to see everything
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          40,
        ), // ✅ Bottom padding for the button
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 25),

            const Icon(Icons.graphic_eq, size: 50, color: Colors.blueAccent)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 1000.ms),

            const SizedBox(height: 15),
            Text(
              "Podcast: $_selectedPersona",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Script View
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  script,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Button (Stop)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  _tts.stop();
                  if (_isPlayingMusic) _musicPlayer.setVolume(1.0);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.stop),
                label: const Text(
                  "STOP LISTENING",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Future<void> _pickPodcastImage(StateSetter setSheetState) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final resized = img.copyResize(decoded, width: 800);
        final compressed = Uint8List.fromList(
          img.encodeJpg(resized, quality: 70),
        );
        setSheetState(() => _podcastImageBytes = compressed);
        setState(() => _podcastImageBytes = compressed);
      }
    }
  }

  void _showPersonaSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎭 Choose Your Buddy",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._personas.keys.map(
              (p) => ListTile(
                leading: Icon(
                  Icons.face,
                  color: _selectedPersona == p
                      ? _getPersonaColor()
                      : Colors.grey,
                ),
                title: Text(p),
                subtitle: Text(_personas[p]!),
                onTap: () {
                  setState(() => _selectedPersona = p);
                  Navigator.pop(context);
                  _speakAI("Persona updated.");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Buddy"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.theater_comedy),
                onPressed: _showPersonaSelector,
                tooltip: "Change Persona",
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child:
                    Icon(
                          Icons.circle,
                          color: _isActive ? Colors.green : Colors.grey,
                          size: 12,
                        )
                        .animate(target: _isActive ? 1 : 0)
                        .fadeIn()
                        .then()
                        .shimmer(duration: 2000.ms),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isActive ? _stopSession : null,
                      child:
                          Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isActive
                                      ? _getPersonaColor().withOpacity(0.1)
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: _isActive
                                        ? _getPersonaColor()
                                        : Colors.grey.shade300,
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _isActive
                                        ? Icons.face
                                        : Icons.face_retouching_off,
                                    size: 80,
                                    color: _isActive
                                        ? _getPersonaColor()
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              )
                              .animate(target: _isActive ? 1 : 0)
                              .scale(duration: 500.ms),
                    ),
                    const SizedBox(height: 40),

                    if (!_isActive) ...[
                      // Quick Start Grid
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: _quickActions
                            .map(
                              (action) => ActionChip(
                                avatar: Icon(
                                  action['icon'],
                                  size: 18,
                                  color: _getPersonaColor(),
                                ),
                                label: Text(action['label']),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey.shade200),
                                elevation: 1,
                                onPressed: () => _startSession(
                                  action['label'],
                                  action['track'],
                                  action['persona'],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 30),
                      // ... TextField ...
                      TextField(
                        controller: _taskController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Or type custom task...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.black26),
                        ),
                      ),
                    ] else ...[
                      Text(
                        _taskController.text,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ToolButton(
                            icon: Icons.mic,
                            label: "Studio",
                            color: _getPersonaColor(),
                            onTap: _openPodcastMenu,
                          ),
                          const SizedBox(width: 12),
                          _ToolButton(
                            icon: _isPlayingMusic
                                ? Icons.graphic_eq
                                : Icons.music_note,
                            label: "Music",
                            color: Colors.orange,
                            onTap: _showMusicSelector,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 30),
                    if (!_isActive)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Start Session"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPersonaColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => _startSession(),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton(
                          onPressed: _stopSession,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text("End Session"),
                        ),
                      ),
                  ],
                ),
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

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
