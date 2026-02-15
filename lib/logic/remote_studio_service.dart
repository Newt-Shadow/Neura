import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class RemoteStudioService {
  static Future<String> generateStudioContent({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    // 1. Validate API Key
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("❌ STUDIO ERROR: GEMINI_API_KEY is missing from .env");
      throw Exception("API Key Missing");
    }

    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    // 2. Build Request Body
    final List<Map<String, dynamic>> parts = [{"text": prompt}];

    if (imageBytes != null) {
      parts.add({
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": base64Encode(imageBytes),
        }
      });
    }

    final body = jsonEncode({
      "contents": [{"parts": parts}],
      "generationConfig": {
        "temperature": 0.7,
        "topP": 0.8,
        "topK": 40,
        "maxOutputTokens": 1000,
      }
    });

    try {
      debugPrint("☁️ Sending Studio Request...");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Deep extract the text safely
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null) {
            return content['parts'][0]['text'] ?? "No text generated.";
          }
        }
        return "Script generation failed: Empty response.";
      } else {
        debugPrint("❌ STUDIO API ERROR: ${response.statusCode} - ${response.body}");
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ STUDIO NETWORK ERROR: $e");
      rethrow;
    }
  }
}