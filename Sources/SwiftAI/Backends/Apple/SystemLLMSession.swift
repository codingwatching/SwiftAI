#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// A session that maintains stateful interactions with Apple's on-device language model.
@available(iOS 26.0, macOS 26.0, *)
public final actor SystemLLMSession: LLMSession {
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

  public nonisolated func prewarm(promptPrefix: Prompt?) {
    if let p = promptPrefix {
      self.session.prewarm(promptPrefix: p.promptRepresentation)
    } else {
      self.session.prewarm()
    }
  }

  func generateResponse<T: Generable>(
    prompt: Prompt,
    type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    let foundationPrompt = prompt.promptRepresentation
    let generationOptions = toFoundationGenerationOptions(options)

    let content: T = try await {
      if T.self == String.self {
        let response: LanguageModelSession.Response<String> = try await session.respond(
          to: foundationPrompt,
          options: generationOptions
        )
        return unsafeBitCast(response.content, to: T.self)
      } else {
        let response = try await session.respond(
          to: foundationPrompt,
          schema: try T.schema.toGenerationSchema(),
          options: generationOptions
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

  func generateResponseStream<T: Generable>(
    prompt: Prompt,
    type: T.Type,
    options: LLMReplyOptions
  ) -> AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    return AsyncThrowingStream { continuation in
      Task {
        defer { continuation.finish() }

        do {
          if T.self == String.self {
            let responseStream = session.streamResponse(
              to: prompt.promptRepresentation,
              options: toFoundationGenerationOptions(options)
            )

            for try await snapshot in responseStream {
              guard let partial = snapshot.content as? T.Partial else {
                assertionFailure("Expected String.Partial to be String")
                return
              }
              continuation.yield(partial)
            }
          } else {
            let responseStream = session.streamResponse(
              to: prompt.promptRepresentation,
              schema: try T.schema.toGenerationSchema(),
              options: toFoundationGenerationOptions(options)
            )

            for try await snapshot in responseStream {
              guard let data = snapshot.content.jsonString.data(using: .utf8) else {
                throw LLMError.generalError("Invalid UTF-8 in partial JSON")
              }

              let partial = try JSONDecoder().decode(T.Partial.self, from: data)
              continuation.yield(partial)
            }
          }
        } catch {
          continuation.finish(throwing: LLMError.generalError("Streaming failed: \(error)"))
        }
      }
    }
  }

  private func toFoundationGenerationOptions(_ options: LLMReplyOptions)
    -> FoundationModels.GenerationOptions
  {
    let samplingMode: GenerationOptions.SamplingMode? = {
      guard let mode = options.samplingMode else { return nil }

      switch mode {
      case .greedy:
        return .greedy
      case .topP(let p):
        return .random(probabilityThreshold: p)
      }
    }()

    return FoundationModels.GenerationOptions(
      sampling: samplingMode,
      temperature: options.temperature,
      maximumResponseTokens: options.maximumTokens
    )
  }
}

@available(iOS 26.0, macOS 26.0, *)
func mapAppleError(_ error: LanguageModelSession.GenerationError) -> LLMError {
  // TODO: Implement proper error mapping when LLMError is fully defined
  return .generalError("Apple generation error: \(error)")
}
#endif
