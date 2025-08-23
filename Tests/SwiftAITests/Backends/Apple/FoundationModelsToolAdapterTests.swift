#if canImport(FoundationModels)
import Testing
import FoundationModels
@testable import SwiftAI

struct FoundationModelsToolAdapterTests {

  // MARK: - Tests

  @Test("Adapter correctly implements FoundationModels.Tool")
  @available(iOS 26.0, macOS 26.0, *)
  func testFoundationModelsToolConformance() throws {
    let adapter = FoundationModelsToolAdapter(wrapping: MockSwiftAITool())

    #expect(adapter.name == "MockTool")
    #expect(adapter.description == "A mock tool for testing")
    #expect(adapter.includesSchemaInInstructions == true)

    /// TODO: Test that the parameters are correctly mapped when we have a good solution for
    /// testing against FoundationModels.GeneratedContent
  }

  @Test("Adapter successfully calls underlying SwiftAI tool")
  @available(iOS 26.0, macOS 26.0, *)
  func testSuccessfulToolCall() async throws {
    let adapter = FoundationModelsToolAdapter(wrapping: MockSwiftAITool())

    let mockGeneratedContent = try GeneratedContent(
      json: """
        {
          "input": "hello world",
          "count": 42
        }
        """)
    let args = try FoundationModelsToolAdapter.Args(mockGeneratedContent)
    let resultPrompt = try await adapter.call(arguments: args)

    #expect(resultPrompt.text.contains("Mock result"))
    #expect(resultPrompt.text.contains("hello world"))
    #expect(resultPrompt.text.contains("count: 42"))
  }

  @Test("Adapter handles bad input gracefully")
  @available(iOS 26.0, macOS 26.0, *)
  func testBadInputHandling() async throws {
    let adapter = FoundationModelsToolAdapter(wrapping: MockSwiftAITool())

    let invalidGeneratedContent = try GeneratedContent(
      json: """
        {
          "wrong_field": "value"
        }
        """)
    let args = try FoundationModelsToolAdapter.Args(invalidGeneratedContent)

    // Expect this to throw an error due to bad input
    await #expect(throws: LLMError.self) {
      _ = try await adapter.call(arguments: args)
    }
  }

  @Test("Adapter handles tool execution failures")
  @available(iOS 26.0, macOS 26.0, *)
  func testToolExecutionFailure() async throws {
    let adapter = FoundationModelsToolAdapter(wrapping: ThrowingSwiftAITool())

    let mockGeneratedContent = try GeneratedContent(
      json: """
        {
          "input": "test input"
        }
        """)
    let args = try FoundationModelsToolAdapter.Args(mockGeneratedContent)

    do {
      _ = try await adapter.call(arguments: args)
      Issue.record("Expected tool execution to fail, but it succeeded.")
    } catch let error as LLMError {
      switch error {
      case .toolExecutionFailed(let tool, let underlyingError):
        #expect(tool.name == "ThrowingTool")
        #expect(underlyingError is FakeSwiftError)
      default:
        Issue.record("Unexpected error: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}

// MARK: - Test Tool Implementation

struct MockSwiftAITool: SwiftAI.Tool {
  @SwiftAI.Generable
  struct Arguments {
    let input: String
    let count: Int
  }

  let name = "MockTool"
  let description = "A mock tool for testing"

  func call(arguments: Arguments) async throws -> String {
    return "Mock result: \(arguments.input) (count: \(arguments.count))"
  }
}

// MARK: - Additional Test Tools

struct ThrowingSwiftAITool: SwiftAI.Tool {
  @SwiftAI.Generable
  struct Arguments {
    let input: String
  }

  let name = "ThrowingTool"
  let description = "A tool that throws errors for testing"

  func call(arguments: Arguments) async throws -> String {
    throw FakeSwiftError.somethingWentWrong
  }
}

enum FakeSwiftError: Error {
  case somethingWentWrong

  var errorDescription: String? {
    switch self {
    case .somethingWentWrong:
      return "Something went wrong in the fake error."
    }
  }
}
#endif
