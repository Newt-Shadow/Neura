import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

// Project imports
import '../domain/ai_response.dart';
import 'neuro_settings.dart';

class RemoteAIService {
  // TODO: Replace with your working API Key
  static const String _apiKey = "AIzaSyCwkfy6HnkL95kViLCv4HHXZSngDNKLRzk"; 

  /// Main method to handle the AI request with dynamic context and learning
  static Future<AIResponse?> processRequest({
    required String userQuery,
    Uint8List? imageBytes,
    required NeuroSettings userSettings, 
  }) async {
    try {
      // 1. GENERATE CONTEXT
      String profileContext = userSettings.generateProfileString();
      
      // Load the System Prompt
      String basePrompt = await _loadAssetString('assets/generic_prompt_en.json');
      
      // --- FIX IS HERE ---
      // We use r'...' to tell Dart "This is just text, do not look for a variable".
      String finalSystemInstruction = basePrompt.replaceFirst(
        r'${user_profile_json}', 
        profileContext.isEmpty ? "User is new. Assume general neurodivergent needs." : profileContext
      );

      // 2. INITIALIZE GEMINI
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7, 
        ),
        systemInstruction: Content.system(finalSystemInstruction),
      );

      // 3. OPTIMIZE IMAGE
      Uint8List? processedImage;
      if (imageBytes != null) {
         processedImage = _resizeImage(imageBytes);
      }

      // 4. PREPARE CONTENT
      final content = [
        Content.multi([
          TextPart(userQuery.isEmpty ? "Analyze this image and decide next steps." : userQuery),
          if (processedImage != null) DataPart('image/jpeg', processedImage),
        ])
      ];

      // 5. CALL AI
      final response = await model.generateContent(content);
      
      if (response.text == null) return null;

      // 6. PARSE RESPONSE
      String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMap = json.decode(cleanJson);
      final aiResponse = AIResponse.fromJson(jsonMap);

      // 7. LEARNING LOOP
      if (aiResponse.profileUpdates != null && aiResponse.profileUpdates!.isNotEmpty) {
        await userSettings.updateProfile(aiResponse.profileUpdates!);
      }

      return aiResponse;

    } catch (e) {
      print("Remote AI Error: $e");
      return null;
    }
  }

  /// Helper: Loads the system prompt from assets
  static Future<String> _loadAssetString(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      print("Error loading asset $path: $e");
      // Fallback prompt - Fixed interpolation here too
      return r"""
      ROLE: Executive Function Coach.
      GOAL: Break tasks into micro-steps.
      OUTPUT: JSON with 'type' (question/plan) and 'actions'.
      CONTEXT: ${user_profile_json}
      """; 
    }
  }
  
  /// Helper: Resizes large images to reduce API latency
  static Uint8List _resizeImage(Uint8List original) {
    try {
      final decodedImage = img.decodeImage(original);
      if (decodedImage == null) return original;

      if (decodedImage.width > 800) {
        final resized = img.copyResize(decodedImage, width: 800);
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }
      
      return original;
    } catch (e) {
      print("Image resize error: $e");
      return original;
    }
  }
}