import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

import 'package:universal_io/io.dart'; // Uses the new package
import 'package:flutter/foundation.dart'; // For kIsWeb

class OfflineVisionService {
  /// Analyzes an image byte array and returns a list of detected objects (e.g., "Bed", "Desk")
  static Future<List<String>> analyzeImage(Uint8List imageBytes) async {
    if (kIsWeb || Platform.isWindows) {
    print("⚠️ Offline Vision not supported on this platform. Skipping.");
    return [];
  }
    try {
      // 1. Convert bytes to a temporary file (ML Kit requires File or InputImage)
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/temp_vision_image.jpg').create();
      await file.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(file.path);

      // 2. Configure the Labeler (Confidence > 50%)
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
      final imageLabeler = ImageLabeler(options: options);

      // 3. Process
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
      
      // 4. Extract text labels
      List<String> detectedObjects = labels.map((l) => l.label).toList();

      // Cleanup
      imageLabeler.close();
      
      return detectedObjects;
    } catch (e) {
      print("Offline Vision Error: $e");
      return [];
    }
  }
} 