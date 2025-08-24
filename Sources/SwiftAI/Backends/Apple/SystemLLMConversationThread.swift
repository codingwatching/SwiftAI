#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// A conversation thread that maintains stateful interactions with Apple's on-device language model.
@available(iOS 26.0, macOS 26.0, *)
public final actor SystemLLMConversationThread {
  let session: LanguageModelSession

  init(
    model: SystemLanguageModel,
    tools: [any Tool],
    messages: [Message]
  ) {
    let transcript = FoundationModels.Transcript(messages: messages, tools: tools)
    let foundationTools = tools.map { FoundationModelsToolAdapter(wrapping: $0) }

    self.session = LanguageModelSession(
      model: model,
      tools: foundationTools,
      transcript: transcript
    )
  }

  func generateResponse<T: Generable>(
    userMessage: Message,
    type: T.Type
  ) async throws -> LLMReply<T> {
    let prompt = toFoundationPrompt(message: userMessage)

    let content: T = try await {
      if T.self == String.self {
        let response: LanguageModelSession.Response<String> = try await session.respond(to: prompt)
        return unsafeBitCast(response.content, to: T.self)
      } else {
        let response = try await session.respond(
          to: prompt,
          schema: try T.schema.toGenerationSchema()
        )
        // TODO: Add a protocol extension on `Generable` to conform `GeneratedContentConvertible`
        // and use it here.
        guard let jsonData = response.content.jsonString.data(using: .utf8) else {
          throw LLMError.generalError("Failed to convert JSON string to Data")
        }
        return try JSONDecoder().decode(T.self, from: jsonData)
      }
    }()

    let messages = try session.transcript.messages
    return LLMReply(content: content, history: messages)
  }

  private func toFoundationPrompt(message: Message) -> FoundationModels.Prompt {
    return FoundationModels.Prompt(message.text)
  }
}

@available(iOS 26.0, macOS 26.0, *)
func mapAppleError(_ error: LanguageModelSession.GenerationError) -> LLMError {
  // TODO: Implement proper error mapping when LLMError is fully defined
  return .generalError("Apple generation error: \(error)")
}
#endif
