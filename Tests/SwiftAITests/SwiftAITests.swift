import Testing
import SwiftAI
import Foundation

// MARK: - Fake LLM Implementation for Testing

/// A fake LLM implementation that returns JSON responses and deserializes them.
struct FakeLLM: LLM {
  var isAvailable: Bool = true
  let jsonResponse: String
  
  init(jsonResponse: String) {
    self.jsonResponse = jsonResponse
  }
  
  /// Convenience initializer for plain text responses
  init(textResponse: String) {
    self.jsonResponse = "\"\(textResponse.replacingOccurrences(of: "\"", with: "\\\""))\""
  }
  
  func reply<T: Generable>(
    to messages: [any Message],
    tools: [any Tool],
    returning type: T.Type,
    options: LLMReplyOptions
  ) async throws -> LLMReply<T> {
    let jsonData = Data(jsonResponse.utf8)
    
    // Deserialize JSON to the requested type
    let decoder = JSONDecoder()
    let content = try decoder.decode(T.self, from: jsonData)
    
    // Add an AI response to the history
    let aiResponse = AIMessage(text: jsonResponse) // FIXME: this may be a structured response not plain text.
    let fullHistory = messages + [aiResponse]
    
    return LLMReply(content: content, history: fullHistory)
  }
}

// MARK: - Test Types

struct FakeResponse: Generable {
  let message: String
  let count: Int
}

// MARK: - Test Cases

@Test func llmProtocolWithStringResponse() async throws {
  let fakeLLM = FakeLLM(textResponse: "Hello from fake LLM!")
  
  let messages: [any Message] = [
    SystemMessage(text: "You are a helpful assistant"),
    UserMessage(text: "Hello!")
  ]
  
  let reply = try await fakeLLM.reply(to: messages)
  
  #expect(reply.content == "Hello from fake LLM!")
  #expect(reply.history.count == 3) // 2 input messages + 1 AI response
  #expect(reply.history[0].role == .system)
  #expect(reply.history[1].role == .user)
  #expect(reply.history[2].role == .ai)
}

@Test func llmProtocolWithStructResponse() async throws {
  let jsonResponse = """
    {
      "message": "Test message",
      "count": 42
    }
    """
  
  let fakeLLM = FakeLLM(jsonResponse: jsonResponse)
  
  let messages: [any Message] = [UserMessage(text: "Generate a fake response")]
  
  let reply = try await fakeLLM.reply(
    to: messages,
    tools: [],
    returning: FakeResponse.self,
    options: .default
  )
  
  #expect(reply.content.message == "Test message")
  #expect(reply.content.count == 42)
  #expect(reply.history.count == 2)
}

@Test func messageTypesWork() {
  let systemMsg = SystemMessage(text: "System prompt")
  let userMsg = UserMessage(text: "User input")
  let aiMsg = AIMessage(text: "AI response")
  
  #expect(systemMsg.role == .system)
  #expect(userMsg.role == .user)
  #expect(aiMsg.role == .ai)
  
  // Test chunk content
  if case .text(let content) = systemMsg.chunks.first {
    #expect(content == "System prompt")
  } else {
    Issue.record("Expected text chunk")
    return
  }
}
