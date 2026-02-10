import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../domain/ai_response.dart';
import 'neuro_settings.dart';

class RemoteAIService {
  
  static Future<AIResponse?> processRequest({
    required String userQuery,
    Uint8List? imageBytes,
    required NeuroSettings userSettings, 
  }) async {
    
    // 1. CHECK API KEY
    String apiKey = userSettings.userApiKey;
    if (apiKey.isEmpty) {
      return AIResponse(type: AIResponseType.plan, message: "Please connect your API Key in Settings.");
    }

    try {
      // 2. GENERATE CONTEXT
      String profileContext = userSettings.generateProfileString();
      String basePrompt = await _loadAssetString('assets/generic_prompt_en.json');
      
      String finalSystemInstruction = basePrompt.replaceFirst(
        r'${user_profile_json}', 
        profileContext.isEmpty ? "User is new." : profileContext
      );

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
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
          TextPart(userQuery.isEmpty ? "Analyze this image." : userQuery),
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
      if (aiResponse.profileUpdates != null) {
        userSettings.updateProfile(aiResponse.profileUpdates!);
      }

      return aiResponse;

    } catch (e) {
      print("Remote AI Error: $e");
      return null;
    }
  }

  static Future<String> _loadAssetString(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      // Fallback
      return r'{"system_prompt": "ROLE: Executive Function Coach. GOAL: Break tasks into micro-steps.  PROFILE: ${user_profile_json}"}';
    }
  }
  
  static Uint8List _resizeImage(Uint8List original) {
    try {
      final decoded = img.decodeImage(original);
      if (decoded == null) return original;
      if (decoded.width > 800) {
        final resized = img.copyResize(decoded, width: 800);
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }
      return original;
    } catch (e) { return original; }
  }
}