import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';

class NeuroProfileScreen extends StatefulWidget {
  const NeuroProfileScreen({super.key});

  @override
  State<NeuroProfileScreen> createState() => _NeuroProfileScreenState();
}

class _NeuroProfileScreenState extends State<NeuroProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _sensoryCtrl;
  late TextEditingController _interestCtrl;

  @override
  void initState() {
    super.initState();
    final settings = context.read<NeuroSettings>();
    _nameCtrl = TextEditingController(text: settings.userName);
    _diagnosisCtrl = TextEditingController(text: settings.disabilityType);
    _sensoryCtrl = TextEditingController(text: settings.sensoryTriggers);
    _interestCtrl = TextEditingController(text: settings.interest);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _diagnosisCtrl.dispose();
    _sensoryCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      context.read<NeuroSettings>().saveProfile(
        name: _nameCtrl.text,
        diagnosis: _diagnosisCtrl.text,
        sensory: _sensoryCtrl.text,
        language: "English", // Default or add dropdown
        interest: _interestCtrl.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Saved & Encrypted 🔒")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Neuro Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Customize your AI assistant.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),

                // --- 1. PERSONAL DETAILS ---
                _buildTextField("Name", _nameCtrl, Icons.person),
                const SizedBox(height: 15),
                _buildTextField("Diagnosis / Context", _diagnosisCtrl, Icons.medical_services, 
                  hint: "e.g. ADHD, Dyslexia, Anxiety, or 'Just Busy'"),
                const SizedBox(height: 15),
                _buildTextField("Sensory Triggers", _sensoryCtrl, Icons.warning_amber,
                  hint: "e.g. Loud noises, Bright lights"),
                const SizedBox(height: 15),
                _buildTextField("Special Interest", _interestCtrl, Icons.favorite,
                  hint: "e.g. Coding, Art, Space (Used for metaphors)"),

                const SizedBox(height: 30),
                const Divider(),
                
                // --- 2. APP PREFERENCES ---
                const Text("Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                
                SwitchListTile(
                  title: const Text("Dyslexia Friendly Font"),
                  value: settings.dyslexiaMode,
                  onChanged: (val) => settings.toggleFont(),
                  activeColor: Colors.teal,
                ),

                // 🔥 NEW: OFFLINE AI TOGGLE
                SwitchListTile(
                  title: const Text("Use Offline AI (Beta)"),
                  subtitle: const Text("Requires 1.5GB download. Works without internet."),
                  value: settings.useLocalModel,
                  onChanged: (val) => settings.toggleLocalModel(val),
                  activeColor: Colors.teal,
                ),

                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("Save Changes"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {String? hint}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: (_) {
        // Auto-save draft logic could go here if needed
      },
    );
  }
}