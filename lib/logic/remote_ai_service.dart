import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../domain/ai_response.dart';
import 'neuro_settings.dart';
import 'pii_masker.dart';
import 'prompt_builder.dart';
import 'advanced_logger.dart';

class RemoteAIService {
  static Future<AIResponse> processRequest({
    required String userQuery,
    Uint8List? imageBytes,
    required NeuroSettings userSettings,
    double energy = 0.5,
    bool isOverwhelmed = false,
  }) async {

    if (userSettings.userApiKey.isEmpty) {
      return _errorResponse("API key missing.");
    }

    try {
      final safeQuery = PIIMasker.mask(userQuery);
      final bool hasImage = imageBytes != null;

      final systemPrompt = PromptBuilder.buildSystemPrompt(
        userName: userSettings.userName,
        disabilityType: userSettings.disabilityType,
        sensoryTriggers: userSettings.sensoryTriggers,
        executiveStruggle: userSettings.executiveStruggle,
        interest: userSettings.interest,
        energyLevel: energy,
        isOverwhelmed: isOverwhelmed,
        hasImage: hasImage,
        language: userSettings.preferredLanguage,
      );

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: userSettings.userApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
          maxOutputTokens: 4096,
        ),
        systemInstruction: Content.system(systemPrompt),
      );

      Uint8List? processedImage;
      if (imageBytes != null) {
        processedImage = await compute(_resizeImageIsolate, imageBytes);
      }

      final content = [
        Content.multi([
          TextPart(
            safeQuery.isEmpty
                ? "Analyze this scene."
                : safeQuery,
          ),
          if (processedImage != null)
            DataPart('image/jpeg', processedImage),
        ])
      ];

      AdvancedLogger().logApi(
        method: "POST", 
        url: "gemini-2.5-flash:generateContent", // Just a label
        body: {
            "query": safeQuery,
            "hasImage": hasImage,
            "systemPrompt": systemPrompt, // Useful to see what context was sent
        }
      );

      final response = await model.generateContent(content);
      AdvancedLogger().logApi(
        method: "RESPONSE", 
        url: "200 OK",
        response: response.text ?? "NULL RESPONSE"
      );

      print("🔍 RAW AI RESPONSE: ${response.text}");

      if (response.text == null || response.text!.isEmpty) {
        return _errorResponse("No response received.");
      }

      String cleanText = response.text!;

      // 1. Remove Markdown code blocks if present
      cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '');

      // 2. Find the start and end of the JSON object
      final startIndex = cleanText.indexOf('{');
      final endIndex = cleanText.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        // Extract ONLY the part between { and }
        cleanText = cleanText.substring(startIndex, endIndex + 1);
      } else {
        // If no curly braces found, it's a real failure
        print("❌ JSON PARSING FAILED: No braces found in: $cleanText");
        throw const FormatException("Invalid JSON format");
      }

      final decoded = json.decode(cleanText);
      // 3. LOG PARSED JSON (Optional, but good for verification)
      AdvancedLogger().log(
        LogType.info, 
        "Parsed JSON", 
        "Successfully decoded AI response",
        jsonContent: decoded
      );
      return AIResponse.fromJson(decoded);

    } catch (e) {
      AdvancedLogger().log(LogType.error, "AI Error", e.toString());
      return _errorResponse("Scene unclear. Please describe your goal.");
    }
  }

  static AIResponse _errorResponse(String message) {
    return AIResponse(
      mode: "clarification",
      missionName: "Clarification Needed",
      coachingMessage: "",
      actions: [],
      question: message,
      options: [
        "Describe what you want to do",
        "Explain the goal in one sentence",
        "Start with something small",
        "Ignore image and type goal"
      ],
    );
  }

  static Uint8List _resizeImageIsolate(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;
    final resized = img.copyResize(decoded, width: 800);
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: 85),
    );
  }
}
