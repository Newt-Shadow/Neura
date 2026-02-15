import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BodyDoubleScreen extends StatefulWidget {
  const BodyDoubleScreen({super.key});

  @override
  State<BodyDoubleScreen> createState() => _BodyDoubleScreenState();
}

class _BodyDoubleScreenState extends State<BodyDoubleScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _isActive = false;
  String _currentMessage = "I'm here with you. Let's start.";
  
  // Smart "Passive" AI Responses (No API needed for this to keep it offline-capable)
  final List<String> _gentlePrompts = [
    "You're doing great. Just one small thing.",
    "Remember to drink some water.",
    "I'm still here. No pressure.",
    "Deep breath. You got this.",
    "It's okay to take it slow.",
    "Focus on just the next 5 minutes.",
  ];

  void _toggleTimer() {
    setState(() => _isActive = !_isActive);
    if (_isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _seconds++;
          // Every 5 minutes (300 seconds), change the gentle message
          if (_seconds % 300 == 0) {
            _currentMessage = _gentlePrompts[Random().nextInt(_gentlePrompts.length)];
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  String _formatTime(int totalSeconds) {
    int min = totalSeconds ~/ 60;
    int sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: const Text("Buddy"),
        backgroundColor: Colors.teal.shade50,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar / Presence Indicator
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(Icons.accessibility_new, size: 60, color: Colors.teal),
            ).animate(target: _isActive ? 1 : 0)
             .shimmer(duration: 2000.ms, color: Colors.teal.shade100), // Subtle shimmer when active

            const SizedBox(height: 40),

            // Gentle Message
            Text(
              _currentMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Colors.teal.shade800,
                fontWeight: FontWeight.w500,
              ),
            ).animate(key: ValueKey(_currentMessage)).fadeIn().slideY(begin: 0.2, end: 0),

            const SizedBox(height: 40),

            // Timer Display
            Text(
              _formatTime(_seconds),
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()], // Keeps numbers steady
              ),
            ),

            const SizedBox(height: 40),

            // Toggle Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActive ? Colors.orange.shade300 : Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(_isActive ? Icons.pause : Icons.play_arrow),
                label: Text(
                  _isActive ? "Take a Break" : "Start Working Together",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}