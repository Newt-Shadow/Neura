import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import 'panic_mode_screen.dart';
import 'body_double_screen.dart';
import '../logic/neuro_settings.dart';
import '../logic/model_holder.dart';
import '../data/downloader_datasource.dart';
import '../domain/download_model.dart';
import 'neuro_profile_screen.dart';
import 'task_breakdown_screen.dart';
import 'sign_in_screen.dart';
import 'model_setup_screen.dart';
import 'translator_screen.dart';
import 'debug_log_screen.dart';

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
  
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadModel();
    });
    
    final settings = context.read<NeuroSettings>();
    settings.addListener(() {
      if (settings.showLevelUpAnimation && mounted) {
        _confettiController.play();
        settings.consumeLevelUpEvent(); 
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("🎉 LEVEL UP! You are amazing! 🎉"), backgroundColor: Colors.purple),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _autoLoadModel() async {
    final settings = context.read<NeuroSettings>();
    if (!settings.useLocalModel) return;
    if (ModelHolder.isModelLoaded) return;

    final downloader = GemmaDownloaderDataSource(
      model: DownloadModel(modelUrl: _modelUrl, modelFilename: _filename),
    );
    await downloader.checkModelExistence();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CONSUMER ensures we rebuild whenever Settings changes
    return Consumer<NeuroSettings>(
      builder: (context, settings, child) {
        final isGuest = settings.currentUser == null;
        final String? authorizedEmail = dotenv.env['ADMIN_EMAIL'];
        final String? currentEmail = settings.currentUser?.email;
        final bool isAdmin = (currentEmail != null && authorizedEmail != null && currentEmail.trim() == authorizedEmail.trim());

        final List<Widget> screens = [
          _buildDashboardBody(settings),
          const NeuroProfileScreen(),
        ];

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text(" Neura ", style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
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
                        Text("${settings.streakCount}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.terminal, color: Colors.grey),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugLogScreen())),
                    ),
                  IconButton(
                    icon: const Icon(Icons.volunteer_activism, color: Colors.pinkAccent),
                    onPressed: () => Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const PanicModeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c))),
                  ),
                  if (isGuest)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
                        icon: const Icon(Icons.login, color: Colors.teal),
                        label: const Text("Sign In", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: CircleAvatar(
                        backgroundColor: Colors.teal,
                        backgroundImage: settings.currentUser?.photoURL != null ? NetworkImage(settings.currentUser!.photoURL!) : null,
                        child: settings.currentUser?.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      onSelected: (val) {
                        if (val == 'profile') setState(() => _selectedIndex = 1);
                        else if (val == 'logout') settings.signOut();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'profile', child: Text("Logged in as ${settings.currentUser?.displayName ?? 'User'}")),
                        const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text("Sign Out", style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                ],
              ),
              body: screens[_selectedIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), label: "Home"),
                  NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.teal, Colors.purple, Colors.amber, Colors.pink], 
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardBody(NeuroSettings settings) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingStatus.isNotEmpty)
              Text(_loadingStatus, style: const TextStyle(color: Colors.teal)),

            Text(
              "Namaste, ${settings.userName.isEmpty ? 'Friend' : settings.userName}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            _buildXpBar(settings), // 🔥 THIS WILL NOW AUTO-UPDATE
            const SizedBox(height: 16),
            
            const Text("One step at a time.", style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 48),

            _HeroCard(
              title: "Task Assistant",
              subtitle: "Auto-Analyze Voice & Video",
              icon: Icons.chat_bubble_outline_rounded,
              color: Colors.teal.shade50,
              iconColor: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskBreakdownScreen())),
            ),
            const SizedBox(height: 24),

            _HeroCard(
              title: "Body Double",
              subtitle: "Work together. No pressure.",
              icon: Icons.people_outline,
              color: Colors.purple.shade50,
              iconColor: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyDoubleScreen())),
            ),
             const SizedBox(height: 24),
             _HeroCard(
              title: "AI Brain Manager",
              subtitle: ModelHolder.isModelLoaded ? "   Active" : "⚙️ Manage Models",
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
  
  Widget _buildXpBar(NeuroSettings settings) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Lvl ${settings.level}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              Text("${settings.xp} / ${settings.xpToNextLevel} XP", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        LinearPercentIndicator(
          lineHeight: 10.0,
          percent: settings.levelProgress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          progressColor: Colors.teal,
          barRadius: const Radius.circular(10),
          animation: true, // Animation might hide instant updates if duration is too long
          animationDuration: 800,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _HeroCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
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