import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart';
import '../models/document_chunk.dart';
import 'embedding_service.dart';

class ProcessDocumentArgs {
  final String filePath;
  final String documentId;
  final String documentName;
  final ByteData storeReference;
  final RootIsolateToken isolateToken;
  final String modelPath;
  
  ProcessDocumentArgs({
    required this.filePath,
    required this.documentId,
    required this.documentName,
    required this.storeReference,
    required this.isolateToken,
    required this.modelPath,
  });
}

class DocumentProcessor {
  static const int wordsPerChunk = 500;
  static const int wordOverlap = 50;

  static Future<int> processDocument(ProcessDocumentArgs args) async {
    return await Isolate.run(() => _processInIsolate(args));
  }

  static Future<int> _processInIsolate(ProcessDocumentArgs args) async {
    // 1. Initialize Flutter bindings for background isolate (needed for assets)
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.isolateToken);

    // 2. Re-attach to ObjectBox
    final store = Store.fromReference(getObjectBoxModel(), args.storeReference);
    final box = store.box<DocumentChunk>();

    // 3. Initialize Embedding Service
    await EmbeddingService.init(args.modelPath);
    final embeddingService = EmbeddingService.instance!;

    final file = File(args.filePath);
    if (!file.existsSync()) {
      store.close();
      return 0;
    }

    final bytes = file.readAsBytesSync();
    
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      
      final int pageCount = document.pages.count;
      
      List<String> currentWordsBuffer = [];
      int chunkIndex = 0;
      List<DocumentChunk> batchToSave = [];

      for (int i = 0; i < pageCount; i++) {
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i) ?? '';
        
        final words = pageText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
        currentWordsBuffer.addAll(words);

        while (currentWordsBuffer.length >= wordsPerChunk) {
          final chunkWords = currentWordsBuffer.take(wordsPerChunk).toList();
          final chunkText = chunkWords.join(' ');
          
          // Generate actual embedding using the offline model
          final embedding = embeddingService.generateEmbedding(chunkText);
          
          final chunk = DocumentChunk(
            documentId: args.documentId,
            documentName: args.documentName,
            text: chunkText,
            chunkIndex: chunkIndex,
            embedding: embedding, 
          );
          
          batchToSave.add(chunk);
          chunkIndex++;
          
          currentWordsBuffer.removeRange(0, wordsPerChunk - wordOverlap);

          if (batchToSave.length >= 20) {
            box.putMany(batchToSave);
            batchToSave.clear();
          }
        }
      }
      
      if (currentWordsBuffer.isNotEmpty) {
        final chunkText = currentWordsBuffer.join(' ');
        if (chunkText.trim().isNotEmpty) {
          final embedding = embeddingService.generateEmbedding(chunkText);
          final chunk = DocumentChunk(
            documentId: args.documentId,
            documentName: args.documentName,
            text: chunkText,
            chunkIndex: chunkIndex,
            embedding: embedding,
          );
          batchToSave.add(chunk);
        }
      }

      if (batchToSave.isNotEmpty) {
        box.putMany(batchToSave);
        batchToSave.clear();
      }

      return box.query(DocumentChunk_.documentId.equals(args.documentId)).build().count();
    } catch (e) {
      print('Error parsing PDF in Isolate: $e');
      return 0;
    } finally {
      document?.dispose();
      embeddingService.dispose();
      store.close();
    }
  }
}
      

