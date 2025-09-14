import Foundation
import MLXLLM
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

    // Tiny models
    case .smolLM_135M:
      return modelManager.llm(with: LLMRegistry.smolLM_135M_4bit)
    case .qwen3_0_6b:
      return modelManager.llm(with: LLMRegistry.qwen3_0_6b_4bit)
    case .qwen3_1_7b:
      return modelManager.llm(with: LLMRegistry.qwen3_1_7b_4bit)
    case .openelm270m:
      return modelManager.llm(with: LLMRegistry.openelm270m4bit)
    case .gemma3_1B_qat:
      return modelManager.llm(with: LLMRegistry.gemma3_1B_qat_4bit)
    case .gemma3n_E2B_bf16:
      return modelManager.llm(with: LLMRegistry.gemma3n_E2B_it_lm_bf16)
    case .gemma3n_E2B_4bit:
      return modelManager.llm(with: LLMRegistry.gemma3n_E2B_it_lm_4bit)
    case .llama3_2_1B:
      return modelManager.llm(with: LLMRegistry.llama3_2_1B_4bit)
    case .smollm3_3b:
      return modelManager.llm(with: LLMRegistry.smollm3_3b_4bit)
    case .llama3_2_3B:
      return modelManager.llm(with: LLMRegistry.llama3_2_3B_4bit)
    case .qwen3_4b:
      return modelManager.llm(with: LLMRegistry.qwen3_4b_4bit)
    case .qwen3_8b:
      return modelManager.llm(with: LLMRegistry.qwen3_8b_4bit)
    case .gemma3n_E4B_bf16:
      return modelManager.llm(with: LLMRegistry.gemma3n_E4B_it_lm_bf16)
    case .gemma3n_E4B_4bit:
      return modelManager.llm(with: LLMRegistry.gemma3n_E4B_it_lm_4bit)
    case .mistral_7b:
      return modelManager.llm(with: LLMRegistry.mistral7B4bit)
    case .deepseek_r1_7b:
      return modelManager.llm(with: LLMRegistry.deepSeekR1_7B_4bit)
    case .phi3_5_4bit:
      return modelManager.llm(with: LLMRegistry.phi3_5_4bit)
    case .llama3_1_8B:
      return modelManager.llm(with: LLMRegistry.llama3_1_8B_4bit)
    case .llama3_8B:
      return modelManager.llm(with: LLMRegistry.llama3_8B_4bit)
    case .mistralNeMo4bit:
      return modelManager.llm(with: LLMRegistry.mistralNeMo4bit)
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
