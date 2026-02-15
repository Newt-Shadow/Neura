import 'dart:convert';
import 'package:flutter/services.dart';
import 'lingua_supportata.dart';

// Class-based approach to match your usage pattern
class LoadLingue {
  static Future<List<LinguaSupportata>> leggiLingueSupportate() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/lingue_supportate.json');
      final dynamic data = json.decode(jsonString);
      
      List<dynamic> list;
      // Handle both formats (List wrapper or direct List)
      if (data is Map && data.containsKey('lingue_supportate')) {
        list = data['lingue_supportate'];
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }

      return list.map((e) => LinguaSupportata.fromJson(e)).toList();
    } catch (e) {
      print("Error loading languages: $e");
      return [];
    }
  }
}