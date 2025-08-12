import Foundation
import Testing

@testable import SwiftAI

@Suite("OpenAI LLM Integration Tests")
struct OpenAILLMIntegrationTests {

  @Test("Basic text generation", .enabled(if: apiKeyIsPresent()))
  func testBasicTextGeneration() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    let response = try await llm.reply(
      to: [UserMessage(text: "What is 2+2? Answer with just the number.")],
      tools: [],
      returning: String.self,
      options: LLMReplyOptions()
    )

    #expect(!response.content.isEmpty)
    #expect(response.history.count == 2)  // User message + AI response
    #expect(response.history.last?.role == .ai)
    #expect(response.content == "4")
  }

  @Test("Conversation with system prompt", .enabled(if: apiKeyIsPresent()))
  func testConversationWithSystemPrompt() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    let messages: [any Message] = [
      SystemMessage(text: "You are a helpful math tutor. Always show your work."),
      UserMessage(text: "What is 15 × 7?"),
    ]

    let response = try await llm.reply(
      to: messages,
      tools: [],
      returning: String.self,
      options: LLMReplyOptions()
    )

    #expect(!response.content.isEmpty)
    #expect(response.history.count == 3)  // System + User + AI
    #expect(response.history.first?.role == .system)
    #expect(response.history.last?.role == .ai)
    #expect(response.content.localizedCaseInsensitiveContains("105"))
    #expect(response.content.count > 3)  // Should show work
  }

  @Test("Threaded conversation", .enabled(if: apiKeyIsPresent()))
  func testThreadedConversation() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    // Create thread with initial context
    var thread = try llm.makeThread(
      tools: [],
      messages: [SystemMessage(text: "You are a helpful assistant. Keep responses brief.")]
    )

    // First exchange
    let firstResponse = try await llm.reply(
      to: "Hello, my name is Alice",
      returning: String.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    #expect(!firstResponse.content.isEmpty)

    // Second exchange - should remember the name
    let secondResponse = try await llm.reply(
      to: "What's my name?",
      returning: String.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    #expect(!secondResponse.content.isEmpty)
    // The response should mention "Alice" since it should remember from context
    #expect(secondResponse.content.localizedCaseInsensitiveContains("alice"))
  }

  @Test("Error handling for invalid request", .enabled(if: apiKeyIsPresent()))
  func testErrorHandling() async throws {
    let llm = OpenAILLM(model: "invalid-model-name-12345")

    let messages: [any Message] = [
      UserMessage(text: "Hello")
    ]

    await #expect(throws: LLMError.self) {
      _ = try await llm.reply(
        to: messages,
        tools: [],
        returning: String.self,
        options: LLMReplyOptions()
      )
    }
  }

  @Test("API key validation")
  func testApiKeyValidation() {
    // Test with explicit API key
    let llmWithKey = OpenAILLM(apiToken: "test-key", model: "gpt-4.1-nano")
    #expect(llmWithKey.isAvailable == true)

    // Test with empty API key
    let llmWithoutKey = OpenAILLM(apiToken: "", model: "gpt-4.1-nano")
    #expect(llmWithoutKey.isAvailable == false)
  }

  @Test("Environment variable API key loading")
  func testEnvironmentVariableLoading() {
    // This test checks that the environment variable is read
    // The actual value depends on the test environment
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    let hasEnvKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
    #expect(llm.isAvailable == hasEnvKey)
  }
}

// MARK: - Test Helpers

/// Check if OpenAI API key is available for integration tests
private func apiKeyIsPresent() -> Bool {
  return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
}
