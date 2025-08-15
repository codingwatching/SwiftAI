#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing

@Suite("Apple On-Device LLM Tests")
struct AppleOnDeviceTests: LLMBaseTestCases {
  var llm: SystemLLM {
    SystemLLM()
  }

  // Helper function to check if Apple Intelligence is available
  private func appleIntelligenceIAvailable() -> Bool {
    SystemLLM().isAvailable
  }

  // MARK: - Basic Tests

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Basic text generation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToPrompt() async throws {
    try await testReply_ToPrompt_Impl()
  }

  // MARK: - Structured Output Tests

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Structured output - primitives content", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectContent() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectContent_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Structured output - primitives history", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningPrimitives_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningPrimitives_ReturnsCorrectHistory_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Structured output - arrays content", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectContent() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectContent_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Structured output - arrays history", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningArrays_ReturnsCorrectHistory() async throws {
    try await testReply_ReturningArrays_ReturnsCorrectHistory_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Structured output - nested objects", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningNestedObjects_ReturnsCorrectContent() async throws {
    try await testReply_ReturningNestedObjects_ReturnsCorrectContent_Impl()
  }

  // MARK: - Threading Tests

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Thread maintains conversation context", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_InThread_MaintainsContext() async throws {
    try await testReply_InThread_MaintainsContext_Impl()
  }

  // MARK: - Tool Calling Tests

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Tool calling - basic calculation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_CallsCorrectTool() async throws {
    try await testReply_WithTools_CallsCorrectTool_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Tool calling - multiple tools", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithMultipleTools_SelectsCorrectTool() async throws {
    try await testReply_WithMultipleTools_SelectsCorrectTool_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Tool calling - with structured output", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_WithTools_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Tool calling - threaded conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithTools_InThread_MaintainsContext() async throws {
    try await testReply_WithTools_InThread_MaintainsContext_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Tool calling - error handling", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_WithFailingTool_HandlesErrors() async throws {
    try await testReply_WithFailingTool_HandlesErrors_Impl()
  }

  // MARK: - Complex Conversation Tests

  @available(iOS 26.0, macOS 26.0, *)
  @Test(
    "Complex conversation history with structured analysis",
    .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws {
    try await testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("History seeding for conversation continuity", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToSeededHistory_MaintainsContext() async throws {
    try await testReply_ToSeededHistory_MaintainsContext_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("Threaded structured output conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_InThread_ReturningStructured_MaintainsContext() async throws {
    try await testReply_InThread_ReturningStructured_MaintainsContext_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("All constraint types with @Guide", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent() async throws {
    try await testReply_ReturningConstrainedTypes_ReturnsCorrectContent_Impl()
  }

  @available(iOS 26.0, macOS 26.0, *)
  @Test("System prompt conversation", .enabled(if: appleIntelligenceIAvailable()))
  func testReply_ToSystemPrompt_ReturnsCorrectResponse() async throws {
    try await testReply_ToSystemPrompt_ReturnsCorrectResponse_Impl()
  }
}
#endif
