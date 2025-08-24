import Combine
import Foundation
import SwiftAI

/// ViewModel managing the essay detail screen with SwiftAI integration.
///
/// Uses dependency injection for the LLM to enable testing and flexibility.
@MainActor
class EssayDetailViewModel: ObservableObject {
  /// The essay being displayed
  let essay: Essay

  /// AI-generated summary of the essay.
  @Published var summary: String = ""

  /// AI-generated structured metadata about the essay
  @Published var metadata: EssayMetadata?

  /// Indicates whether content is currently being loaded
  @Published var isLoading = false

  /// Indicates whether summary is currently being generated
  @Published var isGeneratingSummary = false

  /// Error message if content loading fails
  @Published var errorMessage: String?

  /// Service dependency for fetching essay content
  private let essayService = EssayService()

  /// Summarizer for AI operations
  private let summarizer: Summarizer

  /// Metadata generator for AI operations
  private let metadataGenerator: MetadataGenerator

  /// Markdown content of the essay for display
  @Published var content: String = "" {
    didSet {
      // Auto-generate summary when content is first loaded
      if !content.isEmpty && oldValue.isEmpty {
        Task {
          await summarize()
        }
        Task {
          await generateEssayMetadata()
        }
      }
    }
  }

  init(essay: Essay, llm: any LLM = SystemLLM()) {
    self.essay = essay
    self.summarizer = Summarizer(llm: llm)
    self.metadataGenerator = MetadataGenerator(llm: llm)
  }

  /// Fetches and parses essay content from the URL
  func loadEssayContent() async {
    self.errorMessage = nil
    self.isLoading = true
    defer { self.isLoading = false }

    do {
      self.content = try await essayService.readEssay(from: essay.url)
    } catch {
      self.errorMessage =
        "Failed to load essay content. Please check your internet connection and try again."
    }
  }

  /// Generates summary.
  private func summarize() async {
    self.isGeneratingSummary = true
    defer { self.isGeneratingSummary = false }

    do {
      // Apple's System LLM has a ~4096 token context limit (1 token ≈ 2-3 characters)
      // This means roughly 8,000-12,000 characters maximum per request.
      //
      // For longer content, we use a "divide and conquer" approach:
      // 1. Split text into overlapping chunks
      // 2. Summarize each chunk individually
      // 3. Combine chunk summaries into final summary
      self.summary = try await summarizer.summarize(
        content,
        strategy: .init(chunkSize: 8000, overlapSize: 200)
      )
    } catch {
      self.summary = "Unable to generate summary: \(error.localizedDescription)"
    }
  }

  /// Generates metadata.
  private func generateEssayMetadata() async {
    do {
      self.metadata = try await metadataGenerator.generateMetadata(for: content)
    } catch {
      // Silently handle metadata errors since it's supplementary
    }
  }
}
