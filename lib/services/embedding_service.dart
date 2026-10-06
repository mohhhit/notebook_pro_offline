import 'dart:convert';
import 'package:http/http.dart' as http;

class EmbeddingService {
  static EmbeddingService? instance;
  final String apiKey;
  final int embeddingDim = 384;

  EmbeddingService._(this.apiKey);

  static Future<void> init(String? modelPath, {String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Gemini API key is required for embeddings");
    }
    instance = EmbeddingService._(apiKey);
    print('Gemini Embedding API initialized.');
  }

  /// Generates a 384-dimensional vector for a given text chunk using Gemini
  Future<List<double>> generateEmbedding(String text) async {
    final embeddings = await generateEmbeddings([text]);
    return embeddings.first;
  }

  /// Generates 384-dimensional vectors for a list of text chunks using Gemini
  Future<List<List<double>>> generateEmbeddings(List<String> texts) async {
    if (texts.isEmpty) return [];

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:batchEmbedContents?key=$apiKey');
    
    final requests = texts.map((text) => {
      "model": "models/gemini-embedding-2",
      "content": {
        "parts": [
          {"text": text}
        ]
      },
      "outputDimensionality": embeddingDim
    }).toList();

    int maxRetries = 10;
    int retryCount = 0;
    int delayMs = 15000; // Start with a 15-second wait on 429

    while (retryCount < maxRetries) {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "requests": requests
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> embeddingsData = data['embeddings'];
        return embeddingsData.map((e) {
          final List<dynamic> values = e['values'];
          return values.cast<double>();
        }).toList();
      } else if (response.statusCode == 429) {
        retryCount++;
        print('Rate limit hit (429). Waiting ${delayMs / 1000} seconds before retry $retryCount...');
        if (retryCount >= maxRetries) {
          throw Exception('Rate limit exceeded after heavy retries: ${response.body}');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs += 15000; // Increase wait by 15s each time (15s, 30s, 45s...)
      } else {
        throw Exception('Failed to generate embeddings: ${response.statusCode} - ${response.body}');
      }
    }
    throw Exception('Failed to generate embeddings');
  }

  void dispose() {
    // No local resources to dispose
  }
}
