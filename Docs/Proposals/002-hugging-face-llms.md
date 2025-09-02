# Hugging Face LLMs

- Proposal: [SAI-002](https://github.com/mi12labs/SwiftAI/blob/main/Docs/Proposals/002-hugging-face.md)
- Status: **WIP**
- Implementation:

## Introduction

## API

### Core API

```swift
struct MlxLLM: LLM {
  typealias Session = MlxSession

  init(configuration: ModelConfiguration)

  var loadingState: LoadingState { get }

  // Other fields and method omitted.
}
```

where `ModelConfiguration` is from `MLXLMCommon`.

Model loading and sharing is managed by a central entity.

```swift
class MlxModelManager: Sendable {
  private let modelCache = NSCache<NSString, ModelContainer>()

  private var activeLoadingTasks: [ModelConfiguration: Task<ModelContainer, Error>] = [:]

  func getOrLoadModel(
    forConfiguration configuration: ModelConfiguration
  ) async throws -> ModelContainer

  func areModelFilesAvailableLocally(configuration: ModelConfiguration) -> Bool
}
```

```swift
public enum LoadingState {
  case pending
  case downloading(progress: Double)
  case loading
  case ready
  case failed(Error)
}
```

#### Key Design Decisions

- **Non-blocking init**: Creates instance immediately, loads model lazily
- **Shared model weights**: Multiple `MlxLLM` instances with identical `ModelConfiguration`
  share the same `ModelContext` via weak references Automatic memory management: Models
  deallocated when no active MlxLLM instances reference them

### Model Preparation

```swift
public extension MlxLLM {
  // Downloads model files if not already cached.
  // Calling `prepare` when a model is being dowloaded is a no op.
  // In case a of a previous failure, `prepare` will retry the preparation.
  static func prepare(
    configuration: ModelConfiguration,
    onProgress: @escaping (Double) -> Void,
    onError: @escaping (Error) -> Void
  ) async
}
```

### Storage Management

```swift
public extension MlxLLM {
  // Check if model files exist on disk
  static func isDownloaded(configuration: ModelConfiguration) -> Bool

  // Remove downloaded model files.
  // No op if it doesn't exist.
  static func removeFromDisk(configuration: ModelConfiguration) throws

  // List all downloaded models on disk
  static func downloadedModels() -> [ModelConfiguration]

  static func diskUsage(for configuration: ModelConfiguration) -> Int64?
}
```

### Session

```swift
actor MlxSession {
  private var kvCache: [MLXLMCommon.KVCache]
  private var unprocessedMessages: [Message]
}
```

- [ ] When to setup GPU memory limit?
