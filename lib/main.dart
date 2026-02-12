import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'logic/neuro_settings.dart';
import 'ui/smart_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load ENV FIRST
  await dotenv.load(fileName: ".env");

  print("Loaded ENV KEY: ${dotenv.env['GEMINI_API_KEY']}");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase Error: $e");
  }

  final neuroSettings = NeuroSettings();
  await neuroSettings.loadSettings();

  runApp(
    ChangeNotifierProvider(
      create: (_) => neuroSettings,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Neura",
      theme: ThemeData(
        fontFamily: settings.fontFamily,
        brightness:
            settings.highContrast ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const SmartDashboardScreen(),
    );
  }
}
