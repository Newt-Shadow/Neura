import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/advanced_logger.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  // Filter state
  Set<LogType> _filters = LogType.values.toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // GitHub Dark Dimmed
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text("Neuro Neural Link", style: TextStyle(color: Colors.greenAccent, fontFamily: 'Courier')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => AdvancedLogger().clearLogs(),
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<List<LogEntry>>(
              stream: AdvancedLogger().logsStream,
              initialData: AdvancedLogger().history,
              builder: (context, snapshot) {
                final logs = snapshot.data?.where((l) => _filters.contains(l.type)).toList() ?? [];
                
                if (logs.isEmpty) {
                  return const Center(
                    child: Text("No signals detected.", style: TextStyle(color: Colors.white24)),
                  );
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _LogTile(entry: logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: LogType.values.map((type) {
          final isSelected = _filters.contains(type);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(type.name.toUpperCase()),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  val ? _filters.add(type) : _filters.remove(type);
                });
              },
              backgroundColor: const Color(0xFF21262D),
              selectedColor: _getColor(type).withOpacity(0.3),
              labelStyle: TextStyle(
                color: isSelected ? _getColor(type) : const Color.fromARGB(255, 126, 218, 241),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              checkmarkColor: _getColor(type),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getColor(LogType type) {
    switch (type) {
      case LogType.api: return Colors.cyanAccent;
      case LogType.llm: return Colors.greenAccent;
      case LogType.error: return Colors.redAccent;
      case LogType.user: return Colors.purpleAccent;
      default: return const Color.fromARGB(255, 48, 48, 48);
    }
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    Color color = _getColor(entry.type);
    
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Text(
          "${entry.timestamp.hour}:${entry.timestamp.minute}:${entry.timestamp.second}.${entry.timestamp.millisecond}",
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Courier'),
        ),
        title: Text(entry.title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(entry.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        children: [
          if (entry.jsonContent != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF0D1117),
              child: SelectableText(
                _prettyJson(entry.jsonContent),
                style: const TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 11),
              ),
            ),
          if (entry.jsonContent != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text("Copy JSON"),
              onPressed: () => Clipboard.setData(ClipboardData(text: _prettyJson(entry.jsonContent))),
            )
        ],
      ),
    );
  }

  Color _getColor(LogType type) {
    switch (type) {
      case LogType.api: return Colors.cyanAccent;
      case LogType.llm: return Colors.greenAccent;
      case LogType.error: return Colors.redAccent;
      case LogType.user: return Colors.purpleAccent;
      default: return Colors.white;
    }
  }

  String _prettyJson(dynamic json) {
    try {
      var encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}