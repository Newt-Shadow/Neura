import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../data/downloader_datasource.dart';
import '../domain/download_model.dart';
import 'neuro_profile_screen.dart';
import 'task_breakdown_screen.dart';
import 'sign_in_screen.dart';
import 'model_setup_screen.dart';
import 'translator_screen.dart';

class SmartDashboardScreen extends StatefulWidget {
  const SmartDashboardScreen({super.key});

  @override
  State<SmartDashboardScreen> createState() => _SmartDashboardScreenState();
}

class _SmartDashboardScreenState extends State<SmartDashboardScreen> {
  String _loadingStatus = "";
  final String _modelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';
  final String _filename = 'gemma-3n-E2B-it-int4.task';
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadModel();
    });
  }

  Future<void> _autoLoadModel() async {
    if (ModelHolder.isModelLoaded) return;

    final downloader = GemmaDownloaderDataSource(
      model: DownloadModel(modelUrl: _modelUrl, modelFilename: _filename),
    );
    final exists = await downloader.checkModelExistence();

    if (exists) {
      setState(() => _loadingStatus = "Waking up AI Brain...");
      try {
        final path = await downloader.getFilePath();
        await ModelHolder.loadModel(path);
        if (mounted) setState(() => _loadingStatus = "");
      } catch (e) {
        if (mounted) setState(() => _loadingStatus = "Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();
    final isGuest = settings.currentUser == null;

    // We define the screens here to access 'settings' and 'context'
    final List<Widget> screens = [
      _buildDashboardBody(settings), // Index 0: Dashboard (Home)
      const TranslatorScreen(),      // Index 1: Translator
      const NeuroProfileScreen(),    // Index 2: Profile
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          " Neura ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Streak Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text(
                  "${settings.streakCount}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
          // Sign In / Profile Button
          if (isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                icon: const Icon(Icons.login, color: Colors.teal),
                label: const Text(
                  "Sign In",
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.face_6_outlined, size: 30),
              tooltip: "My Profile",
              onPressed: () => setState(() => _selectedIndex = 2), // Go to Profile
            ),
        ],
      ),
      
      // FIX: Single Body that switches based on index
      body: screens[_selectedIndex],
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined), // Changed icon to represent Dashboard
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.translate),
            label: "Translator",
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  // Extracted the Dashboard content into a widget to allow switching
  Widget _buildDashboardBody(NeuroSettings settings) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(_loadingStatus, style: TextStyle(color: Colors.teal.shade800)),
                  ],
                ),
              ).animate().fadeIn(),

            Text(
              "Namaste, ${settings.userName.isEmpty ? 'Friend' : settings.userName}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "One step at a time.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            _HeroCard(
              title: "Task Assistant",
              subtitle: "Auto-Analyze Voice & Video",
              icon: Icons.chat_bubble_outline_rounded,
              color: Colors.teal.shade50,
              iconColor: Colors.teal,
              onTap: () {
                if (!ModelHolder.isModelLoaded && _loadingStatus.isEmpty) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelSetupScreen()));
                } else if (!ModelHolder.isModelLoaded) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brain is waking up...")));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskBreakdownScreen()));
                }
              },
            ),

            const SizedBox(height: 24),

            _HeroCard(
              title: "AI Brain Manager",
              subtitle: ModelHolder.isModelLoaded ? "✅ Active" : "⚙️ Manage Models",
              icon: Icons.memory,
              color: Colors.blue.shade50,
              iconColor: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelSetupScreen())),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(icon, size: 36, color: iconColor),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(subtitle, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}