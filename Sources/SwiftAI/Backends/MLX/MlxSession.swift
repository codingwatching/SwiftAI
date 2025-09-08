import Foundation
import MLXLMCommon
import Tokenizers

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

    messages.append(.user(.init(text: prompt.text)))

    let modelContainer = try await modelManager.getOrLoadModel(forConfiguration: configuration)

    let toolSpecs = makeMLXToolSpecs(from: self.tools)
    toolLoop: while true {
      let chat = self.messages.map { $0.asMlxChatMessage }

      let stream = try await modelContainer.perform { context in
        let lmInput = try await context.processor.prepare(
          input: UserInput(chat: chat, tools: toolSpecs)
        )
        let parameters: GenerateParameters = makeGenerationParams(from: options)
        return try MLXLMCommon.generate(
          input: lmInput, parameters: parameters, context: context)
      }

      var text = ""
      var toolCallsToExecute = [MLXLMCommon.ToolCall]()

      for await event in stream {
        switch event {
        case .chunk(let chunk):
          text += chunk
        case .toolCall(let toolCall):
          toolCallsToExecute.append(toolCall)
        case .info(_):
          break
        }
      }

      if toolCallsToExecute.isEmpty {
        // Terminal state.
        messages.append(.ai(.init(text: text)))
        return LLMReply(content: unsafeBitCast(text, to: T.self), history: messages)
      }

      // Record the partial AI message with any accumulated text and the tool calls
      let swiftAIToolCalls = toolCallsToExecute.map { mlxCall in
        Message.ToolCall(
          id: UUID().uuidString,
          toolName: mlxCall.function.name,
          arguments: StructuredContent(
            kind: .object(
              mlxCall.function.arguments.mapValues { jsonValue in
                jsonValue.asStructuredContent
              }
            )
          )
        )
      }

      let chunks: [ContentChunk] = text.isEmpty ? [] : [.text(text)]
      messages.append(.ai(.init(chunks: chunks, toolCalls: swiftAIToolCalls)))

      // Execute tools
      for call in swiftAIToolCalls {
        let output = try await execute(toolCall: call)
        messages.append(.toolOutput(output))
      }
    }
  }

  // MARK: - Helpers

  private func execute(toolCall: Message.ToolCall) async throws -> Message.ToolOutput {
    guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
      throw LLMError.generalError("Tool '\(toolCall.toolName)' not found")
    }

    // TODO: It's common that we need to call a tool from a Tool call. Make it easier.
    guard let argumentsData = toolCall.arguments.jsonString.data(using: .utf8) else {
      throw LLMError.generalError("Failed to convert arguments to data")
    }

    let result = try await tool.call(argumentsData)
    return .init(id: toolCall.id, toolName: toolCall.toolName, chunks: result.chunks)
  }
}

private nonisolated func makeGenerationParams(from options: LLMReplyOptions) -> GenerateParameters {
  var params = GenerateParameters()
  if let max = options.maximumTokens { params.maxTokens = max }

  switch options.samplingMode {
  case .some(.greedy):
    params.temperature = 0
  case .some(.topP(let p)):
    params.topP = Float(p)
  case .none:
    break
  }

  if let t = options.temperature, options.samplingMode != .some(.greedy) {
    params.temperature = Float(t)
  }

  return params
}
