import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../logic/remote_ai_service.dart'; // <--- ADDED THIS
import '../domain/ai_response.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;

import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import 'interactive_task_screen.dart';
import 'ar_task_screen.dart';

class TaskBreakdownScreen extends StatefulWidget {
  const TaskBreakdownScreen({super.key});
  @override
  State<TaskBreakdownScreen> createState() => _TaskBreakdownScreenState();
}

class _TaskBreakdownScreenState extends State<TaskBreakdownScreen> {
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Uint8List? _pendingImageBytes;

  bool _isListening = false;
  bool _isLoading = false;
  String _statusMessage = "";

  Uint8List? _attachedImageBytes;
  bool _isVideo = false;
  String? _attachmentName;

  // --- DUAL MODE STATE ---
  bool _isTaskMode = true; // true = Task Agent, false = Normal Chat
  List<Map<String, String>> _chatMessages = [];

  // Session State
  dynamic _activeChat;
  List<String>? _clarificationOptions;
  String? _clarificationQuestion;

  String _maskPII(String input) {
    return input.replaceAll(
      RegExp(r"[\w-\.]+@([\w-]+\.)+[\w-]{2,4}"),
      "[EMAIL]",
    );
  }

  // --- IMAGE OPTIMIZATION ---
  Future<Uint8List> _compressImage(Uint8List rawBytes) async {
    try {
      final cmd = img.decodeImage(rawBytes);
      if (cmd == null) return rawBytes;
      if (cmd.width > 800 || cmd.height > 800) {
        final resized = img.copyResize(
          cmd,
          width: cmd.width > cmd.height ? 800 : null,
          height: cmd.height > cmd.width ? 800 : null,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      }
      return rawBytes;
    } catch (e) {
      return rawBytes;
    }
  }

  // --- INPUT HANDLERS ---
  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? media = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (media != null) {
                  if (!_isTaskMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Switched to Task Mode for Image Analysis",
                        ),
                      ),
                    );
                    setState(() {
                      _isTaskMode = true;
                      _resetSession();
                    });
                  }
                  _resetSession();
                  setState(() {
                    _isLoading = true;
                    _statusMessage = "Optimizing...";
                  });
                  final bytes = await media.readAsBytes();
                  final compressed = await _compressImage(bytes);
                  setState(() {
                    _attachedImageBytes = compressed;
                    _attachmentName = "Image attached";
                    _isVideo = false;
                    _clarificationOptions = null;
                    _isLoading = false;
                  });
                  _processRequest(imageBytes: compressed);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? media = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (media != null) {
                  if (!_isTaskMode) {
                    setState(() {
                      _isTaskMode = true;
                      _resetSession();
                    });
                  }
                  _resetSession();
                  setState(() {
                    _isLoading = true;
                    _statusMessage = "Optimizing...";
                  });
                  final bytes = await media.readAsBytes();
                  final compressed = await _compressImage(bytes);
                  setState(() {
                    _attachedImageBytes = compressed;
                    _attachmentName = "Photo taken";
                    _isVideo = false;
                    _clarificationOptions = null;
                    _isLoading = false;
                  });
                  _processRequest(imageBytes: compressed);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _resetSession() {
    _activeChat = null;
    _clarificationOptions = null;
    // We do NOT clear _chatMessages here to keep history visible for Chat Mode
    // But we clear them if switching TO Task Mode to avoid confusion
    if (_isTaskMode) _chatMessages.clear();
  }

  Future<void> _toggleVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() => _textController.text = val.recognizedWords);
            if (val.finalResult) {
              setState(() => _isListening = false);
              _sendMessage();
            }
          },
        );
      } else {
        openAppSettings();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImageBytes == null) return;

    _speech.stop();
    _textController.clear();

    if (_isTaskMode) {
      if (_clarificationOptions != null) {
        _processRequest(
          textInput: text,
          imageBytes: _pendingImageBytes, // <--- FIX: Resend the image
          forcePlan: true,
        );

        // Cleanup after plan is requested
        _pendingImageBytes = null;
        setState(() {
          _clarificationOptions = null;
        });
      } else {
        if (_attachedImageBytes != null) {
          _pendingImageBytes = _attachedImageBytes;
        }
        _processRequest(textInput: text, imageBytes: _attachedImageBytes);
      }

      // Clear the input preview, but _pendingImageBytes keeps the data alive logic-side
      setState(() {
        _attachedImageBytes = null;
        _attachmentName = null;
        _isListening = false;
      });
    } else {
      _processNormalChat(text);
    }
  }

  // --- MODE 1: CHAT LOGIC ---
  Future<void> _processNormalChat(String text) async {
    setState(() {
      _chatMessages.add({'role': 'user', 'text': text});
      _isLoading = true;
      _statusMessage = "Typing...";
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients)
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
    });

    try {
      if (_activeChat == null) {
        _activeChat = await ModelHolder.createChat();
        final settings = context.read<NeuroSettings>();
        // Initialize conversational persona
        await _activeChat.addQueryChunk(
          Message.text(
            text:
                "System: You are a friendly companion for ${settings.userName}. Keep answers short, encouraging, and helpful. Do NOT output JSON.",
            isUser: true,
          ),
        );
      }

      await _activeChat.addQueryChunk(Message.text(text: text, isUser: true));

      String botResponse = "";
      await for (final token in _activeChat.generateChatResponseAsync()) {
        botResponse += token;
      }

      setState(() {
        _chatMessages.add({'role': 'ai', 'text': botResponse});
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: 300.ms,
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'role': 'ai',
          'text': "Sorry, I got confused. ($e)",
        });
        _isLoading = false;
      });
    }
  }

  // --- MODE 2: TASK AGENT LOGIC ---
  // --- MODE 2: TASK AGENT LOGIC (UPDATED) ---
  Future<void> _processRequest({
    String? textInput,
    Uint8List? imageBytes,
    bool forcePlan = false,
  }) async {
    setState(() {
      _isLoading = true;
      _statusMessage = forcePlan ? "Drafting Plan..." : "Analyzing Scene...";
    });

    try {
      final settings = context.read<NeuroSettings>();
      // Save User Query to History
      if (textInput != null) settings.addToHistory('user', textInput);
      final response = await RemoteAIService.processRequest(
        userQuery: textInput ?? (forcePlan ? "Create the plan." : ""),
        imageBytes: imageBytes,
        userSettings: settings,
      );

      if (response == null) throw Exception("Brain fog. Try again.");
      settings.addToHistory('ai', response.message);

      if (response.type == AIResponseType.question) {
        // CASE A: DYNAMIC OPTIONS RETURNED BY AI
        setState(() {
          _clarificationQuestion = response.message;
          // Use the options from the AI, or fallback if empty
          _clarificationOptions =
              (response.options != null && response.options!.isNotEmpty)
              ? response.options
              : ["Clean", "Organize", "Declutter"];
        });
      } else {
        // CASE B: PLAN READY
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArTaskScreen(
              tasks: response.actions ?? [],
              initialArBox: response.box2d,
              settings: settings,
              onClose: () {
                Navigator.pop(context);
                _pendingImageBytes = null; // Clear memory
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... imports remain the same ...

  // Replace ONLY the _handleResponse function in your existing TaskBreakdownScreen file
  void _handleResponse(String response) {
    try {
      final data = json.decode(response);

      if (data['type'] == 'options') {
        setState(() {
          _clarificationQuestion = data['question'];
          _clarificationOptions = List<String>.from(data['options']);
        });
      } else {
        // --- INTEGRATION FIX ---
        // We decode the JSON here and pass the List directly.
        final List<dynamic> tasks = data['actions'] ?? [];
        final String motivation = data['motivation'] ?? "You can do this!";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InteractiveTaskScreen(
              initialTasks: tasks, // Pass List
              motivation: motivation, // Pass String
              onReset: () {
                Navigator.pop(context);
                // Keeps the chat history alive if they come back
              },
            ),
          ),
        );
      }
    } catch (e) {
      print("JSON Logic Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not read plan. Try again.")),
      );
    }
  }

  // ... rest of the file remains the same ...

  String? _robustJsonExtractor(String input) {
    int start = input.indexOf('{');
    int end = input.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      String candidate = input.substring(start, end + 1);
      try {
        json.decode(candidate);
        return candidate;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton("Task Agent", true),
              _buildModeButton("Chat", false),
            ],
          ),
        ),
        centerTitle: true,
      ),
      // Fixes the keyboard overlap issue
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(child: _isTaskMode ? _buildTaskView() : _buildChatView()),
          if (_attachmentName != null && _isTaskMode) _buildAttachmentBanner(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool isTask) {
    final isSelected = _isTaskMode == isTask;
    return GestureDetector(
      onTap: () {
        if (_isTaskMode != isTask) {
          setState(() {
            _isTaskMode = isTask;
            _resetSession();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskView() {
    if (_isLoading) return Center(child: Text(_statusMessage));
    if (_clarificationOptions != null) return _buildOptionsView();
    return const Center(child: Text("Ready to analyze tasks."));
  }

  Widget _buildChatView() {
    final settings = context.watch<NeuroSettings>();
    final allMessages = [
      ...settings.history.map((h) => {'role': h['role']!, 'text': h['text']!}),
      ..._chatMessages,
    ];
    // if (_chatMessages.isEmpty && !_isLoading) {
    //   return _buildEmptyState("Let's chat! Say Hi.");
    // }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatMessages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        final msg = allMessages[i];
        return ListTile(
          title: Text(
            msg['text']!,
            textAlign: msg['role'] == 'user' ? TextAlign.right : TextAlign.left,
          ),
          subtitle: i < settings.history.length
              ? const Text("History", style: TextStyle(fontSize: 10))
              : null,
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isTaskMode ? Icons.psychology : Icons.chat,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOptionsView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.help_outline, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _clarificationQuestion ?? "Choose an option:",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ..._clarificationOptions!
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      height: 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: Colors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            _processRequest(textInput: option, forcePlan: true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentBanner() {
    return Container(
      color: Colors.teal.shade50,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.teal),
          const SizedBox(width: 8),
          Text(_attachmentName!),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _attachedImageBytes = null;
              _attachmentName = null;
            }),
          ),
        ],
      ),
    );
  }

  // FIXED INPUT BAR (SafeArea Logic)
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false, // Don't pad top
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              if (_isTaskMode)
                IconButton(
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: _pickAttachment,
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: "Message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                elevation: 0,
                backgroundColor:
                    (_textController.text.isNotEmpty || _attachmentName != null)
                    ? Colors.teal
                    : (_isListening ? Colors.redAccent : Colors.teal),
                onPressed:
                    (_textController.text.isNotEmpty || _attachmentName != null)
                    ? _sendMessage
                    : _toggleVoice,
                child: Icon(
                  (_textController.text.isNotEmpty || _attachmentName != null)
                      ? Icons.arrow_upward
                      : (_isListening ? Icons.stop : Icons.mic),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
