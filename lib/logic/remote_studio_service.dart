import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RemoteStudioService {
  static Future<Map<String, String>> generateStudioContent({
    required String prompt,
    Uint8List? fileBytes,
    String mimeType = "image/jpeg",
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    final List<Map<String, dynamic>> parts = [{"text": prompt}];

    if (fileBytes != null) {
      parts.add({
        "inline_data": {
          "mime_type": mimeType,
          "data": base64Encode(fileBytes),
        }
      });
    }

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [{"parts": parts}],
        "generationConfig": {"response_mime_type": "application/json"}
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String rawJson = data['candidates'][0]['content']['parts'][0]['text'];
      final Map<String, dynamic> cleanData = jsonDecode(rawJson);
      return {
        "script": cleanData['spoken_script'] ?? "",
        "summary": cleanData['visual_summary'] ?? ""
      };
    } else {
      throw Exception("Studio API Failed");
    }
  }
}