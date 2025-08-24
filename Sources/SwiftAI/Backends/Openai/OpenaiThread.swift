import Foundation
import OpenAI

/// Maintains the state of a conversation with an Openai language model.
public final actor OpenaiConversationThread {
  private(set) var messages: [Message]
  private(set) var previousResponseID: String?
  let tools: [any SwiftAI.Tool]

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
    tools: [any SwiftAI.Tool] = []
  ) {
    self.messages = messages
    self.previousResponseID = previousResponseID
    self.tools = tools
  }

  func generateResponse<T: Generable>(
    to prompt: any PromptRepresentable,
    returning type: T.Type,
    options: LLMReplyOptions,
    client: OpenAIProtocol,
    model: String
  ) async throws -> LLMReply<T> {
    let userMessage = Message.user(.init(chunks: prompt.chunks))

    var input: CreateModelResponseQuery.Input
    var currentPreviousResponseID: String?

    if let responseID = self.previousResponseID {
      // Continue from previous response.
      input = try CreateModelResponseQuery.Input.from([userMessage])
      currentPreviousResponseID = responseID
    } else {
      // Start a new conversation with the user message.
      input = try CreateModelResponseQuery.Input.from(messages + [userMessage])
      currentPreviousResponseID = nil
    }

    // Configure output format.
    let textConfig = try {
      if type == String.self {
        return CreateModelResponseQuery.TextResponseConfigurationOptions.text
      }
      return try .jsonSchema(makeStructuredOutputConfig(for: type))
    }()

    messages.append(userMessage)

    // Tool loop.
    repeat {
      let query = CreateModelResponseQuery(
        input: input,
        model: model,
        previousResponseId: currentPreviousResponseID,
        text: textConfig,
        tools: try openaiTools.map { .functionTool($0) }
      )

      let response: ResponseObject = try await client.responses.createResponse(query: query)
      let aiMsg = try response.asSwiftAIMessage

      self.messages.append(.ai(aiMsg))
      self.previousResponseID = response.id

      if !aiMsg.toolCalls.isEmpty {
        var outputToolMessages = [Message]()
        for toolCall in aiMsg.toolCalls {
          // TODO: Consider sending the error to the LLM.
          let toolOutput = try await execute(toolCall: toolCall)
          let toolOutputMessage = Message.toolOutput(toolOutput)
          messages.append(toolOutputMessage)
          outputToolMessages.append(toolOutputMessage)
        }

        input = try CreateModelResponseQuery.Input.from(outputToolMessages)
        currentPreviousResponseID = response.id
      }
    } while messages.last?.role != .ai

    // Extract final content from the last AI message
    guard let finalMessage = messages.last else {
      throw LLMError.generalError("Final message should be an AI message")
    }

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
}
