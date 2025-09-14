#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing
import FoundationModels

@Suite("Apple On-Device LLM Tests")
struct AppleOnDeviceTests: LLMBaseTestCases {
  var llm: some LLM {
    if #available(iOS 26.0, macOS 26.0, *) {
      return SystemLLM()
    } else {
      // Test will not run when Apple Intelligence is not available.
      // Test will not run when Apple Intelligence is not available.
      return FakeLLM()
    }
  }

  // MARK: - Basic Tests

  @Test("Basic text generation", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToPrompt() async throws {
    try await testReply_ToPrompt_Impl()
  }

  @Test(
    "Basic text generation - history verification", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToPrompt_ReturnsCorrectHistory() async throws {
    try await testReply_ToPrompt_ReturnsCorrectHistory_Impl()
  }

  @Test("Max tokens constraint - very short response", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_WithMaxTokens1_ReturnsVeryShortResponse() async throws {
    try await testReply_WithMaxTokens1_ReturnsVeryShortResponse_Impl()
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
  func testReply_WithFailingTool_HandlesErrors() async throws {
    try await testReply_WithFailingTool_HandlesErrors_Impl()
  }

  // MARK: - Complex Conversation Tests

  @Test(
    "Complex conversation history with structured analysis",
    .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @Test("History seeding for conversation continuity", .enabled(if: appleIntelligenceIsAvailable()))
  func testReply_ToSeededHistory_MaintainsContext() async throws {
    try await testReply_ToSeededHistory_MaintainsContext_Impl()
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
  func testReply_ToSystemPrompt_ReturnsCorrectResponse() async throws {
    try await testReply_ToSystemPrompt_ReturnsCorrectResponse_Impl()
  }

  @Test
  func testAvailability_PropertyReflectsCorrectStatus() async throws {
    if appleIntelligenceIsAvailable() {
      #expect(llm.availability == .available)
    } else {
      guard case .unavailable = llm.availability else {
        if #available(iOS 26.0, macOS 26.0, *) {
          // This should not happen since Apple Intelligence is not available.
          Issue.record(
            """
            Apple Intelligence is not available, but LLM reports available. 
            [\(FoundationModels.SystemLanguageModel().isAvailable)] 
            [\(FoundationModels.SystemLanguageModel().availability)]
            GOT [\(llm.availability)]
            """
          )
        } else {
          Issue.record(
            "Got \(llm.availability). Want 'unavailable' status."
          )
        }
        return
      }
    }
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
