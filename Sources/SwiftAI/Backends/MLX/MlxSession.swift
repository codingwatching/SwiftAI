import Foundation
import MLXLMCommon

/// A session that maintains stateful interactions with MLX language models.
public final actor MlxSession: LLMSession {
  private let configuration: ModelConfiguration
  private let modelManager: MlxModelManager
  private let tools: [any Tool]

  // Conversation state
  private var messages: [Message]
  private var kvCache: [KVCache]?

  init(
    configuration: ModelConfiguration,
    tools: [any Tool],
    messages: [Message],
    modelManager: MlxModelManager
  ) {
    self.configuration = configuration
    self.tools = tools
    self.messages = messages
    self.modelManager = modelManager
  }

  public nonisolated func prewarm(promptPrefix: Prompt?) {
    // TODO: Implement proper prewarming.
  }

  func generateResponse<T: Generable>(
    prompt: Prompt,
    type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard type == String.self else {
      throw LLMError.generalError("MLX does not support non-string return types")
    }

    // TODO: Implement KVCache handling.

    messages.append(Message.user(.init(text: prompt.text)))

    let modelContainer = try await modelManager.getOrLoadModelContainer(for: configuration)
    let stream = try await modelContainer.perform { context in
      // TODO: Support tools and additional context.
      // TODO: Add support to LLMReplyOptions
      let lmInput = try await context.processor.prepare(
        input: UserInput(prompt: prompt.text)
      )
      return try MLXLMCommon.generate(
        input: lmInput, parameters: GenerateParameters(), context: context)
    }

    var content = ""
    for await event in stream {
      switch event {
      case .chunk(let chunk):
        content += chunk
      case .info(let info):
        // TODO: Handle info.
        print("Info: \(info)")
      case .toolCall(_):
        // TODO: Handle tool call.
        break
      }
    }

    messages.append(Message.ai(.init(text: content)))

    return LLMReply(content: unsafeBitCast(content, to: T.self), history: messages)
  }
}
