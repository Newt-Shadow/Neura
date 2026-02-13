import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:convert'; 
import '../logic/remote_ai_service.dart';
import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../logic/pii_masker.dart';
import '../domain/ai_response.dart';
import 'interactive_task_screen.dart';
import '../logic/local_llm_service.dart';
import '../logic/offline_vision_service.dart';

class TaskBreakdownScreen extends StatefulWidget {
  const TaskBreakdownScreen({super.key});

  @override
  State<TaskBreakdownScreen> createState() => _TaskBreakdownScreenState();
}

class _TaskBreakdownScreenState extends State<TaskBreakdownScreen> {
  bool _forceTextMode = false;

  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

  Uint8List? _pendingImageBytes;
  Uint8List? _sessionImageBytes;
  bool _isLoading = false;
  String _statusMessage = "";

  double _currentEnergy = 0.5;
  bool _isOverwhelmed = false;

  // ==========================================================
  // IMAGE PICK
  // ==========================================================

  Future<void> _pickAttachment() async {
    if (_isLoading) return;
    final XFile? media = await _picker.pickImage(source: ImageSource.camera);

    if (media == null) return;

    final bytes = await media.readAsBytes();
    final compressed = await _compressImage(bytes);

    setState(() {
      _pendingImageBytes = compressed;
      _forceTextMode = false; // image mode active
    });

    // _processTaskRequest(imageBytes: compressed);
  }

  Future<Uint8List> _compressImage(Uint8List rawBytes) async {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final resized = img.copyResize(decoded, width: 800);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }

  // ==========================================================
  // SEND MESSAGE (CLEAN VERSION)
  // ==========================================================

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

    _processTaskRequest(
      textInput: text,
      imageBytes: _forceTextMode ? null : _pendingImageBytes,
    );

    // 🔥 Manual mode → ignore image
    _textController.clear();
    setState(() {
      _pendingImageBytes = null;
    });
  }

  // ==========================================================
  // TASK PROCESSING
  // ==========================================================

  Future<void> _processTaskRequest({
    String? textInput,
    Uint8List? imageBytes,
  }) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Analyzing...";
    });

    try {
      final settings = context.read<NeuroSettings>();
      String finalQuery = PIIMasker.mask(textInput ?? "");

      String safeQuery = PIIMasker.mask(textInput ?? "");

      if (imageBytes != null) {
        setState(() => _statusMessage = "Scanning objects (Offline)...");
        final detectedObjects = await OfflineVisionService.analyzeImage(
          imageBytes,
        );

        if (detectedObjects.isNotEmpty) {
          finalQuery += "\n\n[Context] I see: ${detectedObjects.join(', ')}";
          print("✅ Vision detected: $detectedObjects");
        }
      }

      AIResponse? aiResponse;

      // if (imageBytes == null) {
      //   try {
      //     setState(() => _statusMessage = "Thinking (On-Device)...");

      //     // Ask Gemma
      //     final localText = await LocalLLMService.generateResponse(
      //       "You are a helpful planner. Output valid JSON for this goal: $finalQuery",
      //     );

      //     if (localText != null && localText.contains("{")) {
      //       // Basic JSON extraction
      //       final startIndex = localText.indexOf('{');
      //       final endIndex = localText.lastIndexOf('}');
      //       final jsonStr = localText.substring(startIndex, endIndex + 1);

      //       aiResponse = AIResponse.fromJson(json.decode(jsonStr));
      //     }
      //   } catch (e) {
      //     print("⚠️ Local Gemma passed. Switching to Cloud.");
      //   }
      // }

      // ------------------------------------------------------------
      // 3. CLOUD FALLBACK
      // ------------------------------------------------------------
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

      // 4. Handle Result
      if (aiResponse!.mode == "clarification") {
        _showClarificationDialog(aiResponse, finalQuery);
      } else if (aiResponse.actions.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InteractiveTaskScreen(
              response: aiResponse!,
              dyslexiaMode: settings.dyslexiaMode,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorMessage("Connection failed. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================
  // DYNAMIC CLARIFICATION UI (FIXED)
  // ==========================================================

  void _showClarificationDialog(AIResponse response, String contextText) {
    final dynamicOptions = _generateDynamicOptions(
      response.options,
      contextText,
    );

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              response.question ?? "What would you like to do?",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...dynamicOptions
                .map(
                  (option) => ListTile(
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

                      String combinedContext =
                          "Context: The AI asked '${response.question}'. User replied: '$option'. Create a plan.";

                      // FIX: Pass _pendingImageBytes so the AI can "see" the scene again
                      _processTaskRequest(
                        textInput: option,
                        imageBytes: _sessionImageBytes,
                      );
                    },
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 🔥 SMART OPTION GENERATOR
  // ==========================================================

  List<String> _generateDynamicOptions(
    List<String>? aiOptions,
    String contextText,
  ) {
    final options = <String>[];

    if (aiOptions != null && aiOptions.isNotEmpty) {
      options.addAll(aiOptions);
    }

    final lower = contextText.toLowerCase();

    if (lower.contains("desk") || lower.contains("study")) {
      options.addAll(["Start studying", "Organize books"]);
    }

    if (lower.contains("kitchen")) {
      options.addAll(["Cook something simple", "Clean the counter"]);
    }

    if (lower.contains("bed") || lower.contains("room")) {
      options.addAll(["Make the bed", "Pick up clothes"]);
    }

    if (!options.contains("I will type my goal")) {
      options.add("I will type my goal");
    }

    return options.toSet().toList();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================================
  // UI
  // ==========================================================

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _pendingImageBytes!,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Image attached",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Ready to send",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _pendingImageBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neuro")),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: Text(_statusMessage))
                : const Center(
                    child: Text(
                      "I am Iron Man !",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
          ),
          if (_pendingImageBytes != null) _buildImagePreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: _pickAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: "What's the goal?",
                  border: InputBorder.none,
                ),
              ),
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
