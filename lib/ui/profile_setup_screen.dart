import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _sensoryController = TextEditingController();
  String _selectedLanguage = "English";

  final List<String> _languages = ["English", "Hindi", "Hinglish", "Bengali", "Tamil", "Telugu", "Kannada"];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text("Setup Your Profile")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Welcome to Neuro!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 8),
          const Text("Let's personalize your experience. You can change this later."),
          const SizedBox(height: 32),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "What should I call you?",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: const InputDecoration(
              labelText: "Preferred Language",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.language),
            ),
            items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (val) => setState(() => _selectedLanguage = val!),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(
              labelText: "Diagnosis (Optional)",
              hintText: "e.g., ADHD, Autism, Anxiety",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.medical_services_outlined),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _sensoryController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Sensory Triggers (Optional)",
              hintText: "e.g., Loud noises, bright lights",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.hearing),
            ),
          ),
          
          const SizedBox(height: 40),
          
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                settings.saveProfile(
                  name: _nameController.text.trim().isEmpty ? "Friend" : _nameController.text.trim(),
                  diagnosis: _diagnosisController.text.trim(),
                  sensory: _sensoryController.text.trim(),
                  language: _selectedLanguage,
                );
                Navigator.pop(context); // Go back to dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Skip for now"),
          ),
        ],
      ),
    );
  }
}