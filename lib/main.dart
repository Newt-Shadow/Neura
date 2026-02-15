import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:universal_io/io.dart'; // For Platform check

import 'firebase_options.dart';
import 'logic/neuro_settings.dart';
import 'ui/smart_dashboard_screen.dart';
import 'ui/model_setup_screen.dart'; // Correct path for Setup Screen
import 'logic/model_holder.dart';
import 'data/secure_storage_service.dart'; // Ensure this exists
import 'data/downloader_datasource.dart';
import 'domain/download_model.dart';

// Global config for the model
final kGemmaModelConfig = DownloadModel(
  modelUrl:
      "https://huggingface.co/google/gemma-2b-it-gpu-int4/resolve/main/model.bin",
  modelFilename: "gemma-3n-E2B-it-int4.task",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Essential Services
  await dotenv.load(fileName: ".env");
  // print("Loaded ENV KEY: ${dotenv.env['GEMINI_API_KEY']}");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase Error: $e");
  }

  // Initialize Secure Storage
  // Make sure lib/data/secure_storage_service.dart exists as provided previously
  await SecureStorageService().init();

  // Load Settings
  final neuroSettings = NeuroSettings();
  await neuroSettings.loadSettings();

  // 2. Check & Load AI Model
  Widget initialScreen;

  if (kIsWeb || Platform.isWindows) {
    print("🌍 Web/Windows detected. Skipping Local Model Setup.");
    initialScreen = const SmartDashboardScreen();
  } else {
    // 🔥 Only check model if Local LLM is enabled
    if (neuroSettings.useLocalModel) {
      final downloader = GemmaDownloaderDataSource(model: kGemmaModelConfig);
      final bool isModelPresent = await downloader.checkModelExistence();

      if (isModelPresent) {
        print("✅ Model found. Loading into memory...");
        try {
          final path = await downloader.getFilePath();
          await ModelHolder.loadModel(path);
        } catch (e) {
          print("❌ Failed to load model: $e");
        }
      }
    }

    // ALWAYS start at Dashboard
    initialScreen = const SmartDashboardScreen();
  }

  // final downloader = GemmaDownloaderDataSource(model: kGemmaModelConfig);
  // final bool isModelPresent = await downloader.checkModelExistence();

  // 3. Run App
  runApp(
    ChangeNotifierProvider(
      create: (_) => neuroSettings,
      child: MyApp(initialScreen: initialScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Neuro",
      theme: ThemeData(
        fontFamily: settings.fontFamily,
        brightness: settings.highContrast ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: initialScreen,
    );
  }
}
