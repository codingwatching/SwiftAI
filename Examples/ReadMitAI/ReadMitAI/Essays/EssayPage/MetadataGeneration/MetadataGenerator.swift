import Foundation
import SwiftAI

/// Handles AI-powered essay metadata generation
class MetadataGenerator {

  /// Language model dependency for AI operations
  private let llm: any LLM

  /// For educational purposes, we avoid complicating the code with
  /// context window management and use a simple approach.
  let maxContentLengthToAnalyze = 6000

  init(llm: any LLM) {
    self.llm = llm
  }

  /// Generates structured metadata for the given text
  /// - Parameter text: Text content to analyze
  /// - Returns: EssayMetadata with structured information
  func generateMetadata(for text: String) async throws -> EssayMetadata {
    // Check if the LLM is available
    guard llm.isAvailable else {
      throw MetadataGenerationError.llmUnavailable
    }

    // For long content, use just the first part to avoid context limits
    let excerpt =
      text.count > maxContentLengthToAnalyze ? String(text.prefix(maxContentLengthToAnalyze)) : text

    // SwiftAI's structured output: returns EssayMetadata directly
    let response = try await llm.reply(returning: EssayMetadata.self) {
      """
      Analyze the following essay excerpt and extract metadata about it.

      Essay excerpt:
      ---------------
      \(excerpt)
      """
    }
    return response.content
  }
}

/// Errors that can occur during metadata generation
enum MetadataGenerationError: Error, LocalizedError {
  case llmUnavailable

  var errorDescription: String? {
    switch self {
    case .llmUnavailable:
      return "AI metadata generation is not available on this device."
    }
  }
}
