# ReadMitAI: SwiftAI Educational Demo

> **Learn SwiftAI through a practical essay reading app that demonstrates structured AI output, text chunking.**

Read _mit_ (_with_ in German) me. Is a sample demo app where you can read Paul Graham's essay. Each essay has an AI overview.

## 🎯 What You'll Learn

This demo teaches essential **SwiftAI** patterns:

- **Structured AI Output** with `@Generable` and `@Guide`
- **Text Chunking** strategies for long content
- **LLM Abstraction** with dependency injection

---

## 📁 Codebase Structure

```text
ReadMitAI/
├── Essays/
│   ├── Services/
│   │   ├── Essay.swift              # Basic model
│   │   └── EssayService.swift       # Web scraping
│   ├── EssayFeed/                   # UI Layer
│   │   ├── EssayFeedView.swift
│   │   ├── EssaysViewModel.swift
│   │   └── EssayRowView.swift
│   └── EssayPage/
│       ├── EssayDetailView.swift          # UI (skip for SwiftAI learning)
│       ├── ⭐ EssayDetailViewModel.swift  # SwiftAI coordination
│       ├── Summarization/
│       │   └── ⭐ Summarizer.swift        # Core chunking + AI patterns
│       └── 📁 MetadataGeneration/
│           ├── ⭐ EssayMetadata.swift     # @Generable example
│           └── ⭐ MetadataGenerator.swift # Structured output
└── 📁 Utils/
    └── Chunking.swift                     # Text processing strategy
```

---

## 🔥 Key SwiftAI Concepts

### 1. Structured AI Output - Type-Safe Responses

AI typically returns unstructured text, requiring manual parsing and validation.

SwiftAI's `@Generable` macro creates type-safe structured responses that are automatically validated.

```swift
@Generable
struct EssayMetadata {
  @Guide(description: "Main topic or theme of the essay")
  let topic: String

  @Guide(description: "Reading difficulty level", .anyOf(["Beginner", "Intermediate", "Advanced"]))
  let difficulty: String

  @Guide(description: "Main themes discussed in the essay", .minimumCount(1), .maximumCount(3))
  let keyThemes: [String]
}
```

The `@Guide` macro provides semantic descriptions and validation rules that guide the AI to generate compliant responses. SwiftAI automatically converts AI output into your Swift struct, ensuring type safety at compile time.

### 2. Text Chunking Strategy - Context Window Management

Apple's on-device LLM has a 4,096 token context window. Paul Graham essays often exceed 10,000+ tokens, causing processing failures.

Implement overlapping text chunks with a hierarchical summarization algorithm.

**Algorithm**:

```txt
Input: Long text (>4096 tokens)
Strategy: ChunkSize=8000, OverlapSize=500

1. Split text into overlapping chunks:
   - Chunk 1: Characters 0-8000
   - Chunk 2: Characters 7500-12500 (500 char overlap)
   - ...

2. For each chunk:
   - Generate individual summary (fits in context window)
   - Collect all chunk summaries

3. Hierarchical combination:
   - Combine all chunk summaries into single text
   - Generate final summary from combined summaries
   - Return coherent overview of entire document
```

The 500-character overlap preserves context across chunk boundaries, preventing loss of meaning when sentences are split mid-thought.

### 3. LLM Abstraction

SwiftAI represents all language models using a single API called `LLM`. This makes it easy to swap implementations in production and tests without changing your business logic.

For example you can switch to OpenAI API by changing:

```swift
let llm = SystemLLM()
```

to

```swift
let llm = OpenaiLLM(model="...", apiKey: "...")
```
