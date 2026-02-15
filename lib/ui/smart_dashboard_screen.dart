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

        // ✅ FIX: Wrapped Scaffold and Confetti in a Stack so Confetti plays OVER the UI
        return Stack(
          children: [
            Scaffold(
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
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${settings.streakCount}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // In your AppBar actions:
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.terminal, color: Colors.grey),
                      tooltip: "System Logs (Admin)",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DebugLogScreen()),
                        );
                      },
                    ),
                  // 🚨 PANIC BUTTON
                  IconButton(
                    icon: const Icon(
                      Icons.volunteer_activism,
                      color: Colors.pinkAccent,
                    ),
                    tooltip: "Sensory Rescue",
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const PanicModeScreen(),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                        ),
                      );
                    },
                  ),
                  // 🔋 BRAIN BATTERY (Fixed)
                  IconButton(
                    onPressed: () => _showBrainStateMenu(context, settings),
                    icon: Icon(
                      settings.isOverwhelmed
                          ? Icons.battery_alert
                          : _getBatteryIcon(settings.energyLevel),
                      color: _getBatteryColor(settings.energyLevel),
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
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: CircleAvatar(
                        backgroundColor: Colors.teal,
                        backgroundImage: settings.currentUser?.photoURL != null
                            ? NetworkImage(settings.currentUser!.photoURL!)
                            : null,
                        child: settings.currentUser?.photoURL == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      onSelected: (val) {
                        if (val == 'profile') {
                          setState(() => _selectedIndex = 1); // Go to Profile Tab
                        } else if (val == 'logout') {
                          settings.signOut();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Text(
                            "Logged in as ${settings.currentUser?.displayName ?? 'User'}",
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person),
                              SizedBox(width: 8),
                              Text("My Profile"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Sign Out", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
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
                    icon: Icon(
                      Icons.dashboard_customize_outlined,
                    ), // Changed icon to represent Dashboard
                    label: "Home",
                  ),
                  NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
                ],
              ),
            ),
            
            // ✅ Confetti Layer (Now properly placed in Stack)
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

  // Extracted the Dashboard content into a widget to allow switching
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
                final useLocal = settings.useLocalModel;
                if (!useLocal) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskBreakdownScreen()));
                  return;
                }
                if (!ModelHolder.isModelLoaded) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelSetupScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskBreakdownScreen()));
                }
              },
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
          animation: true, 
          animationDuration: 800,
        ),
      ],
    );
  }

  IconData _getBatteryIcon(double level) {
    if (level > 0.8) return Icons.battery_full;
    if (level > 0.5) return Icons.battery_5_bar;
    if (level > 0.2) return Icons.battery_2_bar;
    return Icons.battery_0_bar;
  }

  Color _getBatteryColor(double level) {
    if (level > 0.6) return Colors.teal;
    if (level > 0.3) return Colors.orange;
    return Colors.red;
  }

  void _showBrainStateMenu(BuildContext context, NeuroSettings settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // ✅ FIX: Added SafeArea here to prevent bottom menu from being hidden by system navigation
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Brain Battery Check 🔋",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                const Text("How much energy do you have?"),
                Slider(
                  value: settings.energyLevel,
                  min: 0.0,
                  max: 1.0,
                  divisions: 5,
                  activeColor: _getBatteryColor(settings.energyLevel),
                  label: "${(settings.energyLevel * 100).toInt()}%",
                  onChanged: (val) => settings.setEnergy(val),
                ),

                const SizedBox(height: 10),

                SwitchListTile(
                  title: const Text("I am Overwhelmed"),
                  subtitle: const Text("Switch to 'Panic Mode' (Gentler AI)"),
                  value: settings.isOverwhelmed,
                  activeColor: Colors.pink,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    settings.setOverwhelm(val);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
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