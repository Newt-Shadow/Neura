import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:io';

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

  @override
  void initState() { super.initState(); _checkModels(); }

  Future<void> _checkModels() async {
    for (var m in _models) {
      final exists = await GemmaDownloaderDataSource(model: DownloadModel(modelUrl: m['url'], modelFilename: m['filename'])).checkModelExistence();
      setState(() => m['isDownloaded'] = exists);
    }
  }

  Future<void> _download(int index) async {
    setState(() { _isBusy = true; _status = "Downloading..."; });
    await WakelockPlus.enable();
    final m = _models[index];
    await GemmaDownloaderDataSource(model: DownloadModel(modelUrl: m['url'], modelFilename: m['filename'])).downloadModel(token: "", onProgress: (p) => setState(() { _progress = p; _status = "${(p*100).toInt()}%"; }));
    await _checkModels();
    setState(() { _isBusy = false; _progress = null; });
    await WakelockPlus.disable();
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