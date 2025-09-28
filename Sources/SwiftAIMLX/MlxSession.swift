import Foundation
import MLXLMCommon
import SwiftAI
import Tokenizers

/// A session that maintains stateful interactions with MLX language models.
public final actor MlxSession: LLMSession {
  private let configuration: ModelConfiguration
  private let modelManager: MlxModelManager
  private let tools: [any SwiftAI.Tool]

  /// Full conversation history.
  private var transcript: [SwiftAI.Message]

  /// Messages that haven't been processed yet by the model.
  /// When a message is processed, it's removed from the list,
  /// and the KVCache is updated.
  private var unprocessedMessages: [SwiftAI.Message]

  /// Key-value cache for the LLM.
  private var kvCache: [KVCache]?

  init(
    configuration: ModelConfiguration,
    tools: [any SwiftAI.Tool],
    messages: [SwiftAI.Message],
    modelManager: MlxModelManager
  ) {
    self.configuration = configuration
    self.tools = tools
    self.modelManager = modelManager
    self.transcript = messages
    self.unprocessedMessages = messages
  }

  /// Loads the model in memory if it's not already loaded.
  public nonisolated func prewarm(promptPrefix: Prompt?) {
    // TODO: In addition to loading the model we should consider preprocessing the prompt.
    Task {
      try await modelManager.getOrLoadModel(forConfiguration: configuration)
    }
  }

  func generateResponse<T: Generable>(
    prompt: Prompt,
    type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard type == String.self else {
      throw LLMError.generalError("MLX does not support structured output yet")
    }

    let stream = generateResponseStream(prompt: prompt, type: type, options: options)
  
    var finalContent: T.Partial?
    for try await partial in stream {
      finalContent = partial
    }
    
    // Currently MLX only supports String streaming.
    // String.Partial is String, so we can cast it to T.
    guard let content = finalContent as? T else {
      throw LLMError.generalError("No content received from streaming response")
    }
    
    return LLMReply(content: content, history: transcript)
  }

  func generateResponseStream<T: Generable>(
    prompt: Prompt,
    type: T.Type,
    options: LLMReplyOptions
  ) -> AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    // Only support String streaming for now
    guard type == String.self else {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: LLMError.generalError("MLX streaming currently only supports String types"))
      }
    }

    return AsyncThrowingStream { continuation in
      Task {
        defer { continuation.finish() }

        do {
          let userMsg = SwiftAI.Message.user(.init(chunks: prompt.chunks))
          transcript.append(userMsg)
          unprocessedMessages.append(userMsg)

          let modelContainer = try await modelManager.getOrLoadModel(forConfiguration: configuration)
          let toolSpecs = makeMLXToolSpecs(from: self.tools)

          if self.kvCache == nil {
            // Create the KVCache if it doesn't exist.
            self.kvCache = await modelContainer.perform { context in
              context.model.newCache(parameters: GenerateParameters())
            }
          }

          // We capture the KVCache before entering the `perform` block to avoid actor isolation issues
          let kvCache = self.kvCache

          // Tool loop for streaming
          while true {
            let mlxChatMsgs = self.unprocessedMessages.map { $0.asMlxChatMessage }
            let stream = try await modelContainer.perform { context in
              let languageModelInput = try await context.processor.prepare(
                input: UserInput(chat: mlxChatMsgs, tools: toolSpecs)
              )
              let parameters = GenerateParameters(from: options)
              return try MLXLMCommon.generate(
                input: languageModelInput,
                cache: kvCache,
                parameters: parameters,
                context: context
              )
            }

            var text = ""
            var toolCallsToExecute = [SwiftAI.Message.ToolCall]()

            for await event in stream {
              switch event {
              case .chunk(let chunk):
                text += chunk
                let partial = unsafeBitCast(text, to: T.Partial.self)
                continuation.yield(partial)
              case .toolCall(let toolCall):
                let toolCall = SwiftAI.Message.ToolCall(from: toolCall)
                toolCallsToExecute.append(toolCall)
              case .info(_):
                break
              }
            }

            // The kvcache now contains the new context
            self.unprocessedMessages.removeAll()

            if toolCallsToExecute.isEmpty {
              // Terminal state - add final AI message to transcript
              transcript.append(.ai(.init(text: text)))
              break
            }

            // If tool calls exist, add AI message to transcript with tool calls
            let chunks: [ContentChunk] = text.isEmpty ? [] : [.text(text)]
            transcript.append(.ai(.init(chunks: chunks, toolCalls: toolCallsToExecute)))

            // Execute tools
            for toolCall in toolCallsToExecute {
              let output = try await execute(toolCall: toolCall)
              transcript.append(.toolOutput(output))
              unprocessedMessages.append(.toolOutput(output))
            }
          }
        } catch {
          continuation.finish(throwing: LLMError.generalError("MLX streaming failed: \(error)"))
        }
      }
    }
  }

  // MARK: - Helpers

  private func execute(toolCall: SwiftAI.Message.ToolCall) async throws
    -> SwiftAI.Message.ToolOutput
  {
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

extension GenerateParameters {
  fileprivate init(from options: LLMReplyOptions) {
    self.init()
    if let max = options.maximumTokens { self.maxTokens = max }

    switch options.samplingMode {
    case .some(.greedy):
      self.temperature = 0
    case .some(.topP(let p)):
      self.topP = Float(p)
    case .none:
      break
    }

    if let t = options.temperature, options.samplingMode != .some(.greedy) {
      self.temperature = Float(t)
    }
  }
}

extension SwiftAI.Message.ToolCall {
  fileprivate init(from mlxToolCall: MLXLMCommon.ToolCall) {
    self.init(
      id: UUID().uuidString,
      toolName: mlxToolCall.function.name,
      arguments: StructuredContent(
        kind: .object(
          mlxToolCall.function.arguments.mapValues { jsonValue in jsonValue.asStructuredContent }
        )
      )
    )
  }
}
