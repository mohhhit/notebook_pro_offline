# NotebookPRO (Partially Online Mode)

## Overview
NotebookPRO is a Flutter-based Android application designed for intelligent document processing and question-answering. Users can upload PDF documents, which the app processes into vector embeddings and stores locally on the device. Users can then ask questions, and the app will retrieve relevant document chunks to generate accurate, context-aware answers.

Originally built with a Python backend using `sentence_transformers` and `ChromaDB`, and later adapted to a "Fully Offline" mode using local TFLite models, the project is currently in its **Partially Online Mode**. 

## Architecture & Core Technologies
*   **Framework**: Flutter (Dart)
*   **Local Database / Vector Store**: ObjectBox (used for blazing-fast local chunk storage and vector similarity search with `@HnswIndex(dimensions: 384)`).
*   **Document Embedding API**: Google Gemini API (`gemini-embedding-2`).
*   **Answer Generation API**: Google Gemini API (`gemini-2.5-flash:streamGenerateContent`).
*   **Follow-up Question Generation API**: Groq API (`llama3-8b-8192`).
*   **Background Processing**: Dart Isolates (`Isolate.run`) to ensure heavy PDF parsing and API communication do not freeze the main UI thread.

## Recent Changes & Key Implementations
This section details the critical transitions made to achieve the "Partially Online Mode".

### 1. Online Embeddings & Deprecation Fixes
*   **Removed Local TFLite**: Completely removed the heavy 22MB local TFLite embedding model from the app bundle/startup flow to reduce app size and initialization time.
*   **Model Migration**: Initially attempted to use `text-embedding-004`, but encountered `404 NOT_FOUND` errors due to model deprecation/shutdown. Successfully migrated to the active `gemini-embedding-2` model, which maintains the required 384 output dimensionality required by the existing ObjectBox schema.

### 2. Rate Limit Resilience & Batching
*   **Batch Embedding**: Replaced sequential, chunk-by-chunk embedding generation with the highly efficient `batchEmbedContents` API. The app now sends chunks in batches of 50 to drastically reduce the Requests Per Minute (RPM).
*   **Heavy Throttling**: Added a mandatory 4-second delay between successful batch requests to prevent spiking the API limits.
*   **Exponential Backoff**: Implemented a robust exponential backoff retry mechanism (starting at 15s, increasing by 15s up to 10 retries) to gracefully handle `429 RESOURCE_EXHAUSTED` (Rate Limit) errors. This ensures large documents process securely in the background without crashing.

### 3. API Key Management
*   The application dynamically reads user-provided `geminiApiKey` and `groqApiKey` from `SharedPreferences`.
*   Includes proactive validation (e.g., preventing document uploads if the Gemini API key is missing) to ensure a smooth user experience.

### 4. Background Isolate Processing
*   The entire pipeline of reading the PDF, extracting text (using `syncfusion_flutter_pdf`), chunking (500 words per chunk with a 50-word overlap), requesting batch embeddings via HTTP, and writing to ObjectBox is executed seamlessly inside a detached Dart Isolate in `document_processor.dart`.

## Instructions for AI Agents
If you are an AI assistant opening this project for the first time:
1.  **Do NOT modify the ObjectBox schema dimensionality**: The vector index is strictly set to `@HnswIndex(dimensions: 384)`. Ensure any future embedding models continue to output exactly 384 dimensions.
2.  **Respect Throttling**: The background isolate in `document_processor.dart` handles heavy API communication. Do not remove the `Future.delayed` throttling or the exponential backoff, as free-tier API accounts will immediately hit rate limits without them.
3.  **Local Storage Priority**: Remember that while APIs are used for inference (Embeddings/LLM), **storage is strictly local** using ObjectBox to respect user privacy and offline capabilities.
