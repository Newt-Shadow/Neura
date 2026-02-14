import 'package:neuro/logic/model_holder.dart';
import 'package:flutter_gemma/flutter_gemma.dart'; // Ensure this is imported for Message class
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart'; 

class LocalLLMService {
  
  /// Generate text using the loaded ModelHolder
  static Future<String?> generateResponse(String prompt) async {
    if (kIsWeb || Platform.isWindows) {
    print("🚫 Local LLM disabled for Web/Windows. Switching to Cloud API.");
    return null; 
  }
    
    if (!ModelHolder.isModelLoaded) {
      print("⚠️ Gemma model not loaded in ModelHolder.");
      return null;
    }

    try {
     
      if (ModelHolder.chat == null) {
        ModelHolder.chat = await ModelHolder.createChat();
      }
      
      // 1. Add the user's prompt to the chat history
      await ModelHolder.chat!.addQueryChunk(
        Message.text(text: prompt, isUser: true),
      );

      // 2. Generate the response
      // generateChatResponse returns a Future<String?> (or similar)
      final response = await ModelHolder.chat!.generateChatResponse();
      return response;
      
    } catch (e) {
      print("❌ Gemma Generation Error: $e");
      return null;
    }
  }
}