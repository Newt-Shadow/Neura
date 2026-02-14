import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/neuro_settings.dart';
import 'profile_setup_screen.dart';
import 'smart_dashboard_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final settings = context.read<NeuroSettings>();

    // 1. Call Auth + Wait for Cloud Pull (Handled by NeuroSettings)
    final user = await settings.signInWithGoogle();

    if (!context.mounted) return;

    if (user != null) {
      // 2. Double-check: Is this a Brand New User?
      // (Even though NeuroSettings synced, we check if the profile field exists to decide navigation)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      bool isNewUser = true; // Default to new
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!;
         // If we have an encrypted profile string, they are an Existing User
         if (data['encrypted_profile'] != null && data['encrypted_profile'] != "") {
           isNewUser = false;
         }
      }

      if (context.mounted) {
        if (isNewUser) {
          // 🚀 Case A: New User -> Go to Profile Setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        } else {
          // 🏠 Case B: Existing User -> Go to Dashboard (Fresh Reload)
          // We use pushReplacement to reset the Dashboard state so it greets the user correctly.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SmartDashboardScreen()),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sync Complete. Welcome back!")),
          );
        }
      }
    } else {
      // ❌ Login Cancelled or Failed
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign In Failed or Cancelled")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings to trigger rebuild when isLoading changes (shows spinner)
    final settings = context.watch<NeuroSettings>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 80, color: Colors.teal),
            const SizedBox(height: 32),
            const Text(
              "Sync Your Mind",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Securely backup your history, streaks, and preferences with Google.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),

            if (settings.isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("Syncing Cloud Data...", style: TextStyle(color: Colors.grey)),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _handleGoogleSignIn(context),
                  icon: const Icon(Icons.login),
                  label: const Text("Continue with Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            if (!settings.isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Continue as Guest",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}