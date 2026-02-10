import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    
    // 1. Simulate network/auth delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      // 2. Trigger the logic in settings
      // (Uses the Hardcoded Key or Firebase if configured)
      await context.read<NeuroSettings>().signInWithGoogle();
      
      setState(() => _isLoading = false);
      
      // 3. Show Success & Close Screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signed In! History will now sync."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Go back to Dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context), // "Continue as Guest" logic
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_sync, size: 80, color: Colors.teal),
            const SizedBox(height: 32),
            const Text(
              "Sync Your Brain",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Sign in to backup your history, preferences, and streaks to the cloud.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text("Sign In with Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Not now, continue as Guest", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}