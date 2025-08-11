#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// Apple's on-device LLM.
/// Requires iOS / macOS 26+ and Apple Intelligence enabled.
@available(iOS 26.0, macOS 26.0, *)
public struct SystemLLM: LLM {
  public typealias Thread = FoundationLanguageModelThread
  private let model: SystemLanguageModel

  public init() {
    self.model = SystemLanguageModel.default
  }

  /// Whether the system model is available.
  /// The model can be unavailable for various reasons, such as:
  /// - Apple Intelligence not enabled on the device
  /// - Low battery
  public var isAvailable: Bool {
    model.isAvailable
  }

  public func makeThread(
    tools: [any Tool],
    messages: [any Message]
  ) -> FoundationLanguageModelThread {
    // TODO: Convert messages to FoundationModels.Transcript and initialize session
    let emptyTranscript = FoundationModels.Transcript()
    let foundationTools = tools.map { FoundationModelsToolAdapter(wrapping: $0) }

    let session = LanguageModelSession(
      model: model,
      tools: foundationTools,
      transcript: emptyTranscript
    )
    return FoundationLanguageModelThread(session: session)
  }

  public func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // TODO: Implement LLMReplyOptions support (temperature, maxTokens, etc.)

    guard isAvailable else {
      // TODO: Throw a more specific error
      throw LLMError.generalError("Model unavailable")
    }

    guard messages.count == 1 else {
      throw LLMError.generalError(
        "System LLM currently only supports a single message in the history for generation.")
    }

    // TODO: The correct approach is to convert messages to FoundationModels.Transcript,
    //   then rehydrate a FoundationModels.LanguageModelSession using that transcript.
    let userMessage = UserMessage(chunks: messages.first!.chunks)
    let prompt = convertMessageToPrompt(userMessage)

    let foundationTools = tools.map { FoundationModelsToolAdapter(wrapping: $0) }
    let session = LanguageModelSession(model: model, tools: foundationTools)

    do {
      return try await generateResponse(
        session: session,
        prompt: prompt,
        inputMessage: userMessage,
        type: type
      )
    } catch let error as LanguageModelSession.GenerationError {
      throw mapAppleError(error)
    } catch {
      throw LLMError.generalError("Generation failed: \(error)")
    }
  }

  public func reply<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    in thread: inout FoundationLanguageModelThread,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    // TODO: Implement LLMReplyOptions support (temperature, maxTokens, etc.)

    guard isAvailable else {
      // TODO: Throw a more specific error
      throw LLMError.generalError("Model unavailable")
    }

    let userMessage = UserMessage(chunks: prompt.chunks)
    let foundationPrompt = convertMessageToPrompt(userMessage)
    do {
      return try await generateResponse(
        session: thread.session,
        prompt: foundationPrompt,
        inputMessage: userMessage,
        type: type
      )
    } catch let error as LanguageModelSession.GenerationError {
      throw mapAppleError(error)
    } catch {
      throw LLMError.generalError("Generation failed: \(error)")
    }
  }

  // MARK: - Private Methods

  private func convertMessageToPrompt(_ message: any Message)
    -> FoundationModels.Prompt
  {
    let content = message.chunks.compactMap { chunk in
      switch chunk {
      case .text(let text):
        return text
      case .structured(let structuredText):
        return structuredText
      case .toolCall(let toolCall):
        return "Tool call: \(toolCall.toolName) with arguments: \(toolCall.arguments)"
      }
    }.joined(separator: "\n")  // TODO: Revisit the separator.

    return FoundationModels.Prompt(content)
  }
}

// TODO: What are the implications of using @unchecked Sendable.
/// A thread that maintains the conversation state of Apple's on-device language model.
@available(iOS 26.0, macOS 26.0, *)
public final class FoundationLanguageModelThread: @unchecked Sendable {
  internal let session: LanguageModelSession

  internal init(session: LanguageModelSession) {
    self.session = session
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func generateResponse<T: Generable>(
  session: LanguageModelSession,
  prompt: FoundationModels.Prompt,
  inputMessage: UserMessage,
  type: T.Type
) async throws -> LLMReply<T> {
  if T.self == String.self {
    let response = try await session.respond(to: prompt, generating: String.self)
    let content = response.content
    guard let typedContent = content as? T else {
      throw LLMError.generalError("Type mismatch: Expected \(T.self)")
    }

    // TODO: The correct approach is to convert FoundationModels.Transcript back to SwiftAI's Message format.
    let aiMessage = AIMessage(chunks: [.text(content)])
    return LLMReply(content: typedContent, history: [inputMessage, aiMessage])
  } else {
    let foundationSchema = try T.schema.toGenerationSchema()
    let response = try await session.respond(to: prompt, schema: foundationSchema)

    guard let jsonData = response.content.jsonString.data(using: .utf8) else {
      throw LLMError.generalError("Failed to convert JSON string to Data")
    }
    let content = try JSONDecoder().decode(T.self, from: jsonData)

    // TODO: The correct approach is to convert FoundationModels.Transcript back to SwiftAI's Message format.
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
    let aiMessage = AIMessage(chunks: [.structured(jsonString)])
    return LLMReply(content: content, history: [inputMessage, aiMessage])
  }
}

@available(iOS 26.0, macOS 26.0, *)
private func mapAppleError(_ error: LanguageModelSession.GenerationError) -> LLMError {
  // TODO: Implement proper error mapping when LLMError is fully defined
  return .generalError("Apple generation error: \(error)")
}
#endif
