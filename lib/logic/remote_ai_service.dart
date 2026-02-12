import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../domain/ai_response.dart';
import 'neuro_settings.dart';
import 'pii_masker.dart';
import 'prompt_builder.dart';

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

      final systemPrompt = PromptBuilder.buildSystemPrompt(
        userName: userSettings.userName,
        disabilityType: userSettings.disabilityType,
        sensoryTriggers: userSettings.sensoryTriggers,
        executiveStruggle: userSettings.executiveStruggle,
        interest: userSettings.interest,
        energyLevel: energy,
        isOverwhelmed: isOverwhelmed,
      );

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: userSettings.userApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
          maxOutputTokens: 800,
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

      final response = await model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        return _errorResponse("No response received.");
      }

      final cleanText = response.text!
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = json.decode(cleanText);
      return AIResponse.fromJson(decoded);

    } catch (e) {
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
