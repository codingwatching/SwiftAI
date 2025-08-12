import Foundation
import SwiftAI
import Testing

// MARK: - Test Cases

@Test func chatBasicConversation() async throws {
  let fakeLLM = FakeLLM()
  fakeLLM.queueReply("Hello! How can I help you today?")

  let chat = try Chat(with: fakeLLM)
  let response = try await chat.send {
    "Hi there! Can you assist me?"
  }

  #expect(response == "Hello! How can I help you today?")
}

@Test func chatWithSystemMessage() async throws {
  let fakeLLM = FakeLLM()
  fakeLLM.queueReply("I'll be concise in my responses.")

  let chat = try Chat(
    with: fakeLLM,
    initialMessages: [
      SystemMessage(text: "You are a helpful but very brief assistant")
    ])
  let response = try await chat.send("Explain AI")

  #expect(response == "I'll be concise in my responses.")
}

@Test func chatWithTools() async throws {
  let fakeLLM = FakeLLM()
  let fakeToolCall = FakeLLM.FakeToolCall(
    toolName: "fake_tool",
    arguments: ["input": "test input"],
    expectedOutput: "Tool executed successfully"
  )
  fakeLLM.queueReply(
    toolCalls: [fakeToolCall],
    finalResponse: "I used the fake tool and got the result: Tool executed successfully"
  )

  let chat = try Chat(with: fakeLLM, tools: [FakeTool()])
  let response = try await chat.send("Use the fake tool")

  #expect(response == "I used the fake tool and got the result: Tool executed successfully")
}

@Test func chatWithStructuredResponse() async throws {
  let jsonResponse = """
    {
      "message": "Here's your structured response",
      "count": 123
    }
    """
  let fakeLLM = FakeLLM()
  fakeLLM.queueReply(jsonResponse)

  let chat = try Chat(with: fakeLLM)
  let response: FakeResponse = try await chat.send(
    "Give me a structured response",
    returning: FakeResponse.self
  )

  #expect(response == FakeResponse(message: "Here's your structured response", count: 123))
}

@Test func chatPersistsConversationHistory() async throws {
  let fakeLLM = FakeLLM()
  fakeLLM.queueReply("First response")
  fakeLLM.queueReply("Second response")

  let chat = try Chat(with: fakeLLM)

  let firstResponse = try await chat.send("First message")
  #expect(firstResponse == "First response")

  let secondResponse = try await chat.send("Second message")
  #expect(secondResponse == "Second response")

  #expect(await chat.messages.count == 4)
}

@Test func chatMessageHistoryWithToolCalls() async throws {
  let fakeLLM = FakeLLM()
  let fakeToolCall = FakeLLM.FakeToolCall(
    toolName: "fake_tool",
    arguments: ["input": "weather query"],
    expectedOutput: "Sunny, 25°C"
  )
  fakeLLM.queueReply(
    toolCalls: [fakeToolCall],
    finalResponse: "The weather is sunny and 25°C."
  )

  let chat = try Chat(with: fakeLLM, tools: [FakeTool()])
  let response = try await chat.send("What's the weather?")

  #expect(response == "The weather is sunny and 25°C.")

  // Verify the message history matches expected sequence
  let actualMessages = await chat.messages

  let expectedMessages: [any Message] = [
    UserMessage(text: "What's the weather?"),
    AIMessage(chunks: [
      .toolCall(
        ToolCall(
          id: "tool_call_0",
          toolName: "fake_tool",
          arguments: "{\"input\":\"weather query\"}"
        ))
    ]),
    ToolOutput(
      id: "tool_call_0",
      toolName: "fake_tool",
      chunks: [.text("Sunny, 25°C")]
    ),
    AIMessage(text: "The weather is sunny and 25°C."),
  ]

  #expect(actualMessages.count == expectedMessages.count)

  // Compare each message individually by role and key properties
  #expect(actualMessages[0].role == expectedMessages[0].role, "First message role mismatch")
  #expect(actualMessages[1].role == expectedMessages[1].role, "Second message role mismatch")
  #expect(actualMessages[2].role == expectedMessages[2].role, "Third message role mismatch")
  #expect(actualMessages[3].role == expectedMessages[3].role, "Fourth message role mismatch")
}
