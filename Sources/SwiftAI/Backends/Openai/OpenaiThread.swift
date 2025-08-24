import Foundation
import OpenAI

/// Maintains the state of a conversation with an Openai language model.
///
/// - Note: This class is not thread-safe. It is not meant to be shared between
///   multiple concurrent calls because it represents a single conversation.
public final class OpenaiConversationThread: @unchecked Sendable {
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

  /// Appends a message to the conversation history.
  func append(message: Message) {
    messages.append(message)
  }

  /// Sets the previous response ID.
  func setPreviousResponseID(_ responseID: String) {
    previousResponseID = responseID
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
