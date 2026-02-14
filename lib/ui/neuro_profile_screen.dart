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
  
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _sensoryCtrl;
  late TextEditingController _interestCtrl;

  // Focus Nodes for Auto-Save
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _diagnosisFocus = FocusNode();
  final FocusNode _sensoryFocus = FocusNode();
  final FocusNode _interestFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final settings = context.read<NeuroSettings>();
    _nameCtrl = TextEditingController(text: settings.userName);
    _diagnosisCtrl = TextEditingController(text: settings.disabilityType);
    _sensoryCtrl = TextEditingController(text: settings.sensoryTriggers);
    _interestCtrl = TextEditingController(text: settings.interest);

    // Attach Listeners: Save immediately when user leaves a text box
    _nameFocus.addListener(() => _onFocusLost(_nameFocus));
    _diagnosisFocus.addListener(() => _onFocusLost(_diagnosisFocus));
    _sensoryFocus.addListener(() => _onFocusLost(_sensoryFocus));
    _interestFocus.addListener(() => _onFocusLost(_interestFocus));
  }

  @override
  void dispose() {
    // Final Save check when screen is destroyed
    _performSave(silent: true);

    _nameCtrl.dispose();
    _diagnosisCtrl.dispose();
    _sensoryCtrl.dispose();
    _interestCtrl.dispose();
    
    _nameFocus.dispose();
    _diagnosisFocus.dispose();
    _sensoryFocus.dispose();
    _interestFocus.dispose();
    super.dispose();
  }

  // Triggered whenever a field gains or loses focus
  void _onFocusLost(FocusNode node) {
    if (!node.hasFocus) {
      // User left the text area -> Sync immediately
      _performSave(silent: true);
    }
  }

  void _performSave({bool silent = false}) {
    // Basic validation check (skip saving empty name if user cleared it by mistake)
    if (_nameCtrl.text.trim().isEmpty) return;

    context.read<NeuroSettings>().saveProfile(
      name: _nameCtrl.text,
      diagnosis: _diagnosisCtrl.text,
      sensory: _sensoryCtrl.text,
      language: "English",
      interest: _interestCtrl.text,
    );

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Saved & Encrypted 🔒")),
      );
    } else {
      print("☁️ Auto-Syncing Profile...");
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    // PopScope ensures data is saved even if user hits "Back" without clicking anything
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) _performSave(silent: true);
      },
      child: Scaffold(
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
                  // ✅ Fix: Pass FocusNode as 4th positional argument
                  _buildTextField("Name", _nameCtrl, Icons.person, _nameFocus),
                  
                  const SizedBox(height: 15),
                  
                  _buildTextField("Diagnosis / Context", _diagnosisCtrl, Icons.medical_services, _diagnosisFocus, 
                    hint: "e.g. ADHD, Dyslexia, Anxiety, or 'Just Busy'"),
                  
                  const SizedBox(height: 15),
                  
                  _buildTextField("Sensory Triggers", _sensoryCtrl, Icons.warning_amber, _sensoryFocus,
                    hint: "e.g. Loud noises, Bright lights"),
                  
                  const SizedBox(height: 15),
                  
                  _buildTextField("Special Interest", _interestCtrl, Icons.favorite, _interestFocus,
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

                  // OFFLINE AI TOGGLE
                  SwitchListTile(
                    title: const Text("Use Offline AI (Beta)"),
                    subtitle: const Text("Requires 1.5GB download. Works without internet."),
                    value: settings.useLocalModel,
                    onChanged: (val) => settings.toggleLocalModel(val),
                    activeColor: Colors.teal,
                  ),

                  const SizedBox(height: 30),
                  
                  // Manual Button (Kept for reassurance)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _performSave(silent: false),
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
      ),
    );
  }

  // ✅ Definition: FocusNode is the 4th POSITIONAL argument
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, FocusNode focusNode, {String? hint}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // ✅ Connects the detector
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        
      ),
    );
  }
}