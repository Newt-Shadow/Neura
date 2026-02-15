import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/percent_indicator.dart';

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
import 'debug_log_screen.dart';

class SmartDashboardScreen extends StatefulWidget {
  const SmartDashboardScreen({super.key});

  @override
  State<SmartDashboardScreen> createState() => _SmartDashboardScreenState();
}

class _SmartDashboardScreenState extends State<SmartDashboardScreen> {
  final String _modelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';
  final String _filename = 'gemma-3n-E2B-it-int4.task';

  int _selectedIndex = 0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoadModel());

    context.read<NeuroSettings>().addListener(() {
      if (context.read<NeuroSettings>().showLevelUpAnimation && mounted) {
        _confettiController.play();
        context.read<NeuroSettings>().consumeLevelUpEvent();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 LEVEL UP! You are amazing! 🎉"),
            backgroundColor: Colors.purple,
          ),
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
    if (!settings.useLocalModel || ModelHolder.isModelLoaded) return;
    final downloader = GemmaDownloaderDataSource(
      model: DownloadModel(modelUrl: _modelUrl, modelFilename: _filename),
    );
    await downloader.checkModelExistence();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NeuroSettings>(
      builder: (context, settings, child) {
        final isGuest = settings.currentUser == null;

        final List<Widget> screens = [
          _buildZenDashboard(settings),
          const NeuroProfileScreen(),
        ];

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: const Text(
                  "Neuro",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.health_and_safety,
                    color: Colors.pinkAccent,
                  ),
                  tooltip: "Panic Mode",
                  onPressed: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const PanicModeScreen(),
                      transitionsBuilder: (_, a, __, c) =>
                          FadeTransition(opacity: a, child: c),
                    ),
                  ),
                ),
                actions: [
                  if (isGuest)
                    IconButton(
                      icon: const Icon(Icons.login, color: Colors.teal),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage:
                              settings.currentUser?.photoURL != null
                              ? NetworkImage(settings.currentUser!.photoURL!)
                              : null,
                          child: settings.currentUser?.photoURL == null
                              ? const Icon(Icons.person, color: Colors.teal)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),

              body: screens[_selectedIndex],

              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    label: "Dashboard",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    label: "Profile",
                  ),
                ],
              ),
            ),

            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.teal,
                  Colors.purple,
                  Colors.amber,
                  Colors.pink,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZenDashboard(NeuroSettings settings) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            "Hi, ${settings.userName.isEmpty ? 'Friend' : settings.userName}",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ✅ 1. XP Bar
          _buildXpBar(settings),
          const SizedBox(height: 20),

          // ✅ 2. Status Chips (Star Added)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  icon: Icons.star,
                  color: Colors.amber,
                  label: "Lvl ${settings.level}",
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _StatusChip(
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                  label: "${settings.streakCount} Day Streak",
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _StatusChip(
                  icon: settings.isOverwhelmed
                      ? Icons.battery_alert
                      : _getBatteryIcon(settings.energyLevel),
                  color: _getBatteryColor(settings.energyLevel),
                  label: "${(settings.energyLevel * 100).toInt()}% Energy",
                  isOutline: true,
                  onTap: () => _showBrainStateMenu(context, settings),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ✅ 3. Full Width Cards
          _HeroCard(
            title: "Task Assistant",
            subtitle: "Break down goals & chaos.",
            icon: Icons.auto_awesome,
            color: Colors.teal.shade50,
            iconColor: Colors.teal,
            isHighContrast: settings.highContrast,
            onTap: () {
              if (settings.useLocalModel && !ModelHolder.isModelLoaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModelSetupScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaskBreakdownScreen(),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          _HeroCard(
            title: "Buddy",
            subtitle: "Stay focused. I'll watch the time.",
            icon: Icons.support_agent,
            color: Colors.purple.shade50,
            iconColor: Colors.purple,
            isHighContrast: settings.highContrast,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BodyDoubleScreen()),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ 4. AI Brain (Now Full Width)
          _HeroCard(
            title: "AI Brain Manager",
            subtitle: ModelHolder.isModelLoaded
                ? "Active: Ready to think offline."
                : "Offline Mode: Tap to setup.",
            icon: Icons.psychology,
            color: Colors.blue.shade50,
            iconColor: Colors.blue,
            isHighContrast: settings.highContrast,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModelSetupScreen()),
            ),
          ),

          if (settings.currentUser != null &&
              settings.currentUser!.email != null &&
              dotenv.env['ADMIN_EMAIL'] != null &&
              settings.currentUser!.email == dotenv.env['ADMIN_EMAIL']) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.terminal, size: 16),
                label: const Text("Admin Logs"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugLogScreen()),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildXpBar(NeuroSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Level ${settings.level}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            Text(
              "${settings.xp} / ${settings.xpToNextLevel} XP",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 8.0,
          percent: settings.levelProgress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          progressColor: Colors.teal,
          barRadius: const Radius.circular(10),
          padding: EdgeInsets.zero,
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                SwitchListTile(
                  title: const Text("I am Overwhelmed"),
                  subtitle: const Text("Switch to 'Panic Mode' (Gentler AI)"),
                  value: settings.isOverwhelmed,
                  activeColor: Colors.pink,
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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isOutline;
  final VoidCallback onTap;

  const _StatusChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
  final bool isHighContrast;
  final double? height;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.isHighContrast = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final finalBg = isHighContrast ? Colors.white : color;
    final finalIcon = isHighContrast ? Colors.black : iconColor;
    final border = isHighContrast
        ? Border.all(color: Colors.black, width: 3)
        : null;
    final titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isHighContrast ? Colors.black : Colors.black87,
    );

    return Container(
      height: height,
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: finalBg,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: isHighContrast
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 32, color: finalIcon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: titleStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isHighContrast
                                  ? Colors.black
                                  : Colors.black54,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isHighContrast ? Colors.black : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
