import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  encrypt.Key? _key;
  
  // Initialize and retrieve/generate the unique device key
  Future<void> init() async {
    if (_key != null) return;

    String? storedKey = await _storage.read(key: 'secure_history_key');
    
    if (storedKey == null) {
      // Generate a new random 32-byte key (AES-256)
      final key = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: 'secure_history_key', value: base64UrlEncode(key.bytes));
      _key = key;
    } else {
      _key = encrypt.Key(base64Url.decode(storedKey));
    }
  }

  // Encrypt Text: Returns "IV:Base64Cipher"
  String encryptText(String plainText) {
    if (_key == null) throw Exception("EncryptionService not initialized");
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return "${base64UrlEncode(iv.bytes)}:${encrypted.base64}";
  }

  // Decrypt Text
  String decryptText(String encryptedFull) {
    if (_key == null) throw Exception("EncryptionService not initialized");
    try {
      final parts = encryptedFull.split(':');
      if (parts.length != 2) return "Error: Invalid format";

      final iv = encrypt.IV(base64Url.decode(parts[0]));
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return "Decryption Failed";
    }
  }

  // Encrypt Binary Data (Images)
  Uint8List encryptData(Uint8List data) {
    if (_key == null) throw Exception("EncryptionService not initialized");
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
    
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    // Prepend IV to the data bytes
    final combined = BytesBuilder();
    combined.add(iv.bytes);
    combined.add(encrypted.bytes);
    return combined.toBytes();
  }

  // Decrypt Binary Data (Images)
  Uint8List decryptData(Uint8List data) {
    if (_key == null) throw Exception("EncryptionService not initialized");
    
    // Extract IV (first 16 bytes)
    final ivBytes = data.sublist(0, 16);
    final contentBytes = data.sublist(16);
    
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
    
    final encrypted = encrypt.Encrypted(contentBytes);
    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }
}