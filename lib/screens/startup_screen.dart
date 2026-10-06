import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/embedding_service.dart';
import '../services/objectbox_service.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String _statusMessage = 'Initializing...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeOfflineBackend();
  }

  Future<void> _initializeOfflineBackend() async {
    try {
      // 1. Initialize ObjectBox
      setState(() => _statusMessage = 'Initializing Database...');
      await ObjectBoxService.create();

      // 2. No local embedding model needed. We use Gemini API.
      setState(() => _statusMessage = 'Initializing...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Transition to Main App
      // Transition to Main App
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
    }
  }

  Future<void> _downloadFile(String url, File targetFile) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      
      final contentLength = response.contentLength ?? 23000000;
      int downloaded = 0;
      int lastUpdate = 0;
      
      final sink = targetFile.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdate > 100 || downloaded == contentLength) {
          lastUpdate = now;
          setState(() {
            _progress = downloaded / contentLength;
          });
        }
      }
      
      await sink.close();
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.downloading, size: 64, color: Color(0xFF8AB4F8)),
              const SizedBox(height: 24),
              const Text(
                'NotebookPRO Offline Prep',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (_progress > 0 && _progress < 1.0)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: const Color(0xFF1E1E1E),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8AB4F8)),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                )
              else
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8AB4F8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
