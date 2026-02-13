import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../logic/encryption_service.dart';

class HistoryItem {
  final String id;
  final String prompt;
  final String aiResponseSummary;
  final DateTime timestamp;
  final Uint8List? decryptedImage; // Null if no image

  HistoryItem({
    required this.id,
    required this.prompt,
    required this.aiResponseSummary,
    required this.timestamp,
    this.decryptedImage,
  });
}

class HistoryRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _crypto = EncryptionService();

  Future<void> saveInteraction({
    required String userId,
    required String userPrompt,
    required String aiResponse,
    Uint8List? imageBytes,
  }) async {
    await _crypto.init();
    final String uuid = const Uuid().v4();

    String? storagePath;

    // 1. Encrypt and Upload Image (if exists)
    if (imageBytes != null) {
      final encryptedImage = _crypto.encryptData(imageBytes);
      final ref = _storage.ref().child('secure_history/$userId/$uuid.bin'); // .bin to mask type
      await ref.putData(encryptedImage);
      storagePath = ref.fullPath;
    }

    // 2. Encrypt Text Data
    final encryptedPrompt = _crypto.encryptText(userPrompt);
    final encryptedResponse = _crypto.encryptText(aiResponse);

    // 3. Save Metadata to Firestore
    await _firestore.collection('users').doc(userId).collection('history').doc(uuid).set({
      'timestamp': FieldValue.serverTimestamp(),
      'e_prompt': encryptedPrompt,
      'e_response': encryptedResponse,
      'e_image_path': storagePath, // Path is not sensitive, but file content is
    });
  }

  // Fetch and Decrypt Logic
  Future<List<HistoryItem>> fetchHistory(String userId) async {
    await _crypto.init();

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(20) // Load last 20 for performance
        .get();

    List<HistoryItem> items = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      // Decrypt Texts
      final prompt = _crypto.decryptText(data['e_prompt'] ?? "");
      final response = _crypto.decryptText(data['e_response'] ?? "");
      
      // Decrypt Image (Lazy load logic usually better, but here we do simple await)
      Uint8List? imageBytes;
      if (data['e_image_path'] != null) {
        try {
          final ref = _storage.ref(data['e_image_path']);
          // Max size 5MB
          final encryptedBytes = await ref.getData(5 * 1024 * 1024); 
          if (encryptedBytes != null) {
            imageBytes = _crypto.decryptData(encryptedBytes);
          }
        } catch (e) {
          print("Error decrypting image: $e");
        }
      }

      items.add(HistoryItem(
        id: doc.id,
        prompt: prompt,
        aiResponseSummary: response,
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        decryptedImage: imageBytes,
      ));
    }

    return items;
  }
}