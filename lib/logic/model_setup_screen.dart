import 'package:flutter/material.dart';
import 'package:neuro/data/downloader_datasource.dart';
import 'package:neuro/domain/download_model.dart';
import 'package:neuro/logic/model_holder.dart';
import 'package:neuro/main.dart'; // To restart/navigate after success
import 'package:neuro/ui/smart_dashboard_screen.dart'; // <--- Add this import

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  // CONFIGURATION: Set your model URL here
  final _modelConfig = DownloadModel(
    modelUrl: "https://huggingface.co/google/gemma-2b-it-gpu-int4/resolve/main/model.bin", // Example URL
    modelFilename: "gemma-2b-it-gpu-int4.bin",
  );

  late GemmaDownloaderDataSource _dataSource;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = "AI Brain Missing";

  @override
  void initState() {
    super.initState();
    _dataSource = GemmaDownloaderDataSource(model: _modelConfig);
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    bool exists = await _dataSource.checkModelExistence();
    if (exists) {
      _initializeAndContinue();
    } else {
      setState(() => _status = "Tap below to download the AI Brain (1.5 GB)");
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = "Downloading... (Do not close app)";
    });

    try {
      await _dataSource.downloadModel(
        token: "", // Add your HuggingFace token if required, or leave empty if public
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );
      
      _initializeAndContinue();
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status = "Download Failed: ${e.toString()}";
        _progress = 0;
      });
    }
  }

  Future<void> _initializeAndContinue() async {
    setState(() => _status = "Initializing Intelligence...");
    
    try {
      final path = await _dataSource.getFilePath();
      
      // Use your ModelHolder to load it
      await ModelHolder.loadModel(path);

      if (mounted) {
        // Navigate to your main app (SignIn or Dashboard)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyApp(initialScreen: SmartDashboardScreen()),
        ),
        );
      }
    } catch (e) {
      setState(() => _status = "Initialization Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text(
                "Setup Neuro Engine",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              if (_isDownloading) ...[
                LinearProgressIndicator(value: _progress, minHeight: 10),
                const SizedBox(height: 10),
                Text("${(_progress * 100).toStringAsFixed(1)}%"),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download),
                  label: const Text("Download Offline Model"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}