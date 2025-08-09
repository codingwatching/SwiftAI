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
      if T.self == String.self {
        let reply = try await generateText(
          session: session,
          prompt: prompt,
          messages: messages
        )
        guard let typedReply = reply as? LLMReply<T> else {
          throw LLMError.generalError("Type mismatch: Expected LLMReply<\(T.self)>")
        }
        return typedReply
      } else {
        return try await generateStructuredOutput(
          session: session,
          prompt: prompt,
          messages: messages,
          type: type
        )
      }
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

  private func generateText(
    session: LanguageModelSession,
    prompt: FoundationModels.Prompt,
    messages: [any Message],
  ) async throws -> LLMReply<String> {
    let response = try await session.respond(to: prompt)
    let content = response.content

    // TODO: The correct approach is to convert FoundationModels.Transcript back to SwiftAI's Message format.
    let updatedHistory = messages + [AIMessage(chunks: [.text(content)])]
    return LLMReply(content: content, history: updatedHistory)
  }

  private func generateStructuredOutput<T: Generable>(
    session: LanguageModelSession,
    prompt: FoundationModels.Prompt,
    messages: [any Message],
    type: T.Type
  ) async throws -> LLMReply<T> {
    let foundationSchema = try T.schema.toGenerationSchema()
    let response = try await session.respond(to: prompt, schema: foundationSchema)

    guard let jsonData = response.content.jsonString.data(using: .utf8) else {
      throw LLMError.generalError("Failed to convert JSON string to Data")
    }
    let content = try JSONDecoder().decode(T.self, from: jsonData)

    // TODO: The correct approach is to convert FoundationModels.Transcript back to SwiftAI's Message format.
    // For now, we'll use a placeholder representation of the structured content
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
    let structuredMessage = AIMessage(chunks: [.structured(jsonString)])
    let updatedHistory = messages + [structuredMessage]

    return LLMReply(content: content, history: updatedHistory)
  }

  private func mapAppleError(_ error: LanguageModelSession.GenerationError) -> LLMError {
    // TODO: Implement proper error mapping when LLMError is fully defined
    return .generalError("Apple generation error: \(error)")
  }
}
#endif
