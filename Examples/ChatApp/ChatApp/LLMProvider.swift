import Foundation
import MLXLMCommon
import SwiftAI
import SwiftAIMLX

/// LLM Factory.
class LLMProvider {
  /// Model manager for MLX models
  private let modelManager: MlxModelManager

  /// Initialize the provider with a model manager
  init(modelManager: MlxModelManager) {
    self.modelManager = modelManager
  }

  /// Available models
  var availableModels: [ModelID] {
    ModelID.allCases
  }

  /// Creates an LLM instance for the given model
  func getLLM(for model: ModelID) -> any LLM {
    switch model {
    case .afm:
      return SystemLLM()
    case .llama32_1b:
      return modelManager.llm(with: .init(id: "mlx-community/Llama-3.2-1B-Instruct-4bit"))
    case .qwen3_4b:
      return modelManager.llm(with: .init(id: "mlx-community/Qwen3-4B-4bit"))
    }
  }
}

/// Default model manager creation
extension LLMProvider {
  /// Creates an LLMProvider with a default model manager
  /// - Parameter storageDirectory: Directory where models will be stored
  static func create(storageDirectory: URL? = nil) -> LLMProvider {

    #if os(macOS)
    let defaultStorageDir = URL.downloadsDirectory.appending(path: "huggingface")
    #else
    let defaultStorageDir = URL.cachesDirectory.appending(path: "huggingface")
    #endif

    let defaultDirectory = storageDirectory ?? defaultStorageDir

    let modelManager = MlxModelManager(storageDirectory: defaultDirectory)
    return LLMProvider(modelManager: modelManager)
  }
}
