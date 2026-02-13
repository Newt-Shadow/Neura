import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late Box _encryptedBox;
  bool _isInitialized = false;

  
  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    
    String? keyString = await _secureStorage.read(key: 'neuro_db_key');
    List<int> encryptionKey;

    if (keyString == null) {
      
      encryptionKey = Hive.generateSecureKey();
      await _secureStorage.write(
        key: 'neuro_db_key',
        value: base64UrlEncode(encryptionKey),
      );
    } else {
      encryptionKey = base64Url.decode(keyString);
    }

    // 2. Open the Box with AES-256 Encryption
    _encryptedBox = await Hive.openBox(
      'neuro_secure_data',
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _isInitialized = true;
  }

 
  Future<void> saveData(String key, dynamic value) async {
    if (!_isInitialized) await init();
    await _encryptedBox.put(key, value);
  }


  dynamic getData(String key) {
    if (!_isInitialized) return null;
    return _encryptedBox.get(key);
  }
}