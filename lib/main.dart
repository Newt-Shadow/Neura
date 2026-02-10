import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'localization/app_strings.dart';

import 'logic/neuro_settings.dart';
import 'ui/smart_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appStrings = AppStrings();
  try { await appStrings.loadFromAsset('assets/strings_en.json'); } catch (_) {}

  final neuroSettings = NeuroSettings();
  await neuroSettings.loadSettings();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appStrings),
        ChangeNotifierProvider.value(value: neuroSettings),
      ],
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
      title: 'Smart Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: settings.fontFamily,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: settings.highContrast ? Brightness.dark : Brightness.light,
          background: settings.highContrast ? Colors.black : Colors.grey[50],
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SmartDashboardScreen(),
    );
  }
}