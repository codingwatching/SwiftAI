import Foundation

/// Enum representing supported models.
enum ModelID: String, CaseIterable, Identifiable {
  case afm = "apple-fm"
  case llama32_1b = "llama3.2:1b"
  case qwen3_4b = "qwen3:4b"

  var id: String { rawValue }

  /// Display name for the model
  var displayName: String {
    switch self {
    case .afm:
      return "Apple System LLM"
    case .llama32_1b:
      return "Llama 3.2 1B"
    case .qwen3_4b:
      return "Qwen3 4B"
    }
  }
}
