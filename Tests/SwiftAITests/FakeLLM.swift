import Foundation
import SwiftAI

// MARK: - Shared Test Helpers

/// A stateful fake LLM implementation for testing with programmable responses and tool calling.
final class FakeLLM: LLM, @unchecked Sendable {
  /// A tuple representing a programmed tool call and its expected output.
  typealias ProgrammedToolCall = (call: Message.ToolCall, expectedOutput: String)

  /// Represents a programmed response that the fake LLM will return.
  struct ProgrammedReply {
    let toolCalls: [ProgrammedToolCall]?
    let finalResponse: String

    init(toolCalls: [ProgrammedToolCall]? = nil, finalResponse: String) {
      self.toolCalls = toolCalls
      self.finalResponse = finalResponse
    }
  }

  let isAvailable: Bool = true
  let availability: LLMAvailability = .available
  private var replyQueue: [ProgrammedReply] = []

  init() {}

  // MARK: - Configuration Methods

  /// Queues a simple text response.
  func queueReply(_ response: String) {
    let reply = ProgrammedReply(finalResponse: response)
    replyQueue.append(reply)
  }

  /// Queues a response with tool calls followed by a final response.
  func queueReply(toolCalls: [ProgrammedToolCall], finalResponse: String) {
    let reply = ProgrammedReply(toolCalls: toolCalls, finalResponse: finalResponse)
    replyQueue.append(reply)
  }

  /// Queues a pre-configured reply.
  func queueReply(_ reply: ProgrammedReply) {
    replyQueue.append(reply)
  }

  // MARK: - LLM Implementation

  func reply<T: Generable>(
    to messages: [Message],
    returning type: T.Type,
    tools: [any Tool],
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    guard !replyQueue.isEmpty else {
      throw FakeLLMError.noRepliesQueued
    }

    let reply = replyQueue.removeFirst()
    var currentMessages = messages

    // Simulate tool calls if programmed
    if let programmedToolCalls = reply.toolCalls {
      let toolCallMessages = programmedToolCalls.map { $0.call }

      // Add AI message with tool calls
      if !toolCallMessages.isEmpty {
        let aiMessage = Message.ai(.init(chunks: [], toolCalls: toolCallMessages))
        currentMessages.append(aiMessage)
      }

      // Simulate tool execution
      for programmedToolCall in programmedToolCalls {
        guard tools.contains(where: { $0.name == programmedToolCall.call.toolName }) else {
          throw FakeLLMError.toolNotFound(programmedToolCall.call.toolName)
        }

        let toolOutputMessage = Message.toolOutput(
          .init(
            id: programmedToolCall.call.id,
            toolName: programmedToolCall.call.toolName,
            chunks: [.text(programmedToolCall.expectedOutput)]
          ))
        currentMessages.append(toolOutputMessage)
      }
    }

    // Create final AI response
    let content: T
    if T.self == String.self {
      // For String responses, use the text directly
      content = reply.finalResponse as! T
    } else {
      // For structured responses, decode as JSON
      let finalResponseData = Data(reply.finalResponse.utf8)
      let decoder = JSONDecoder()
      content = try decoder.decode(T.self, from: finalResponseData)
    }

    let aiResponse = Message.ai(.init(text: reply.finalResponse))
    let fullHistory = currentMessages + [aiResponse]

    return LLMReply(content: content, history: fullHistory)
  }
}

// MARK: - Test Error Types

enum FakeLLMError: Error {
  case noRepliesQueued
  case toolNotFound(String)
}

@Generable
struct FakeResponse: Equatable {
  let message: String
  let count: Int
}

struct FakeTool: Tool {
  @Generable
  struct Arguments {
    let input: String
  }

  let name = "fake_tool"
  let description = "A fake tool for testing purposes"

  func call(arguments: Arguments) async throws -> String {
    return "Tool output: \(arguments.input)"
  }
}
