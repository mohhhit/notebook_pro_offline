import 'package:objectbox/objectbox.dart';

@Entity()
class DocumentChunk {
  @Id()
  int id = 0;

  final String documentId;
  final String documentName;
  final String text;
  final int chunkIndex;
  
  // We use 384 dimensions assuming all-MiniLM-L6-v2 embedding model
  @HnswIndex(dimensions: 384) 
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  DocumentChunk({
    this.id = 0,
    required this.documentId,
    required this.documentName,
    required this.text,
    required this.chunkIndex,
    this.embedding,
  });
}
