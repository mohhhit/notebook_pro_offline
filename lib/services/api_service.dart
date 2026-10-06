import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'objectbox_service.dart';
import 'embedding_service.dart';

class ApiService {
  // Default backend URL (can be changed in settings)
  static String _baseUrl = 'http://localhost:8011';

  // Initialize baseUrl from storage
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('backend_url') ?? 'http://localhost:8011';
  }

  // Get current backend URL
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url') ?? _baseUrl;
  }

  // Set backend URL
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
    _baseUrl = url;
  }

  // Get base URL synchronously (uses cached value)
  static String get baseUrl => _baseUrl;

  static bool _isLocalTunnelUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'loca.lt' || host.endsWith('.loca.lt');
  }

  static Map<String, String> buildHeaders({
    String? baseUrl,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (extra != null) {
      headers.addAll(extra);
    }

    final effectiveBaseUrl = baseUrl ?? _baseUrl;
    if (_isLocalTunnelUrl(effectiveBaseUrl)) {
      // Bypasses LocalTunnel's anti-phishing interstitial for API requests.
      headers['bypass-tunnel-reminder'] = 'true';
    }

    return headers;
  }

  static String formatHttpError({
    required String operation,
    required http.Response response,
  }) {
    final body = response.body;

    if (response.statusCode == 511 ||
        body.contains('Tunnel website ahead') ||
        body.contains('bypass-tunnel-reminder')) {
      return '$operation failed: LocalTunnel blocked this API request (HTTP 511). '
          'Use your .loca.lt URL and retry. If the issue persists, restart the app so new headers are applied.';
    }

    if (body.contains('<html') || body.contains('<!DOCTYPE html')) {
      return '$operation failed: server returned HTML instead of JSON (HTTP ${response.statusCode}). '
          'Check backend URL and tunnel state.';
    }

    if (body.length > 600) {
      return '$operation failed with HTTP ${response.statusCode}. '
          'Server response was too long to display.';
    }

    return '$operation failed (HTTP ${response.statusCode}): $body';
  }

  // Test connection to backend
  static Future<bool> testConnection(String url) async {
    return true; // Always true for fully offline mode
  }

  // ==================== Spaces ====================

  Future<List<Space>> getSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = prefs.getString('offline_spaces') ?? '[]';
    List<dynamic> data = json.decode(spacesJson);
    return data.map((j) => Space.fromJson(j)).toList();
  }

  Future<Space> createSpace(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = prefs.getString('offline_spaces') ?? '[]';
    List<dynamic> data = json.decode(spacesJson);
    
    final newSpace = {
      'id': 'space_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'file_count': 0,
    };
    
    data.add(newSpace);
    await prefs.setString('offline_spaces', json.encode(data));
    
    return Space.fromJson(newSpace);
  }

  Future<void> deleteSpace(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final spacesJson = prefs.getString('offline_spaces') ?? '[]';
    List<dynamic> data = json.decode(spacesJson);
    
    data.removeWhere((s) => s['id'] == spaceId);
    await prefs.setString('offline_spaces', json.encode(data));
  }

  // ==================== Chats ====================

  Future<List<ChatInfo>> getChats(String spaceId) async {
    return []; // Return empty list for local POC
  }

  Future<Chat> getChat(String spaceId, String chatId) async {
    return Chat(
      id: chatId,
      messages: [],
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  // Backend data management
  Future<List<int>> exportData() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/system/export'));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to export data: ${response.statusCode}');
    }
  }

  Future<void> importData(String filePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/system/import'));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to import data: ${response.body}');
    }
  }

  Future<void> importDataBytes(List<int> bytes, String filename) async {
  }

  Future<void> deleteChat(String spaceId, String chatId) async {
  }

  Future<void> deleteChatMessage({
    required String spaceId,
    required String chatId,
    required String timestamp,
    required String role,
    String? content,
    bool deleteRelatedUser = false,
  }) async {
  }

  // ==================== Chat/RAG ====================

  Future<ChatResponse> sendMessage({
    required String query,
    required String spaceId,
    String? chatId,
    String workflow = 'chat',
  }) async {
    return ChatResponse(
      response: 'Local response not implemented.',
      sources: [],
      chatId: chatId ?? 'chat_1',
      timestamp: DateTime.now().toIso8601String(),
      suggestedFollowUps: [],
    );
  }

  Stream<ChatStreamEvent> sendMessageStream({
    required String query,
    required String spaceId,
    String? chatId,
    String workflow = 'chat',
  }) async* {
    yield ChatStreamEvent(
      event: 'message',
      data: {'content': '\n\n**?? Searching Documents...**\n'},
    );

    // Get API Keys
    final config = await getConfig();
    final geminiKey = config['gemini_api_key'];
    final groqKey = config['groq_api_key'];

    if (geminiKey == null || geminiKey.isEmpty) {
      yield ChatStreamEvent(
        event: 'message',
        data: {'content': 'Error: Gemini API key is missing. Please add it in settings.', 'isComplete': true},
      );
      return;
    }

    // 1. Generate query embedding using Gemini
    await EmbeddingService.init(null, apiKey: geminiKey);
    final embedding = await EmbeddingService.instance!.generateEmbedding(query);

    // 2. Search ObjectBox
    final chunks = ObjectBoxService.instance!.searchChunks(embedding, limit: 3);
    
    String contextText = chunks.map((c) => c.text).join('\n\n---\n\n');
    String prompt = '''You are a helpful assistant answering questions based on the provided context.
If the answer is not in the context, say so.
Context:
$contextText

Question: $query
Answer:''';

    yield ChatStreamEvent(
      event: 'message',
      data: {'content': '?? Generating answer...\n\n'},
    );

    // 3. Call Gemini to stream the answer
    final geminiUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=$geminiKey');
    
    final request = http.Request('POST', geminiUrl)
      ..headers.addAll({'Content-Type': 'application/json'})
      ..body = json.encode({
        "contents": [{"parts": [{"text": prompt}]}]
      });

    final response = await http.Client().send(request);
    
    if (response.statusCode != 200) {
      final errorBytes = await response.stream.toBytes();
      final errorText = utf8.decode(errorBytes);
      yield ChatStreamEvent(
        event: 'message',
        data: {'content': 'Error from Gemini: $errorText', 'isComplete': true},
      );
      return;
    }

    StringBuffer fullAnswer = StringBuffer();
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final matches = RegExp(r'"text":\s*"([^"\\]*(?:\\.[^"\\]*)*)"').allMatches(chunk);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          String textChunk = match.group(1)!;
          textChunk = textChunk.replaceAll(r'\n', '\n').replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
          fullAnswer.write(textChunk);
          yield ChatStreamEvent(
            event: 'message',
            data: {'content': textChunk},
          );
        }
      }
    }
    
    yield ChatStreamEvent(
      event: 'message',
      data: {'content': '', 'isComplete': true},
    );

    // 4. Generate Follow-ups using Groq
    if (groqKey != null && groqKey.isNotEmpty) {
      try {
        final groqUrl = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
        final groqResponse = await http.post(
          groqUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $groqKey'
          },
          body: json.encode({
            "model": "llama3-8b-8192",
            "messages": [
              {"role": "system", "content": "Generate exactly 3 short follow-up questions for the user based on their query and the answer. Return them as a JSON array of strings."},
              {"role": "user", "content": "Query: $query\nAnswer: ${fullAnswer.toString()}"}
            ],
            "response_format": {"type": "json_object"}
          }),
        );

        if (groqResponse.statusCode == 200) {
          final data = json.decode(groqResponse.body);
          final content = json.decode(data['choices'][0]['message']['content']);
          List<dynamic> questions;
          if (content is List) {
            questions = content;
          } else if (content.containsKey('questions')) {
            questions = content['questions'];
          } else {
            questions = content.values.first;
          }
          
          yield ChatStreamEvent(
            event: 'followup',
            data: {'questions': questions.map((q) => q.toString()).toList()},
          );
        }
      } catch (e) {
        print('Groq follow-up error: $e');
      }
    }
  }

  // ==================== File Upload ====================

  Future<Map<String, dynamic>> uploadFiles(
    String spaceId,
    List<PlatformFile> files,
  ) async {
    final url = await ApiService.getBaseUrl();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$url/api/spaces/$spaceId/upload'),
    );
    request.headers.addAll(ApiService.buildHeaders(baseUrl: url));

    for (var file in files) {
      if (kIsWeb) {
        final fileBytes = await file.readAsBytes();
        if (fileBytes.isEmpty) {
          throw Exception('Selected file is empty: ${file.name}');
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            fileBytes,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        // Desktop/Mobile: use path
        request.files.add(
          await http.MultipartFile.fromPath('files', file.path!),
        );
      } else {
        throw Exception('File has no path: ${file.name}');
      }
    }

    var streamedResponse = await request.send().timeout(
      const Duration(minutes: 45),
      onTimeout: () {
        throw Exception(
          'Upload timed out while waiting for backend processing.',
        );
      },
    );
    var response = await http.Response.fromStream(streamedResponse).timeout(
      const Duration(minutes: 45),
      onTimeout: () {
        throw Exception('Backend took too long to return upload response.');
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        ApiService.formatHttpError(
          operation: 'Failed to upload files',
          response: response,
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUploadedFiles(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final filesJson = prefs.getString('offline_files_$spaceId') ?? '[]';
    List<dynamic> data = json.decode(filesJson);
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> deleteFile(String spaceId, String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final filesJson = prefs.getString('offline_files_$spaceId') ?? '[]';
    List<dynamic> data = json.decode(filesJson);
    
    data.removeWhere((f) => f['filename'] == filename);
    await prefs.setString('offline_files_$spaceId', json.encode(data));
  }

  // ==================== Config ====================

  Future<Map<String, String?>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'groq_api_key': prefs.getString('groq_api_key'),
      'gemini_api_key': prefs.getString('gemini_api_key'),
      'nvidia_api_key': prefs.getString('nvidia_api_key'),
    };
  }

  Future<void> updateConfig({
    String? groqKey,
    String? geminiKey,
    String? nvidiaKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (groqKey != null) await prefs.setString('groq_api_key', groqKey);
    if (geminiKey != null) await prefs.setString('gemini_api_key', geminiKey);
    if (nvidiaKey != null) await prefs.setString('nvidia_api_key', nvidiaKey);
  }
}

// ==================== Models ====================

class Space {
  final String id;
  final String name;
  final String createdAt;
  final int fileCount;

  Space({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.fileCount,
  });

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'],
      name: json['name'],
      createdAt: json['created_at'],
      fileCount: json['file_count'],
    );
  }
}

class ChatInfo {
  final String id;
  final String title;
  final String preview;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  ChatInfo({
    required this.id,
    required this.title,
    required this.preview,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ChatInfo.fromJson(Map<String, dynamic> json) {
    return ChatInfo(
      id: json['id'],
      title: json['title'],
      preview: json['preview'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      messageCount: json['message_count'],
    );
  }
}

class Chat {
  final String id;
  final List<ChatMessage> messages;
  final String createdAt;
  final String updatedAt;

  Chat({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final String timestamp;
  final List<dynamic>? sources;
  final List<String>? suggestedFollowUps;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources,
    this.suggestedFollowUps,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      content: json['content'],
      timestamp: json['timestamp'],
      sources: json['sources'] is List
          ? List<dynamic>.from(json['sources'])
          : null,
      suggestedFollowUps: json['suggested_follow_ups'] is List
          ? List<String>.from(json['suggested_follow_ups'])
          : null,
    );
  }
}

class ChatResponse {
  final String response;
  final List<dynamic> sources;
  final String chatId;
  final String timestamp;
  final String? uiNotice;
  final List<String> suggestedFollowUps;

  ChatResponse({
    required this.response,
    required this.sources,
    required this.chatId,
    required this.timestamp,
    this.uiNotice,
    required this.suggestedFollowUps,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'],
      sources: json['sources'],
      chatId: json['chat_id'],
      timestamp: json['timestamp'],
      uiNotice: json['ui_notice'],
      suggestedFollowUps: json['suggested_follow_ups'] is List
          ? List<String>.from(json['suggested_follow_ups'])
          : <String>[],
    );
  }
}

class ChatStreamEvent {
  final String event;
  final Map<String, dynamic> data;

  ChatStreamEvent({required this.event, required this.data});
}
