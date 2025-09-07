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
      let chatMessages = makeMLXChatMessages(from: self.messages)

      let stream = try await modelContainer.perform { context in
        let lmInput = try await context.processor.prepare(
          input: UserInput(chat: chatMessages, tools: toolSpecs)
        )
        // TODO: Add support to LLMReplyOptions
        return try MLXLMCommon.generate(
          input: lmInput, parameters: GenerateParameters(), context: context)
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

private func makeMLXChatMessages(from messages: [Message]) -> [MLXLMCommon.Chat.Message] {
  return messages.map { m in
    switch m {
    case .system(let sysMsg):
      return MLXLMCommon.Chat.Message.system(sysMsg.text)
    case .user(let userMsg):
      return MLXLMCommon.Chat.Message.user(userMsg.text)
    case .ai(let aiMsg):
      // TODO: Add Tool calls in toolUseStartTag and toolUseEndTag for the model
      return MLXLMCommon.Chat.Message.assistant(aiMsg.text)
    case .toolOutput(let toolOutputMsg):
      return MLXLMCommon.Chat.Message.tool(toolOutputMsg.text)
    }
  }
}

extension MLXLMCommon.JSONValue {
  fileprivate var asStructuredContent: StructuredContent {
    switch self {
    case .null:
      return StructuredContent(kind: .null)
    case .bool(let value):
      return StructuredContent(kind: .bool(value))
    case .int(let value):
      return StructuredContent(kind: .number(Double(value)))
    case .double(let value):
      return StructuredContent(kind: .number(value))
    case .string(let value):
      return StructuredContent(kind: .string(value))
    case .array(let values):
      return StructuredContent(kind: .array(values.map { $0.asStructuredContent }))
    case .object(let dict):
      return StructuredContent(kind: .object(dict.mapValues { $0.asStructuredContent }))
    @unknown default:
      assertionFailure("Unknown JSONValue type")
      return StructuredContent(kind: .null)
    }
  }
}

private func makeMLXToolSpecs(from tools: [any Tool]) -> [Tokenizers.ToolSpec]? {
  if tools.isEmpty { return nil }
  return tools.map { makeToolSpec(from: $0) }
}

private func makeToolSpec(from tool: any Tool) -> Tokenizers.ToolSpec {
  let parameters = schemaToJSONObject(type(of: tool).parameters)
  return [
    "type": "function",
    "function": [
      "name": tool.name,
      "description": tool.description,
      "parameters": parameters,
    ]
  ]
}

// MARK: - Schema → JSON (for Tokenizers.ToolSpec)

private func schemaToJSONObject(_ schema: Schema) -> [String: Any] {
  switch schema {
  case .object(let name, let description, let properties):
    var json: [String: Any] = [
      "type": "object",
      "properties": properties.mapValues { prop in
        var propertySchema = schemaToJSONObject(prop.schema)
        if let d = prop.description {
          propertySchema["description"] = d
        }
        return propertySchema
      },
      "required": Array(properties.filter { !$0.value.isOptional }.keys),
      "additionalProperties": false,
    ]
    if let description {
      json["description"] = description
    }
    json["title"] = name
    return json

  case .string(let constraints):
    var json: [String: Any] = ["type": "string"]
    for constraint in constraints {
      switch constraint {
      case .pattern(let regex):
        json["pattern"] = regex
      case .constant(let value):
        json["enum"] = [value]
      case .anyOf(let options):
        json["enum"] = options
      }
    }
    return json

  case .integer(let constraints):
    var json: [String: Any] = ["type": "integer"]
    for constraint in constraints {
      switch constraint {
      case .range(let lowerBound, let upperBound):
        if let lowerBound { json["minimum"] = lowerBound }
        if let upperBound { json["maximum"] = upperBound }
      }
    }
    return json

  case .number(let constraints):
    var json: [String: Any] = ["type": "number"]
    for constraint in constraints {
      switch constraint {
      case .range(let lowerBound, let upperBound):
        if let lowerBound { json["minimum"] = lowerBound }
        if let upperBound { json["maximum"] = upperBound }
      }
    }
    return json

  case .boolean:
    return ["type": "boolean"]

  case .array(let itemSchema, let constraints):
    var json: [String: Any] = [
      "type": "array",
      "items": schemaToJSONObject(itemSchema),
    ]
    for constraint in constraints {
      switch constraint {
      case .count(let lower, let upper):
        if let lower { json["minItems"] = lower }
        if let upper { json["maxItems"] = upper }
      }
    }
    return json

  case .anyOf(let name, let description, let schemas):
    var json: [String: Any] = [
      "anyOf": schemas.map { schemaToJSONObject($0) }
    ]
    json["title"] = name
    if let description { json["description"] = description }
    return json
  }
}
