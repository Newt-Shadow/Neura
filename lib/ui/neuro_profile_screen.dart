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
          const Text("About Me (Encrypted)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
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

          TextField(controller: _diagnosisController, decoration: const InputDecoration(labelText: "Diagnosis", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          TextField(controller: _sensoryController, maxLines: 2, decoration: const InputDecoration(labelText: "Sensory Triggers", border: OutlineInputBorder())),
          
          const SizedBox(height: 32),
          const Text("Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          
          SwitchListTile(title: const Text("Dyslexic-Friendly Font"), value: settings.useDyslexicFont, onChanged: (val) => settings.toggleFont()),
          SwitchListTile(title: const Text("High Contrast Mode"), value: settings.highContrast, onChanged: (val) => settings.toggleContrast()),
          
          const SizedBox(height: 40),
          
          // SAFE SAVE BUTTON
          ElevatedButton(
            onPressed: () async {
              settings.saveProfile(
                name: _nameController.text,
                diagnosis: _diagnosisController.text,
                sensory: _sensoryController.text,
                language: _selectedLanguage,
              );
              FocusScope.of(context).unfocus();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved ✅"), backgroundColor: Colors.teal));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("Save & Encrypt"),
          ),

          const SizedBox(height: 40),
          const Divider(thickness: 2),
          const SizedBox(height: 20),

          // THE RESET BUTTON (Fixes Glitches)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.shade50
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Reset App Data", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text("Fixes glitches, leakage & history issues.", style: TextStyle(fontSize: 12)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Reset Everything?"),
                    content: const Text("This will wipe all local history and settings to fix the bugs. Cloud data is safe."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () {
                          settings.clearAllData(); // CALLS THE NEW FUNCTION
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset Complete. Restarting...")));
                        },
                        child: const Text("Reset", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}