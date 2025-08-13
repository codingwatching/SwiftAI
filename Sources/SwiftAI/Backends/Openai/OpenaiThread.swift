import Foundation
import OpenAI

/// Maintains the state of a conversation with an Openai language model.
public final class OpenaiThread: Sendable {
  let messages: [any Message]
  let previousResponseID: String?
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
    messages: [any Message] = [],
    previousResponseID: String? = nil,
    tools: [any SwiftAI.Tool] = []
  ) {
    self.messages = messages
    self.previousResponseID = previousResponseID
    self.tools = tools
  }

  /// Returns a new thread with an additional message appended to the conversation history.
  func withNewMessage(_ message: any Message) -> OpenaiThread {
    let updatedMessages = messages + [message]
    return OpenaiThread(
      messages: updatedMessages, previousResponseID: previousResponseID, tools: tools)
  }

  /// Returns a new thread with an updated response ID.
  func withNewResponseID(_ responseID: String) -> OpenaiThread {
    return OpenaiThread(messages: messages, previousResponseID: responseID, tools: tools)
  }

  func execute(toolCall: ToolCall) async throws -> ToolOutput {
    guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
      throw LLMError.generalError("Tool '\(toolCall.toolName)' not found")
    }

    let argumentsData = toolCall.arguments.data(using: .utf8) ?? Data()
    let result = try await tool.call(argumentsData)

    return ToolOutput(
      id: toolCall.id,
      toolName: toolCall.toolName,
      chunks: result.chunks,
    )
  }
}
