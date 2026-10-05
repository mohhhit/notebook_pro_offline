import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';
import '../models/document_chunk.dart';

import 'dart:typed_data';

class ObjectBoxService {
  static ObjectBoxService? instance;
  late final Store store;
  late final Box<DocumentChunk> chunkBox;

  ObjectBoxService._create(this.store) {
    chunkBox = Box<DocumentChunk>(store);
  }

  static Future<ObjectBoxService> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(docsDir.path, "notebook_pro_db"));
    instance = ObjectBoxService._create(store);
    return instance!;
  }

  // Retrieve the raw memory pointer so it can be passed to an Isolate
  ByteData get storeReference => store.reference;

  List<DocumentChunk> searchChunks(List<double> queryEmbedding, {int limit = 5}) {
    // Vector search in ObjectBox using the HnswIndex on the 'embedding' property
    final builder = chunkBox.query(DocumentChunk_.embedding.nearestNeighborsF32(queryEmbedding, limit));
    final query = builder.build();
    final results = query.find();
    query.close();
    return results;
  }
}
