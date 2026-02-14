import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PanicModeScreen extends StatefulWidget {
  const PanicModeScreen({super.key});

  @override
  State<PanicModeScreen> createState() => _PanicModeScreenState();
}

class _PanicModeScreenState extends State<PanicModeScreen> with SingleTickerProviderStateMixin {
  bool _isBreathing = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark mode for sensory reduction
      body: SafeArea(
        child: Stack(
          children: [
            // Center Breathing Circle
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.teal.shade900, Colors.black],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 40, spreadRadius: 10)
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Breathe",
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(duration: 4000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)) // 4-second inhale
                  .then(delay: 2000.ms) // Hold
                  .scale(duration: 4000.ms, begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)), // 4-second exhale

                  const SizedBox(height: 50),
                  
                  const Text(
                    "You are safe.\nThis feeling will pass.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5),
                  ).animate().fadeIn(duration: 1000.ms),
                ],
              ),
            ),

            // Exit Button (Subtle)
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white30, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}