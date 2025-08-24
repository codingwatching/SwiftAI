import Foundation
import SwiftAI

/// Configuration for text chunking strategy
struct SummarizationStrategy {
  let chunkSize: Int
  let overlapSize: Int
}

/// Handles AI-powered text summarization
class Summarizer {

  /// Language model dependency for AI operations
  private let llm: any LLM

  init(llm: any LLM) {
    self.llm = llm
  }

  /// Generates a summary for the given text
  ///
  /// - Parameter text: Text content to summarize
  /// - Returns: Summary text
  func summarize(_ text: String, strategy: SummarizationStrategy) async throws -> String {
    // Check if the LLM is available
    guard llm.isAvailable else {
      throw SummarizationError.llmUnavailable
    }

    // Generate summary using chunking strategy
    return try await generateChunkedSummary(text, strategy)
  }

  /// Demonstrates SwiftAI chunking strategy for long content
  ///
  /// SwiftAI Context Window Management:
  /// 1. Split text into overlapping chunks (maintains context)
  /// 2. Process chunks sequentially (clear for learning)
  /// 3. Combine results with another AI call
  private func generateChunkedSummary(_ text: String, _ strategy: SummarizationStrategy)
    async throws -> String
  {
    // Split text into overlapping chunks to maintain context
    let chunks = text.chunked(chunkSize: strategy.chunkSize, overlapSize: strategy.overlapSize)

    // Summarize each chunk individually
    var chunkSummaries: [String] = []
    for chunk in chunks {
      let chunkSummary = try await summarizeChunk(chunk)
      chunkSummaries.append(chunkSummary)
    }

    // If there's only one chunk, return the summary directly
    if chunkSummaries.count == 1 {
      return chunkSummaries[0]
    }

    // Combine all chunk summaries into one final summary
    let combinedSummaries = chunkSummaries.joined(separator: "\n\n")
    let finalPrompt = """
      Combine the following section summaries into a single, coherent overview in at most 3 sentences.

      Section summaries:
      \(combinedSummaries)
      """

    let response = try await llm.reply(to: finalPrompt)
    return response.content
  }

  /// Generates a summary for content that fits within context limits
  private func summarizeChunk(_ text: String) async throws -> String {
    let prompt = """
      Analyze the following text and provide a concise summary of the main points in at most 3 sentences.

      Note: You may receive text that begins or ends with incomplete sentences due to chunking - please ignore any incomplete sentences and focus on the complete thoughts.

      Text to summarize:
      ------------------
      \(text)
      """

    let response = try await llm.reply(to: prompt)
    return response.content
  }
}

/// Errors that can occur during summarization
enum SummarizationError: Error, LocalizedError {
  case llmUnavailable

  var errorDescription: String? {
    switch self {
    case .llmUnavailable:
      return "AI summarization is not available on this device."
    }
  }
}
