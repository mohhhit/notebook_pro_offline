import 'dart:typed_data';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmbeddingService {
  static EmbeddingService? instance;
  Interpreter? _interpreter;
  final int maxSeqLength = 256;
  final int embeddingDim = 384;

  static Future<void> init(String modelPath) async {
    instance = EmbeddingService();
    await instance!._initializeFromFile(modelPath);
  }

  Future<void> _initializeFromFile(String path) async {
    try {
      _interpreter = await Interpreter.fromFile(File(path));
      print('TFLite model loaded successfully from file.');
    } catch (e) {
      print('Error loading TFLite model from file: $e');
    }
  }


  /// Generates a 384-dimensional vector for a given text chunk
  List<double> generateEmbedding(String text) {
    if (_interpreter == null) {
      throw Exception("Interpreter not initialized");
    }

    // 1. Tokenization (Placeholder)
    // NOTE: all-MiniLM-L6-v2 requires a WordPiece tokenizer and a vocab.txt file.
    // For this offline RAG POC, we simulate the tokenization output. 
    // You would replace this with a real WordPiece Dart implementation.
    List<int> inputIds = _mockWordPieceTokenizer(text);
    List<int> attentionMask = List.filled(maxSeqLength, 0);
    List<int> typeIds = List.filled(maxSeqLength, 0);

    for (int i = 0; i < inputIds.length; i++) {
      attentionMask[i] = 1;
    }

    // 2. Prepare Inputs
    // TFLite expects inputs as lists of lists (tensors)
    var input0 = [inputIds];
    var input1 = [attentionMask];
    var input2 = [typeIds];

    // Assuming the model takes input_ids, attention_mask, token_type_ids
    // The exact order depends on how the .tflite model was exported.
    Map<int, Object> inputs = {
      0: input0,
      1: input1,
      2: input2,
    };

    // 3. Prepare Output Tensor
    // Output shape for MiniLM before pooling is usually [1, seqLength, 384]
    var output = List.generate(
        1, 
        (i) => List.generate(maxSeqLength, (j) => List.filled(embeddingDim, 0.0))
    );

    Map<int, Object> outputs = {
      0: output,
    };

    // 4. Run Inference on-device
    _interpreter!.runForMultipleInputs(inputs.values.toList(), outputs);

    // 5. Mean Pooling
    // The model outputs embeddings for every token. We mean-pool them to get 
    // a single 384-dimensional vector representing the entire sentence/chunk.
    return _meanPooling(output[0], attentionMask);
  }

  List<int> _mockWordPieceTokenizer(String text) {
    // A dummy tokenizer. In production, load vocab.txt and use a WordPiece algorithm.
    // We truncate to maxSeqLength - 2 to leave room for [CLS] and [SEP] tokens.
    final words = text.split(' ').take(maxSeqLength - 2).toList();
    List<int> tokens = List.filled(maxSeqLength, 0); // 0 is usually [PAD]
    
    tokens[0] = 101; // [CLS] token id in BERT
    for (int i = 0; i < words.length; i++) {
      tokens[i + 1] = words[i].hashCode % 30000; // Mock ID mapped to vocab size
    }
    tokens[words.length + 1] = 102; // [SEP] token id
    
    return tokens;
  }

  List<double> _meanPooling(List<List<double>> tokenEmbeddings, List<int> attentionMask) {
    List<double> sentenceEmbedding = List.filled(embeddingDim, 0.0);
    int validTokens = 0;

    for (int i = 0; i < maxSeqLength; i++) {
      if (attentionMask[i] == 1) {
        validTokens++;
        for (int j = 0; j < embeddingDim; j++) {
          sentenceEmbedding[j] += tokenEmbeddings[i][j];
        }
      }
    }

    if (validTokens > 0) {
      for (int j = 0; j < embeddingDim; j++) {
        sentenceEmbedding[j] /= validTokens;
      }
    }

    return sentenceEmbedding;
  }

  void dispose() {
    _interpreter?.close();
  }
}
