import Foundation
import Testing

@testable import SwiftAI

@Suite("OpenAI LLM Integration Tests")
struct OpenaiLLMTests: LLMBaseTestCases {
  var llm: OpenaiLLM {
    OpenaiLLM(model: "gpt-4.1-nano")
  }

  // MARK: - Shared LLM Tests

  @Test("Basic text generation", .enabled(if: apiKeyIsPresent()))
  func testReply_ToPrompt() async throws {
    try await testReply_ToPrompt_Impl()
  }

  @Test("Basic text generation - history verification", .enabled(if: apiKeyIsPresent()))
  func testReply_ToPrompt_ReturnsCorrectHistory() async throws {
    try await testReply_ToPrompt_ReturnsCorrectHistory_Impl()
  }

  @Test(
    "Max tokens constraint - very short response",
    .disabled("llm reply options not supported yet"),
    .enabled(if: apiKeyIsPresent()))
  func testReply_WithMaxTokens1_ReturnsVeryShortResponse() async throws {
    try await testReply_WithMaxTokens1_ReturnsVeryShortResponse_Impl()
  }

  @Test("Structured output - primitives content", .enabled(if: apiKeyIsPresent()))
  func testReply_ReturningPrimitives_ReturnsCorrectContent() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectContent_Impl()
  }

  @Test(
    "Structured output - primitives history",
    .enabled(if: apiKeyIsPresent())
  )
  func testReply_ReturningPrimitives_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - arrays content", .enabled(if: apiKeyIsPresent()))
  func testReply_ReturningArrays_ReturnsCorrectContent() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectContent_Impl()
  }

  @Test(
    "Structured output - arrays history",
    .enabled(if: apiKeyIsPresent())
  )
  func testReply_ReturningArrays_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - nested objects", .enabled(if: apiKeyIsPresent()))
  func testReply_ReturningNestedObjects_ReturnsCorrectContent() async throws {
    try await testReply_ReturningNestedObjects_ReturnsCorrectContent_Impl()
  }

  @Test("Thread maintains conversation context", .enabled(if: apiKeyIsPresent()))
  func testReply_InThread_MaintainsContext() async throws {
    try await testReply_InThread_MaintainsContext_Impl()
  }

  @Test("Tool calling - basic calculation", .enabled(if: apiKeyIsPresent()))
  func testReply_WithTools_CallsCorrectTool() async throws {
    try await testReply_WithTools_CallsCorrectTool_Impl()
  }

  @Test("Tool calling - multiple tools", .enabled(if: apiKeyIsPresent()))
  func testReply_WithMultipleTools_SelectsCorrectTool() async throws {
    try await testReply_WithMultipleTools_SelectsCorrectTool_Impl()
  }

  @Test("Tool calling - with structured output", .enabled(if: apiKeyIsPresent()))
  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_WithTools_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("Tool calling - threaded conversation", .enabled(if: apiKeyIsPresent()))
  func testReply_WithTools_InThread_MaintainsContext() async throws {
    try await testReply_WithTools_InThread_MaintainsContext_Impl()
  }

  @Test("Multi-turn tool loop", .enabled(if: apiKeyIsPresent()))
  func testReply_MultiTurnToolLoop() async throws {
    try await testReply_MultiTurnToolLoop_Impl()
  }

  @Test("Tool calling - error handling", .enabled(if: apiKeyIsPresent()))
  func testReply_WithFailingTool_HandlesErrors() async throws {
    try await testReply_WithFailingTool_HandlesErrors_Impl()
  }

  @Test("Complex conversation history with structured analysis", .enabled(if: apiKeyIsPresent()))
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("History seeding for conversation continuity", .enabled(if: apiKeyIsPresent()))
  func testReply_ToSeededHistory_MaintainsContext() async throws {
    try await testReply_ToSeededHistory_MaintainsContext_Impl()
  }

  @Test("Threaded structured output conversation", .enabled(if: apiKeyIsPresent()))
  func testReply_InThread_ReturningStructured_MaintainsContext() async throws {
    try await testReply_InThread_ReturningStructured_MaintainsContext_Impl()
  }

  @Test("All constraint types with @Guide", .enabled(if: apiKeyIsPresent()))
  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent() async throws {
    try await testReply_ReturningConstrainedTypes_ReturnsCorrectContent_Impl()
  }

  // MARK: - OpenAI-Specific Tests

  @Test("Conversation with system prompt", .enabled(if: apiKeyIsPresent()))
  func testReply_ToSystemPrompt_ReturnsCorrectResponse() async throws {
    try await testReply_ToSystemPrompt_ReturnsCorrectResponse_Impl()
  }

  @Test("Error handling for invalid request", .enabled(if: apiKeyIsPresent()))
  func testReply_WithInvalidCredentials_ThrowsError() async throws {
    let invalidLLM = OpenaiLLM(apiToken: "invalid-key", model: "invalid-model-name-12345")

    let messages: [Message] = [
      .user(.init(text: "Hello"))
    ]

    await #expect(throws: (any Error).self) {
      _ = try await invalidLLM.reply(
        to: messages
      )
    }
  }

  @Test("API key validation")
  func testOpenaiLLM_WithApiKey_ReportsAvailability() {
    // Test with explicit API key
    let llmWithKey = OpenaiLLM(apiToken: "test-key", model: "gpt-4.1-nano")
    #expect(llmWithKey.isAvailable == true)

    // Test with empty API key
    let llmWithoutKey = OpenaiLLM(apiToken: "", model: "gpt-4.1-nano")
    #expect(llmWithoutKey.isAvailable == false)
  }

  @Test("Environment variable API key loading")
  func testOpenaiLLM_WithEnvironmentKey_ReportsAvailability() {
    // This test checks that the environment variable is read
    // The actual value depends on the test environment
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

    let hasEnvKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
    #expect(llm.isAvailable == hasEnvKey)
  }
}

/// Check if Openai API key is available for integration tests
private func apiKeyIsPresent() -> Bool {
  return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
}
