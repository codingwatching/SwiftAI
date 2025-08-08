#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// Apple's on-device LLM.
/// Requires iOS / macOS 26+ and Apple Intelligence enabled.
@available(iOS 26.0, macOS 26.0, *)
public struct SystemLLM: LLM {
  private let model: SystemLanguageModel

  public init() {
    self.model = SystemLanguageModel.default
  }

  /// Whether the the system model is available.
  /// The model can be unavailable for various reasons, such as:
  /// - Apple Intelligence not enabled on the device
  /// - Low battery
  public var isAvailable: Bool {
    model.isAvailable
  }

  public func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // TODO: Implement tool support
    // TODO: Implement LLMReplyOptions support (temperature, maxTokens, etc.)

    guard isAvailable else {
      throw LLMError.generalError("Model unavailable")
    }

    guard tools.isEmpty else {
      throw LLMError.generalError("Tool calling not yet supported")
    }

    // TODO: The correct approach is to convert messages to FoundationModels.Transcript,
    //   then rehydrate a FoundationModels.LanguageModelSession using that transcript.
    let prompt = try convertMessagesToPrompt(messages)
    let session = LanguageModelSession(model: model)

    do {
      // Handle different return types
      if T.self != String.self {
        fatalError("Unsupported return type: \(T.self). Only String is currently supported.")
      }

      let response = try await session.respond(to: prompt)
      guard let content = response.content as? T else {
        throw LLMError.generalError("Unexpected response type")
      }
      // TODO: The correct approach is to convert FoundationModels.Transcript back to SwiftAI's Message format.
      let updatedHistory = messages + [AIMessage(chunks: [.text(response.content)])]

      return LLMReply(content: content, history: updatedHistory)
    } catch let error as LanguageModelSession.GenerationError {
      throw mapAppleError(error)
    } catch {
      throw LLMError.generalError("Generation failed: \(error)")
    }
  }

  // MARK: - Private Methods

  private func convertMessagesToPrompt(_ messages: [any Message]) throws
    -> FoundationModels.Prompt
  {
    // TODO: Support multiple messages in the history.
    assert(
      messages.count == 1,
      "System LLM currently only supports a single message in the history for generation.")
    let firstMessage = messages.first!

    let content = firstMessage.chunks.compactMap { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(_):
        fatalError("Structured messages not supported yet")
      case .toolCall:
        // TODO: Handle tool calls when tool support is added
        fatalError("Tool calls not supported yet")
      }
    }.joined(separator: "")

    return FoundationModels.Prompt(content)
  }

  // TODO: Implement schema conversion for structured output
  // private func convertSchemaToAppleSchema(_ schema: Schema) throws -> GenerationSchema

  private func mapAppleError(_ error: LanguageModelSession.GenerationError) -> LLMError {
    // TODO: Implement proper error mapping when LLMError is fully defined
    return .generalError("Apple generation error: \(error)")
  }
}
#endif
