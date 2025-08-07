import Testing
import SwiftAI
import Foundation

// MARK: - Test Cases

@Test func llmProtocolWithStringResponse() async throws {
  var fakeLLM = FakeLLM()
  fakeLLM.queueReply("Hello from fake LLM!")
  
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
  
  var fakeLLM = FakeLLM()
  fakeLLM.queueReply(jsonResponse)
  
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
