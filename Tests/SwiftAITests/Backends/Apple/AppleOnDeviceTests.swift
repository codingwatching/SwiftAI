#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing

@Suite("Apple On-Device LLM Tests")
struct AppleOnDeviceTests: LLMBaseTestCases {
  var llm: some LLM {
    if #available(iOS 26.0, macOS 26.0, *) {
      return SystemLLM()
    } else {
      return FakeLLM()
    }
  }

  // MARK: - Basic Tests

  @Test("Basic text generation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToPrompt() async throws {
    try await testReply_ToPrompt_Impl()
  }

  @Test("Basic text generation - history verification", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToPrompt_ReturnsCorrectHistory() async throws {
    try await testReply_ToPrompt_ReturnsCorrectHistory_Impl()
  }

  @Test("Max tokens constraint - very short response", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithMaxTokens1_ReturnsVeryShortResponse() async throws {
    try await testReply_WithMaxTokens1_ReturnsVeryShortResponse_Impl()
  }

  // MARK: - Structured Output Tests

  @Test("Structured output - primitives content", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectContent() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectContent_Impl()
  }

  @Test("Structured output - primitives history", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - arrays content", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectContent() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectContent_Impl()
  }

  @Test("Structured output - arrays history", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectHistory_Impl()
  }

  @Test("Structured output - nested objects", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningNestedObjects_ReturnsCorrectContent() async throws {
    try await testReply_ReturningNestedObjects_ReturnsCorrectContent_Impl()
  }

  // MARK: - Threading Tests

  @Test("Thread maintains conversation context", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_InThread_MaintainsContext() async throws {
    try await testReply_InThread_MaintainsContext_Impl()
  }

  // MARK: - Tool Calling Tests

  @Test("Tool calling - basic calculation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_CallsCorrectTool() async throws {
    try await testReply_WithTools_CallsCorrectTool_Impl()
  }

  @Test("Tool calling - multiple tools", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithMultipleTools_SelectsCorrectTool() async throws {
    try await testReply_WithMultipleTools_SelectsCorrectTool_Impl()
  }

  @Test("Tool calling - with structured output", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_WithTools_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("Tool calling - threaded conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_InThread_MaintainsContext() async throws {
    try await testReply_WithTools_InThread_MaintainsContext_Impl()
  }

  @Test("Multi-turn tool loop", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_MultiTurnToolLoop() async throws {
    try await testReply_MultiTurnToolLoop_Impl(using: llm)
  }

  @Test("Tool calling - error handling", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithFailingTool_HandlesErrors() async throws {
    try await testReply_WithFailingTool_HandlesErrors_Impl()
  }

  // MARK: - Complex Conversation Tests

  @Test(
    "Complex conversation history with structured analysis",
    .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("History seeding for conversation continuity", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToSeededHistory_MaintainsContext() async throws {
    try await testReply_ToSeededHistory_MaintainsContext_Impl()
  }

  @Test("Threaded structured output conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_InThread_ReturningStructured_MaintainsContext() async throws {
    try await testReply_InThread_ReturningStructured_MaintainsContext_Impl()
  }

  @Test("All constraint types with @Guide", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent() async throws {
    try await testReply_ReturningConstrainedTypes_ReturnsCorrectContent_Impl()
  }

  @Test("System prompt conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToSystemPrompt_ReturnsCorrectResponse() async throws {
    try await testReply_ToSystemPrompt_ReturnsCorrectResponse_Impl()
  }
}

private func appleIntelligenceIAvailable() -> Bool {
  if #available(iOS 26.0, macOS 26.0, *) {
    return SystemLLM().isAvailable
  } else {
    return false
  }
}
#endif
