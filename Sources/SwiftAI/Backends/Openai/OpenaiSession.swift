import Foundation
import OpenAI

/// Maintains the state of a conversation with an Openai language model.
public final actor OpenaiSession: LLMSession {
  private(set) var messages: [Message]
  private(set) var previousResponseID: String?
  let tools: [any SwiftAI.Tool]
  private let client: OpenAIProtocol
  private let model: String

  var openaiTools: [FunctionTool] {
    get throws {
      return try tools.map { tool in
        FunctionTool(
          name: tool.name,
          description: tool.description,
          parameters: try convertSchemaToJSONSchema(type(of: tool).parameters),
          strict: true
        )
      }
    }
  }

  init(
    messages: [Message] = [],
    previousResponseID: String? = nil,
    tools: [any SwiftAI.Tool] = [],
    client: OpenAIProtocol,
    model: String
  ) {
    self.messages = messages
    self.previousResponseID = previousResponseID
    self.tools = tools
    self.client = client
    self.model = model
  }

  // No op.
  // OpenAI automatically caches prompt prefixes that are > 1024 tokens by default.
  public nonisolated func prewarm(promptPrefix: Prompt?) {}

  func generateResponse<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    let userMessage = Message.user(.init(chunks: prompt.chunks))

    var input: CreateModelResponseQuery.Input
    if self.previousResponseID != nil {
      // Continue from previous response.
      input = try CreateModelResponseQuery.Input.from([userMessage])
    } else {
      // Start a new conversation with the user message.
      input = try CreateModelResponseQuery.Input.from(messages + [userMessage])
    }

    // Configure output format.
    let textConfig = try {
      if type == String.self {
        return CreateModelResponseQuery.TextResponseConfigurationOptions.text
      }
      return try .jsonSchema(makeStructuredOutputConfig(for: type))
    }()

    self.messages.append(userMessage)

    let finalMessage: Message.AIMessage = try await {
      // Tool loop.
      while true {
        let response: ResponseObject = try await client.responses.createResponse(
          query: CreateModelResponseQuery(
            input: input,
            model: model,
            maxOutputTokens: options.maximumTokens,
            previousResponseId: self.previousResponseID,
            temperature: options.temperature.map { $0 * 2.0 },  // OpenAI uses a range between 0.0 and 2.0
            text: textConfig,
            tools: try openaiTools.map { .functionTool($0) },
            topP: extractTopPThreshold(from: options.samplingMode)
          )
        )

        // Update the conversation state.
        let aiMsg = try response.asSwiftAIMessage
        self.messages.append(.ai(aiMsg))
        self.previousResponseID = response.id

        if aiMsg.toolCalls.isEmpty {
          // No more tool calls, we're done.
          return aiMsg
        }

        // Execute tool calls and update the conversation state.
        var outputToolMessages = [Message]()
        for toolCall in aiMsg.toolCalls {
          let toolOutput = try await execute(toolCall: toolCall)
          outputToolMessages.append(.toolOutput(toolOutput))
        }

        self.messages.append(contentsOf: outputToolMessages)

        // Prepare the next input.
        input = try CreateModelResponseQuery.Input.from(outputToolMessages)
      }
    }()

    // Extract final content from the last AI message
    let content: T = try {
      if T.self == String.self {
        return unsafeBitCast(finalMessage.text, to: T.self)
      } else {
        // For structured types, parse JSON from text content
        let jsonData = finalMessage.text.data(using: .utf8) ?? Data()
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
      }
    }()

    return LLMReply(
      content: content,
      history: messages
    )
  }

  func generateResponseStream<T: Generable>(
    to prompt: Prompt,
    returning type: T.Type,
    options: LLMReplyOptions
  ) -> AsyncThrowingStream<T.Partial, Error> where T: Sendable {
    return AsyncThrowingStream { continuation in
      Task(name: "OpenaiSession.generateResponseStream") {
        defer {
          continuation.finish()
        }

        let userMessage = Message.user(.init(chunks: prompt.chunks))
        self.messages.append(userMessage)

        // Configure output format.
        let textConfig = try {
          if type == String.self {
            return CreateModelResponseQuery.TextResponseConfigurationOptions.text
          }
          return try .jsonSchema(makeStructuredOutputConfig(for: type))
        }()

        var input: CreateModelResponseQuery.Input = try {
          if self.previousResponseID != nil {
            // Continue from previous response.
            return try CreateModelResponseQuery.Input.from([userMessage])
          } else {
            // Start a new conversation with the user message.
            return try CreateModelResponseQuery.Input.from(messages + [userMessage])
          }
        }()

        do {
          while true {
            // Prepare OpenAI streaming query
            let query = CreateModelResponseQuery(
              input: input,
              model: model,
              maxOutputTokens: options.maximumTokens,
              previousResponseId: self.previousResponseID,
              stream: true,
              temperature: options.temperature.map { $0 * 2.0 },  // OpenAI uses a range between 0.0 and 2.0
              text: textConfig,
              tools: try openaiTools.map { .functionTool($0) },
              topP: extractTopPThreshold(from: options.samplingMode)
            )

            var accumulatedText: String = ""
            for try await event in self.client.responses.createResponseStreaming(query: query) {
              switch event {
              case .outputText(.delta(let deltaEvent)):
                accumulatedText += deltaEvent.delta
                let partial = try {
                  if T.self == String.self {
                    // String.Partial = String
                    return accumulatedText as! T.Partial
                  } else {
                    // TODO: Do not yield when the the new partial is the same as the previous one.
                    let partialJson = repair(json: accumulatedText)
                    return try JSONDecoder().decode(
                      T.Partial.self, from: partialJson.data(using: .utf8) ?? Data())
                  }
                }()
                continuation.yield(partial)

              case .completed(let responseEvent),
                .incomplete(let responseEvent):
                let response = responseEvent.response

                // Update the conversation state.
                let aiMsg = try response.asSwiftAIMessage
                self.messages.append(.ai(aiMsg))
                self.previousResponseID = response.id

                if aiMsg.toolCalls.isEmpty {
                  // No more tool calls, we're done.
                  return
                }

                // Execute tool calls and update the conversation state.
                var outputToolMessages = [Message]()
                for toolCall in aiMsg.toolCalls {
                  let toolOutput = try await execute(toolCall: toolCall)
                  outputToolMessages.append(.toolOutput(toolOutput))
                }

                self.messages.append(contentsOf: outputToolMessages)

                // Prepare the next input.
                input = try CreateModelResponseQuery.Input.from(outputToolMessages)

              case .error(let errorEvent):
                continuation.finish(
                  throwing: LLMError.generalError("OpenAI streaming error: \(errorEvent.message)"))

              case .refusal(.done(let refusalEvent)):
                continuation.finish(
                  throwing: LLMError.generalError("OpenAI refusal error: \(refusalEvent.refusal)"))

              default:
                // Ignore other events.
                break
              }
            }
          }
        } catch {
          continuation.finish(throwing: LLMError.generalError("OpenAI streaming failed: \(error)"))
        }
      }
    }
  }

  func execute(toolCall: Message.ToolCall) async throws -> Message.ToolOutput {
    guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
      throw LLMError.generalError("Tool '\(toolCall.toolName)' not found")
    }

    let argumentsData = toolCall.arguments.jsonString.data(using: .utf8) ?? Data()
    let result = try await tool.call(argumentsData)

    return .init(
      id: toolCall.id,
      toolName: toolCall.toolName,
      chunks: result.chunks
    )
  }

  private func extractTopPThreshold(from samplingMode: LLMReplyOptions.SamplingMode?) -> Double? {
    guard let samplingMode = samplingMode else { return nil }

    switch samplingMode {
    case .topP(let probabilityThreshold):
      return probabilityThreshold
    case .greedy:
      return 0.0
    }
  }
}
