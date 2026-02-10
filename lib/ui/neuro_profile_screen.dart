import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';

class NeuroProfileScreen extends StatefulWidget {
  const NeuroProfileScreen({super.key});
  @override
  State<NeuroProfileScreen> createState() => _NeuroProfileScreenState();
}

class _NeuroProfileScreenState extends State<NeuroProfileScreen> {
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _sensoryController = TextEditingController();
  String _selectedLanguage = "English";

  final List<String> _languages = ["English", "Hindi", "Hinglish", "Bengali", "Tamil", "Telugu", "Kannada"];

  @override
  void initState() {
    super.initState();
    final settings = context.read<NeuroSettings>();
    _nameController.text = settings.userName;
    _diagnosisController.text = settings.diagnosis;
    _sensoryController.text = settings.sensorySensitivities;
    
    if (_languages.contains(settings.preferredLanguage)) {
      _selectedLanguage = settings.preferredLanguage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();
    
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("About Me (Encrypted & Synced)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 16),
          
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: const InputDecoration(labelText: "Preferred Language", border: OutlineInputBorder()),
            items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (val) => setState(() => _selectedLanguage = val!),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _diagnosisController,
            decoration: const InputDecoration(labelText: "Diagnosis", hintText: "ADHD, Autism...", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _sensoryController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: "Sensory Triggers", hintText: "Loud noises, bright lights...", border: OutlineInputBorder()),
          ),
          
          const SizedBox(height: 32),
          const Text("Accessibility", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          
          SwitchListTile(
            title: const Text("Dyslexic-Friendly Font"), 
            value: settings.useDyslexicFont, 
            onChanged: (val) => settings.toggleFont()
          ),
          SwitchListTile(
            title: const Text("High Contrast Mode"), 
            value: settings.highContrast, 
            onChanged: (val) => settings.toggleContrast()
          ),
          
          const SizedBox(height: 20),
          const Text("Detail Level"),
          Slider(
            value: settings.taskGranularity, 
            min: 0.0, max: 2.0, divisions: 2, 
            label: settings.taskGranularity == 0.0 ? "Simple" : "Detailed", 
            onChanged: (val) => settings.setGranularity(val)
          ),

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              settings.saveProfile(
                name: _nameController.text,
                diagnosis: _diagnosisController.text,
                sensory: _sensoryController.text,
                language: _selectedLanguage,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("Save & Encrypt"),
          ),
        ],
      ),
    );
  }
}