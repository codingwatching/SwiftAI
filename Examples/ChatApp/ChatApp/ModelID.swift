import Foundation

/// Enum representing supported models.
enum ModelID: String, CaseIterable, Identifiable {
  case afm = "apple-fm"

  // Tiny models (< 1B parameters)
  case smolLM_135M = "smollm-135m"
  case openelm270m = "openelm-270m"
  case phi3_5_4bit = "phi-3.5-4bit"  // ~0.6B
  case qwen3_0_6b = "qwen3-0.6b"

  // Small models (1B - 3B parameters)
  case gemma3_1B_qat = "gemma3-1b-qat"
  case llama3_2_1B = "llama3.2-1b"
  case qwen3_1_7b = "qwen3-1.7b"
  case gemma3n_E2B_bf16 = "gemma3n-e2b-bf16"
  case gemma3n_E2B_4bit = "gemma3n-e2b-4bit"
  case llama3_2_3B = "llama3.2-3b"
  case smollm3_3b = "smollm3-3b"

  // Medium models (3B+ - 8B parameters)
  case gemma3n_E4B_bf16 = "gemma3n-e4b-bf16"
  case gemma3n_E4B_4bit = "gemma3n-e4b-4bit"
  case qwen3_4b = "qwen3-4b"
  case mistral_7b = "mistral-7b"
  case deepseek_r1_7b = "deepseek-r1-7b"
  case mistralNeMo4bit = "mistral-nemo-4bit" // ~7B
  case qwen3_8b = "qwen3-8b"

  // Large models (8B+ parameters)
  case llama3_1_8B = "llama3.1-8b"
  case llama3_8B = "llama3-8b"

  var id: String { rawValue }

  /// Display name for the model
  var displayName: String {
    switch self {
    case .afm:
      return "Apple System LLM"

    case .smolLM_135M:
      return "SmolLM 135M"
    case .qwen3_0_6b:
      return "Qwen3 0.6B"
    case .qwen3_1_7b:
      return "Qwen3 1.7B"
    case .openelm270m:
      return "OpenELM 270M"
    case .gemma3_1B_qat:
      return "Gemma 3 1B QAT"
    case .gemma3n_E2B_bf16:
      return "Gemma 3n E2B (BF16)"
    case .gemma3n_E2B_4bit:
      return "Gemma 3n E2B (4bit)"
    case .llama3_2_1B:
      return "Llama 3.2 1B"
    case .smollm3_3b:
      return "SmolLM3 3B"
    case .llama3_2_3B:
      return "Llama 3.2 3B"
    case .qwen3_4b:
      return "Qwen3 4B"
    case .qwen3_8b:
      return "Qwen3 8B"
    case .gemma3n_E4B_bf16:
      return "Gemma 3n E4B (BF16)"
    case .gemma3n_E4B_4bit:
      return "Gemma 3n E4B (4bit)"
    case .mistral_7b:
      return "Mistral 7B"
    case .deepseek_r1_7b:
      return "DeepSeek R1 7B"
    case .phi3_5_4bit:
      return "Phi 3.5 (4bit)"
    case .llama3_1_8B:
      return "Llama 3.1 8B"
    case .llama3_8B:
      return "Llama 3 8B"
    case .mistralNeMo4bit:
      return "Mistral NeMo (4bit)"
    }
  }
}
