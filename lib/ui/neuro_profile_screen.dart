import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/neuro_settings.dart';
// ✅ Import the necessary files
import 'language_dropdown.dart'; 
import '../localization/lingua_supportata.dart';
import '../localization/load_lingue.dart'; 

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

  bool _userIsTyping = false;

  // ✅ Added State variables for Language
  List<LinguaSupportata> _supportedLanguages = [];
  bool _isLoadingLanguages = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<NeuroSettings>();
    _nameCtrl = TextEditingController(text: settings.userName);
    _diagnosisCtrl = TextEditingController(text: settings.disabilityType);
    _sensoryCtrl = TextEditingController(text: settings.sensoryTriggers);
    _interestCtrl = TextEditingController(text: settings.interest);

    // ✅ Load languages when screen starts
    _loadLanguages();

    void setTyping() => _userIsTyping = true;
    void clearTyping() => _userIsTyping = false;

    // Track typing
    _nameCtrl.addListener(setTyping);
    _diagnosisCtrl.addListener(setTyping);
    _sensoryCtrl.addListener(setTyping);
    _interestCtrl.addListener(setTyping);

    // Attach Listeners
    _nameFocus.addListener(() { if (!_nameFocus.hasFocus) { clearTyping(); _onFocusLost(_nameFocus); }});
    _diagnosisFocus.addListener(() { if (!_diagnosisFocus.hasFocus) { clearTyping(); _onFocusLost(_diagnosisFocus); }});
    _sensoryFocus.addListener(() { if (!_sensoryFocus.hasFocus) { clearTyping(); _onFocusLost(_sensoryFocus); }});
    _interestFocus.addListener(() { if (!_interestFocus.hasFocus) { clearTyping(); _onFocusLost(_interestFocus); }});
  }

  // ✅ Function to load languages from JSON
  Future<void> _loadLanguages() async {
    try {
      // ✅ FIXED: Calling the static class method properly
      final list = await LoadLingue.leggiLingueSupportate(); 
      if (mounted) {
        setState(() {
          _supportedLanguages = list;
          _isLoadingLanguages = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading languages: $e");
      if (mounted) setState(() => _isLoadingLanguages = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<NeuroSettings>();

    if (!_userIsTyping) {
      if (_nameCtrl.text == "Friend" && settings.userName != "Friend") {
        _nameCtrl.text = settings.userName;
      }
      if (_diagnosisCtrl.text == "ADHD" && settings.disabilityType != "ADHD") {
        _diagnosisCtrl.text = settings.disabilityType;
      }
      if (_sensoryCtrl.text != settings.sensoryTriggers) {
         _sensoryCtrl.text = settings.sensoryTriggers;
      }
      if (_interestCtrl.text != settings.interest) {
         _interestCtrl.text = settings.interest;
      }
    }
  }

  @override
  void dispose() {
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

  void _onFocusLost(FocusNode node) {
    if (!node.hasFocus) {
      _performSave(silent: true);
    }
  }

  void _performSave({bool silent = false}) {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (!mounted) return;

    final currentLang = context.read<NeuroSettings>().preferredLanguage;

    context.read<NeuroSettings>().saveProfile(
      name: _nameCtrl.text,
      diagnosis: _diagnosisCtrl.text,
      sensory: _sensoryCtrl.text,
      language: currentLang, // Use the selected language
      interest: _interestCtrl.text,
    );

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Saved & Encrypted 🔒")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NeuroSettings>();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _performSave(silent: true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Profile Settings")),
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

                  const SizedBox(height: 15),

                  // ✅ LANGUAGE DROPDOWN ADDED HERE
                  const Text("Assistant Language", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _isLoadingLanguages
                      ? const LinearProgressIndicator()
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: LanguageDropdown(
                            lingue: _supportedLanguages,
                            linguaSelezionata: settings.preferredLanguage,
                            onChanged: (newLang) {
                              if (newLang != null) {
                                // Save immediately when language changes
                                context.read<NeuroSettings>().saveProfile(
                                  name: _nameCtrl.text,
                                  diagnosis: _diagnosisCtrl.text,
                                  sensory: _sensoryCtrl.text,
                                  language: newLang,
                                  interest: _interestCtrl.text,
                                );
                              }
                            },
                          ),
                        ),

                  const SizedBox(height: 30),
                  const Divider(),

                  const Text("Current Brain State", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text("Helps the AI adapt its tone right now.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),

                  // ENERGY SLIDER
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Energy Level"),
                    subtitle: Text(
                      settings.energyLevel > 0.7 ? "High Energy 🚀" : 
                      settings.energyLevel > 0.3 ? "Balanced 😐" : "Low Battery 🪫"
                    ),
                    trailing: Text("${(settings.energyLevel * 100).toInt()}%"),
                  ),
                  Slider(
                    value: settings.energyLevel,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: Colors.teal,
                    label: "${(settings.energyLevel * 100).toInt()}%",
                    onChanged: (val) => settings.setEnergy(val),
                  ),

                  // OVERWHELM SWITCH
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("I am Overwhelmed"),
                    subtitle: const Text("Activates 'Panic Mode' (simpler steps, gentler tone)."),
                    value: settings.isOverwhelmed,
                    activeColor: Colors.pinkAccent,
                    onChanged: (val) => settings.setOverwhelm(val),
                  ),

                  const SizedBox(height: 10),
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
                  
                  // Manual Button
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, FocusNode focusNode, {String? hint}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, 
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