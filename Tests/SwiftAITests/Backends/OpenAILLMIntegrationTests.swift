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

  @Test("Structured output generation", .enabled(if: apiKeyIsPresent()))
  func testStructuredOutput() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    let response = try await llm.reply(
      to: [
        UserMessage(text: "Create a user profile for John Smith, age 30, email john@example.com")
      ],
      tools: [],
      returning: UserProfile.self,
      options: LLMReplyOptions()
    )

    #expect(!response.content.name.isEmpty)
    #expect(response.content.age == 30)
    #expect(response.content.email == "john@example.com")
    #expect(response.history.count == 2)  // User message + AI response
    #expect(response.history.last?.role == .ai)
  }

  @Test("Threaded structured output conversation", .enabled(if: apiKeyIsPresent()))
  func testThreadedStructuredOutput() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    // Create thread with initial context
    var thread = try llm.makeThread(
      tools: [],
      messages: [SystemMessage(text: "You are a helpful assistant that creates user profiles.")]
    )

    // First exchange - create a user profile
    let firstResponse = try await llm.reply(
      to: "Create a profile for Alice Johnson, age 25",
      returning: UserProfile.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    #expect(firstResponse.content.name.lowercased() == "alice johnson")
    #expect(firstResponse.content.age == 25)

    // Second exchange - should remember the context and create another profile
    let secondResponse = try await llm.reply(
      to: "What's the age of Alice?",
      returning: String.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    #expect(secondResponse.content.contains("25"))
  }

  @Test("All constraint types with @Guide", .enabled(if: apiKeyIsPresent()))
  func testAllConstraintTypes() async throws {
    let llm = OpenAILLM(model: "gpt-4.1-nano")

    let response = try await llm.reply(
      to: [
        UserMessage(
          text:
            """
            Create comprehensive data: email john@test.com, age 30, priority high, price 25.99, 
            verified true, not active, exactly 3 tags, and no description. For others use sensible defaults.
            """
        )
      ],
      tools: [],
      returning: ComprehensiveProfile.self,
      options: LLMReplyOptions()
    )

    // String pattern constraint
    #expect(response.content.email == "john@test.com")

    // String enum constraint
    #expect(response.content.priority == "high")

    // String constant constraint
    #expect(response.content.category == "default")

    // Integer range constraints
    #expect(response.content.age == 30)
    // #expect(response.content.score == 75) // FIXME: Enable when constraints are working.
    // #expect(response.content.rating == 4) // FIXME: Enable when constraints are working.

    // Double range constraints
    #expect(response.content.price == 25.99)
    // #expect(response.content.weight == 0.1) // FIXME: Enable when constraints are working.

    // Boolean constant constraints
    #expect(response.content.isVerified == true)
    #expect(response.content.isActive == false)

    // Array count constraints
    #expect(response.content.tags.count == 5)
    #expect(response.content.tags.allSatisfy { $0 == "A" || $0 == "B" || $0 == "C" })
    #expect(response.content.features.count >= 1 && response.content.features.count <= 5)
    #expect(response.content.notes.count <= 3)

    // Optional fields
    #expect(response.content.description == nil)
  }
}

// MARK: - Test Types

@Generable
struct UserProfile {
  let name: String
  @Guide(.minimum(1), .maximum(120))
  let age: Int
  let email: String?
}

@Generable
struct ComprehensiveProfile {
  // String constraints
  @Guide(.pattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"))
  let email: String

  @Guide(.anyOf(["low", "medium", "high"]))
  let priority: String

  @Guide(.constant("default"))
  let category: String

  // Integer constraints
  @Guide(.minimum(18), .maximum(100))
  let age: Int

  @Guide(.range(0...100))
  let score: Int

  @Guide(.range(1...5))
  let rating: Int

  // Double constraints
  @Guide(.minimum(0.01), .maximum(999.99))
  let price: Double

  @Guide(.range(0.1...500.0))
  let weight: Double

  // Boolean constraints
  let isVerified: Bool

  let isActive: Bool

  // Array constraints
  @Guide<[String]>(.count(5), .element(.anyOf(["A", "B", "C"])))
  let tags: [String]

  @Guide<[String]>(.minimumCount(1))  // FIXME: Automatic type inference fails without passing `[String]`
  let features: [String]

  @Guide<[String]>(.maximumCount(3))  // FIXME: Automatic type inference fails without passing `[String]`
  let notes: [String]

  // Optional field
  let description: String?

  @Guide(description: "internal field", .constant("TOKEN"))
  let token: String
}

// MARK: - Test Helpers

/// Check if OpenAI API key is available for integration tests
private func apiKeyIsPresent() -> Bool {
  return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
}
