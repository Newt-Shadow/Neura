import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/chat.dart';  // Import for InferenceChat
import 'package:flutter_gemma/core/model.dart'; // Import for InferenceModel and ModelType

class ModelHolder {
  static InferenceModel? _model;
  static InferenceChat? chat;
  static bool isModelLoaded = false;

  static Future<void> loadModel(String path) async {
    if (_model != null) return;
    
    final gemma = FlutterGemmaPlugin.instance;
    await gemma.modelManager.setModelPath(path);
    
    _model = await gemma.createModel(
      modelType: ModelType.gemmaIt, // ModelType is now imported
      supportImage: true, 
      maxTokens: 2048,
    );
    isModelLoaded = true;
  }

  static Future<InferenceChat> createChat() async {
    if (_model == null) throw Exception("AI Brain not loaded yet");
    return await _model!.createChat(supportImage: true);
  }
  
  // Add a getter for the existing chat or model if needed elsewhere
  static InferenceModel? get model => _model;
}