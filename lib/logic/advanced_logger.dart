import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogType { info, api, llm, error, user }

class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String title;
  final String message;
  final dynamic jsonContent;
  final String? imagePath; // Optional: path or base64 preview

  LogEntry({
    required this.type,
    required this.title,
    required this.message,
    this.jsonContent,
    this.imagePath,
  }) : timestamp = DateTime.now();
}

class AdvancedLogger {
  // Singleton
  static final AdvancedLogger _instance = AdvancedLogger._internal();
  factory AdvancedLogger() => _instance;
  AdvancedLogger._internal();

  final List<LogEntry> _logs = [];
  final StreamController<List<LogEntry>> _logStream = StreamController.broadcast();

  Stream<List<LogEntry>> get logsStream => _logStream.stream;
  List<LogEntry> get history => List.unmodifiable(_logs);

  // ===========================================================================
  // 📝 LOGGING METHODS
  // ===========================================================================

  void log(LogType type, String title, String message, {dynamic jsonContent, String? imagePath}) {
    final entry = LogEntry(
      type: type,
      title: title,
      message: message,
      jsonContent: jsonContent,
      imagePath: imagePath,
    );

    _logs.insert(0, entry); // Add newest first
    _logStream.add(_logs);
    
    // Also print to Terminal
    _printToConsole(entry);
  }

  void logApi({required String method, required String url, dynamic body, dynamic response}) {
    log(
      LogType.api, 
      "☁️ API [$method]", 
      url, 
      jsonContent: {
        "request": body,
        "response": response
      }
    );
  }

  void logLLM({required String model, required String prompt, required String output}) {
    log(
      LogType.llm, 
      "🧠 LOCAL LLM ($model)", 
      "Generation complete", 
      jsonContent: {
        "prompt": prompt,
        "output": output
      }
    );
  }

  void clearLogs() {
    _logs.clear();
    _logStream.add([]);
  }

  // ===========================================================================
  // 🖥️ TERMINAL FORMATTING
  // ===========================================================================

  void _printToConsole(LogEntry entry) {
    if (kReleaseMode) return;

    const String reset = '\x1B[0m';
    String color;
    String icon;

    switch (entry.type) {
      case LogType.api:
        color = '\x1B[36m'; // Cyan
        icon = "☁️";
        break;
      case LogType.llm:
        color = '\x1B[32m'; // Green
        icon = "🧠";
        break;
      case LogType.error:
        color = '\x1B[31m'; // Red
        icon = "🔥";
        break;
      case LogType.user:
        color = '\x1B[35m'; // Magenta
        icon = "👤";
        break;
      default:
        color = '\x1B[37m'; // White
        icon = "ℹ️";
    }

    final time = "${entry.timestamp.hour}:${entry.timestamp.minute}:${entry.timestamp.second}";
    debugPrint('$color[$time] $icon ${entry.title}: ${entry.message}$reset');
    
    if (entry.jsonContent != null) {
      try {
        // Pretty print JSON
        var encoder = const JsonEncoder.withIndent('  ');
        String pretty = encoder.convert(entry.jsonContent);
        // Truncate if too long for terminal
        if (pretty.length > 2000) pretty = "${pretty.substring(0, 2000)}... [TRUNCATED]";
        debugPrint('$color$pretty$reset');
      } catch (e) {
        debugPrint('$color[Raw Data]: ${entry.jsonContent}$reset');
      }
    }
  }
}