import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:io';
import 'dart:math';
import '../data/downloader_datasource.dart';
import '../domain/download_model.dart';
import '../logic/model_holder.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  
  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final List<Map<String, dynamic>> _models = [
    {'name': 'Gemma 2B (Fast)', 'filename': 'gemma-3n-E2B-it-int4.task', 'url': 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task', 'isDownloaded': false},
    {'name': 'Gemma 4B (Smart)', 'filename': 'gemma-3n-E4B-it-int4.task', 'url': 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task', 'isDownloaded': false},
  ];
  String _status = ""; double? _progress; bool _isBusy = false;
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  void initState() { super.initState(); _checkModels(); }

  Future<void> _checkModels() async {
    for (var m in _models) {
      final exists = await GemmaDownloaderDataSource(model: DownloadModel(modelUrl: m['url'], modelFilename: m['filename'])).checkModelExistence();
      setState(() => m['isDownloaded'] = exists);
    }
  }

  Future<void> _download(int index) async {
    setState(() { 
      _isBusy = true; 
      _status = "Starting..."; 
      _progress = 0;
    });
    
    await WakelockPlus.enable();
    final m = _models[index];
    
    try {
      await GemmaDownloaderDataSource(
        model: DownloadModel(modelUrl: m['url'], modelFilename: m['filename'])
      ).downloadModel(
        token: "", // It will now use the fallback token in datasource
        onProgress: (received, total) {
          setState(() {
            // Calculate percentage for the progress bar
            _progress = total > 0 ? received / total : 0;
            
            // Format the status string with size
            final receivedStr = _formatBytes(received, 1);
            final totalStr = _formatBytes(total, 1);
            final percent = (_progress! * 100).toInt();
            
            _status = "$percent% ($receivedStr / $totalStr)";
          });
        }
      );
      
      await _checkModels();
      if (mounted) {
        setState(() => _status = "Download Complete!");
      }
    } catch (e) {
      // Catch errors (like 401 Unauthorized) and show them
      if (mounted) {
        setState(() => _status = "Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isBusy = false; });
      }
      await WakelockPlus.disable();
    }
  }

  Future<void> _load(int index) async {
    setState(() { _isBusy = true; _status = "Loading..."; });
    final m = _models[index];
    final path = await GemmaDownloaderDataSource(model: DownloadModel(modelUrl: m['url'], modelFilename: m['filename'])).getFilePath();
    try {
      await ModelHolder.loadModel(path);
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brain Loaded!"))); Navigator.pop(context); }
    } catch(e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Brains")),
      body: Column(children: [
        if (_isBusy) LinearProgressIndicator(value: _progress),
        Expanded(child: ListView.builder(
          itemCount: _models.length,
          itemBuilder: (ctx, i) {
            final m = _models[i];
            return Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(m['name']),
                subtitle: Text(m['isDownloaded'] ? "Ready to use" : "Not downloaded"),
                trailing: m['isDownloaded']
                    ? ElevatedButton(onPressed: _isBusy ? null : () => _load(i), child: const Text("Load"))
                    : OutlinedButton(onPressed: _isBusy ? null : () => _download(i), child: const Text("Download")),
              ),
            );
          },
        ))
      ]),
    );
  }
}