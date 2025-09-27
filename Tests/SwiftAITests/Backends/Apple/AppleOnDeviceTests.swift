#if canImport(FoundationModels)
import Foundation
import SwiftAI
import SwiftAILLMTesting
import Testing

@Suite("Apple On-Device LLM Tests")
struct AppleOnDeviceTests: LLMBaseTestCases {
  var llm: some LLM {
    if #available(iOS 26.0, macOS 26.0, *) {
      return SystemLLM()
    } else {
      return CrashingLLM()
    }
  }

  // MARK: - Basic Tests

  @Test("Basic text generation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyToPrompt() async throws {
    try await testReplyToPrompt_Impl()
  }

  @Test(
    "Basic text generation - history verification", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyToPrompt_ReturnsCorrectHistory() async throws {
    try await testReplyToPrompt_ReturnsCorrectHistory_Impl()
  }

  @Test("Max tokens constraint - very short response", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithMaxTokens1_ReturnsVeryShortResponse() async throws {
    try await testReply_WithMaxTokens1_ReturnsVeryShortResponse_Impl()
  }

  // MARK: - Streaming Tests

  @Test("Streaming text generation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_ReturningText_EmitsMultipleTextPartials() async throws {
    try await testReplyStream_ReturningText_EmitsMultipleTextPartials_Impl()
  }

  @Test("Streaming text generation - history verification", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_ReturningText_ReturnsCorrectHistory() async throws {
    try await testReplyStream_ReturningText_ReturnsCorrectHistory_Impl()
  }

  @Test("Streaming maintains session context", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_InSession_MaintainsContext() async throws {
    try await testReplyStream_InSession_MaintainsContext_Impl()
  }

  // MARK: - Structured Output Tests

  @Test("Structured output - primitives content", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectContent() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectContent_Impl()
  }

  @Test("Structured output - primitives history", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - arrays content", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectContent() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectContent_Impl()
  }

  @Test("Structured output - arrays history", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - nested objects", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningNestedObjects_ReturnsCorrectContent() async throws {
    try await testReply_ReturningNestedObjects_ReturnsCorrectContent_Impl()
  }

  // MARK: - Session Tests

  @Test("Session maintains conversation context", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_InSession_MaintainsContext() async throws {
    try await testReply_InSession_MaintainsContext_Impl()
  }

  @Test("Session returns correct history", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_InSession_ReturnsCorrectHistory() async throws {
    try await testReply_InSession_ReturnsCorrectHistory_Impl()
  }

  // MARK: - Prewarming Tests

  @Test("Prewarming does not break normal operation", .enabled(if: appleIntelligenceIsAvailable()))
  func testPrewarm_DoesNotBreakNormalOperation() async throws {
    try await testPrewarm_DoesNotBreakNormalOperation_Impl()
  }

  // MARK: - Tool Calling Tests

  @Test("Tool calling - basic calculation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithTools_CallsCorrectTool() async throws {
    try await testReply_WithTools_CallsCorrectTool_Impl()
  }

  @Test("Tool calling - multiple tools", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithMultipleTools_SelectsCorrectTool() async throws {
    try await testReply_WithMultipleTools_SelectsCorrectTool_Impl()
  }

  @Test("Tool calling - with structured output", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_WithTools_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("Tool calling - session-based conversation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithTools_InSession_MaintainsContext() async throws {
    try await testReply_WithTools_InSession_MaintainsContext_Impl()
  }

  @Test("Multi-turn tool loop", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_MultiTurnToolLoop() async throws {
    try await testReply_MultiTurnToolLoop_Impl(using: llm)
  }

  @Test("Tool calling - error handling", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithFailingTool_Fails() async throws {
    try await testReply_WithFailingTool_Fails_Impl()
  }

  // MARK: - Streaming Tool Calling Tests

  @Test("Streaming tool calling - basic calculation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_WithTools_CallsCorrectTool() async throws {
    try await testReplyStream_WithTools_CallsCorrectTool_Impl()
  }

  @Test("Streaming tool calling - multiple tools", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_WithMultipleTools_SelectsCorrectTool() async throws {
    try await testReplyStream_WithMultipleTools_SelectsCorrectTool_Impl()
  }

  @Test("Streaming multi-turn tool loop", .enabled(if: appleIntelligenceIsAvailable()))
  func testReplyStream_MultiTurnToolLoop() async throws {
    try await testReplyStream_MultiTurnToolLoop_Impl(using: llm)
  }

  // MARK: - Complex Conversation Tests

  @Test(
    "Complex conversation history with structured analysis",
    .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("History seeding for conversation continuity", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToChatContinuation() async throws {
    try await testReply_ToChatContinuation_Impl()
  }

  @Test(
    "Session-based structured output conversation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_InSession_ReturningStructured_MaintainsContext() async throws {
    try await testReply_InSession_ReturningStructured_MaintainsContext_Impl()
  }

  @Test("All constraint types with @Guide", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent() async throws {
    try await testReply_ReturningConstrainedTypes_ReturnsCorrectContent_Impl()
  }

  @Test("System prompt conversation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithSystemPrompt() async throws {
    try await testReply_WithSystemPrompt_Impl()
  }

  // MARK: - Streaming Structured Output Tests (Disabled for SystemLLM)

  @Test(.disabled("Streaming structured output not yet implemented for SystemLLM"))
  func testReplyStream_ReturningPrimitives_EmitsProgressivePartials() async throws {}

  @Test(.disabled("Streaming structured output not yet implemented for SystemLLM"))
  func testReplyStream_ReturningArrays_EmitsProgressivePartials() async throws {}

  @Test(.disabled("Streaming structured output not yet implemented for SystemLLM"))
  func testReplyStream_ReturningNestedObjects_EmitsProgressivePartials() async throws {}

  @Test(.disabled("Streaming structured output not yet implemented for SystemLLM"))
  func testReplyStream_ReturningStructured_InSession_MaintainsContext() async throws {}

  @Test(.enabled(if: appleIntelligenceIsAvailable()))
  func testAvailability_PropertyReflectsCorrectStatus() async throws {
    #expect(llm.availability == .available)
  }
}

private func appleIntelligenceIsAvailable() -> Bool {
  if #available(iOS 26.0, macOS 26.0, *) {
    return SystemLLM().isAvailable
  } else {
    return false
  }
}
#endif
