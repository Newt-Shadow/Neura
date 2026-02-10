import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';
import 'profile_setup_screen.dart'; // We will create this next

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final settings = context.read<NeuroSettings>();
    
    // Call the Google Sign In logic
    final user = await settings.signInWithGoogle();
    
    if (user != null && context.mounted) {
      // Check if profile is empty (New User?)
      if (settings.userName == "Friend" || settings.userName.isEmpty) {
        // Go to Profile Setup
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen())
        );
      } else {
        // Existing user, go back or show success
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Welcome back!")),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign In Failed or Cancelled")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
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
              const CircularProgressIndicator()
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
            const SizedBox(height: 16),
            if (!settings.isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Continue as Guest", style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}