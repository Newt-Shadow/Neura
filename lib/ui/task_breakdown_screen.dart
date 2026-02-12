import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../logic/remote_ai_service.dart';
import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../logic/pii_masker.dart';
import '../domain/ai_response.dart';
import 'interactive_task_screen.dart';

class TaskBreakdownScreen extends StatefulWidget {
  const TaskBreakdownScreen({super.key});

  @override
  State<TaskBreakdownScreen> createState() =>
      _TaskBreakdownScreenState();
}

class _TaskBreakdownScreenState
    extends State<TaskBreakdownScreen> {

  bool _forceTextMode = false;

  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController =
      TextEditingController();

  Uint8List? _pendingImageBytes;
  bool _isLoading = false;
  String _statusMessage = "";

  double _currentEnergy = 0.5;
  bool _isOverwhelmed = false;

  // ==========================================================
  // IMAGE PICK
  // ==========================================================

  Future<void> _pickAttachment() async {
    final XFile? media =
        await _picker.pickImage(source: ImageSource.camera);

    if (media == null) return;

    final bytes = await media.readAsBytes();
    final compressed = await _compressImage(bytes);

    setState(() {
      _pendingImageBytes = compressed;
      _forceTextMode = false; // image mode active
    });

    _processTaskRequest(imageBytes: compressed);
  }

  Future<Uint8List> _compressImage(
      Uint8List rawBytes) async {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final resized =
        img.copyResize(decoded, width: 800);
    return Uint8List.fromList(
        img.encodeJpg(resized, quality: 75));
  }

  // ==========================================================
  // SEND MESSAGE (CLEAN VERSION)
  // ==========================================================

  void _sendMessage() {
    final text = _textController.text.trim();

    if (text.isEmpty && _pendingImageBytes == null)
      return;

    if (text.toLowerCase().contains("overwhelmed") ||
        text.toLowerCase().contains("stuck")) {
      _isOverwhelmed = true;
    }

    // 🔥 Manual mode → ignore image
    if (_forceTextMode) {
      _processTaskRequest(
        textInput: text,
        imageBytes: null,
      );
      _textController.clear();
      return;
    }

    _processTaskRequest(
      textInput: text,
      imageBytes: _pendingImageBytes,
    );

    _textController.clear();
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
      final settings =
          context.read<NeuroSettings>();

      String safeQuery =
          PIIMasker.mask(textInput ?? "");

      if (imageBytes != null &&
          safeQuery.isEmpty) {
        safeQuery =
            "Analyze this scene and determine possible goals.";
      }

      final response =
          await RemoteAIService.processRequest(
        userQuery: safeQuery,
        imageBytes: imageBytes,
        userSettings: settings,
        energy: _currentEnergy,
        isOverwhelmed: _isOverwhelmed,
      );

      if (!mounted) return;

      // 🔥 Clarification mode
      if (response.mode ==
          "clarification") {
        _showClarificationDialog(
            response, safeQuery);
        return;
      }

      // 🔥 Task mode
      if (response.actions.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InteractiveTaskScreen(
              response: response,
              dyslexiaMode:
                  settings.dyslexiaMode,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorMessage(
          "Something went wrong.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================================
  // 🔥 DYNAMIC CLARIFICATION UI
  // ==========================================================

  void _showClarificationDialog(
      AIResponse response,
      String contextText) {

    final dynamicOptions =
        _generateDynamicOptions(
            response.options,
            contextText);

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              response.question ??
                  "What would you like to do?",
              style:
                  const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ...dynamicOptions
                .map((option) =>
                    ListTile(
                      title:
                          Text(option),
                      onTap: () {
                        Navigator.pop(
                            context);

                        if (option ==
                            "I will type my goal") {
                          setState(() {
                            _forceTextMode =
                                true;
                            _pendingImageBytes =
                                null;
                          });
                          return;
                        }

                        _processTaskRequest(
                            textInput:
                                option,
                            imageBytes:
                                null);
                      },
                    ))
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
      String contextText) {

    final options =
        <String>[];

    if (aiOptions != null &&
        aiOptions.isNotEmpty) {
      options.addAll(aiOptions);
    }

    final lower =
        contextText.toLowerCase();

    if (lower.contains("desk") ||
        lower.contains("study")) {
      options.addAll([
        "Start studying",
        "Organize books",
      ]);
    }

    if (lower.contains("kitchen")) {
      options.addAll([
        "Cook something simple",
        "Clean the counter",
      ]);
    }

    if (lower.contains("bed") ||
        lower.contains("room")) {
      options.addAll([
        "Make the bed",
        "Pick up clothes",
      ]);
    }

    if (!options.contains(
        "I will type my goal")) {
      options.add(
          "I will type my goal");
    }

    return options
        .toSet()
        .toList();
  }

  void _showErrorMessage(
      String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            "Micro-Win Planner"),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: Text(
                        _statusMessage))
                : const Center(
                    child: Text(
                      "Ready to break it into Micro-Wins.",
                      style: TextStyle(
                          fontSize: 18,
                          color:
                              Colors.grey),
                    ),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
              color:
                  Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                  Icons.add_a_photo),
              onPressed:
                  _pickAttachment,
            ),
            Expanded(
              child: TextField(
                controller:
                    _textController,
                decoration:
                    const InputDecoration(
                  hintText:
                      "What's the goal?",
                  border:
                      InputBorder.none,
                ),
              ),
            ),
            FloatingActionButton(
              mini: true,
              onPressed:
                  _sendMessage,
              backgroundColor:
                  Colors.teal,
              child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
