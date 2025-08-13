import Foundation
import Testing

@testable import SwiftAI

@Suite("Openai LLM Integration Tests")
struct OpenaiLLMIntegrationTests {

  @Test("Basic text generation", .enabled(if: apiKeyIsPresent()))
  func testBasicTextGeneration() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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
    let llm = OpenaiLLM(model: "invalid-model-name-12345")

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
    let llmWithKey = OpenaiLLM(apiToken: "test-key", model: "gpt-4.1-nano")
    #expect(llmWithKey.isAvailable == true)

    // Test with empty API key
    let llmWithoutKey = OpenaiLLM(apiToken: "", model: "gpt-4.1-nano")
    #expect(llmWithoutKey.isAvailable == false)
  }

  @Test("Environment variable API key loading")
  func testEnvironmentVariableLoading() {
    // This test checks that the environment variable is read
    // The actual value depends on the test environment
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

    let hasEnvKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
    #expect(llm.isAvailable == hasEnvKey)
  }

  @Test("Structured output generation", .enabled(if: apiKeyIsPresent()))
  func testStructuredOutput() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

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

  // MARK: - Tool Calling Tests
  // TODO: Refactor tests later so that tool calling tests can be run over all backends (Openai + Apple on-device)

  @Test("Basic calculation with tool calling", .enabled(if: apiKeyIsPresent()))
  func testToolCallingBasicCalculation() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let calculatorTool = MockCalculatorTool()

    let _ = try await llm.reply(
      to: [UserMessage(text: "Calculate 15 + 27 using the calculator tool")],
      tools: [calculatorTool],
      returning: String.self,
      options: LLMReplyOptions()
    )

    // Verify the calculator tool was called with correct arguments
    #expect(calculatorTool.wasCalledWith != nil)
    if let args = calculatorTool.wasCalledWith {
      #expect(args.operation == "add")
      #expect([args.a, args.b].sorted() == [15.0, 27.0])
    }
  }

  @Test("Multiple tools available - correct tool selection", .enabled(if: apiKeyIsPresent()))
  func testToolCallingMultipleTools() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let calculatorTool = MockCalculatorTool()
    let weatherTool = MockWeatherTool()

    let _ = try await llm.reply(
      to: [UserMessage(text: "What's the weather in New York?")],
      tools: [calculatorTool, weatherTool],
      returning: String.self,
      options: LLMReplyOptions()
    )

    // Verify the weather tool was called and calculator tool was not
    #expect(weatherTool.wasCalledWith != nil)
    #expect(calculatorTool.wasCalledWith == nil)

    if let args = weatherTool.wasCalledWith {
      #expect(args.city == "New York")
    }
  }

  @Test("Tool calling with structured output", .enabled(if: apiKeyIsPresent()))
  func testToolCallingWithStructuredOutput() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let calculatorTool = MockCalculatorTool()

    let reply: LLMReply<CalculationResult> = try await llm.reply(
      to: [UserMessage(text: "Calculate 10 * 5 and return the result in the specified format")],
      tools: [calculatorTool],
      returning: CalculationResult.self,
      options: LLMReplyOptions()
    )

    // Verify the calculator tool was called with correct arguments
    #expect(calculatorTool.wasCalledWith != nil)
    if let args = calculatorTool.wasCalledWith {
      #expect(args.operation == "multiply")
      #expect([args.a, args.b].sorted() == [5.0, 10.0])
    }

    // Also verify structured output contains expected result
    #expect(!reply.content.calculation.isEmpty)
    #expect(reply.content.result == 50.0)
  }

  @Test("Threaded conversation with tool calling", .enabled(if: apiKeyIsPresent()))
  func testToolCallingThreadedConversation() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let calculatorTool = MockCalculatorTool()
    let weatherTool = MockWeatherTool()

    // Create thread with tools
    var thread = try llm.makeThread(tools: [calculatorTool, weatherTool], messages: [])

    // First interaction: calculator
    let _ = try await llm.reply(
      to: "Calculate 5 + 3",
      returning: String.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    // Verify calculator was called correctly
    #expect(calculatorTool.wasCalledWith != nil)
    if let args = calculatorTool.wasCalledWith {
      #expect(args.operation == "add")
      #expect([args.a, args.b].sorted() == [3.0, 5.0])
    }

    // Reset call history for second test
    calculatorTool.resetCallHistory()

    // Second interaction: weather (should maintain context)
    let _ = try await llm.reply(
      to: "Now tell me about the weather in Paris",
      returning: String.self,
      in: &thread,
      options: LLMReplyOptions()
    )

    // Verify weather tool was called and calculator was not called again
    #expect(weatherTool.wasCalledWith != nil)
    #expect(calculatorTool.wasCalledWith == nil)

    if let args = weatherTool.wasCalledWith {
      #expect(args.city == "Paris")
    }
  }

  @Test("Tool error handling", .enabled(if: apiKeyIsPresent()))
  func testToolCallingErrorHandling() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let failingTool = FailingTool()

    // Test that tool errors are properly handled
    do {
      let _ = try await llm.reply(
        to: [UserMessage(text: "Use the failing_tool with input 'test'")],
        tools: [failingTool],
        returning: String.self,
        options: LLMReplyOptions()
      )
      Issue.record("Expected tool execution to fail, but it succeeded.")
    } catch {
      // Verify the failing tool was called with correct arguments before failing
      #expect(failingTool.wasCalledWith != nil)
      if let args = failingTool.wasCalledWith {
        #expect(args.input == "test")
      }

      // Tool errors should be wrapped in LLMError
      #expect(error is LLMError)
    }
  }

  @Test("Complex conversation history with structured analysis", .enabled(if: apiKeyIsPresent()))
  func testComplexConversationHistoryStructuredAnalysis() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")

    let messages: [any Message] = [
      SystemMessage(
        text:
          "You are a helpful assistant that can perform calculations and provide weather information. Always be accurate and detailed in your responses."
      ),
      UserMessage(text: "Please calculate 15 + 27 for me"),
      AIMessage(chunks: [
        .text("I'll calculate that for you using the calculator tool."),
        .toolCall(
          ToolCall(
            id: "call-1",
            toolName: "calculator",
            arguments: #"{"operation": "add", "a": 15.0, "b": 27.0}"#
          )),
      ]),
      SwiftAI.ToolOutput(
        id: "call-1",
        toolName: "calculator",
        chunks: [.text("Result: 42.0")]
      ),
      AIMessage(chunks: [
        .text("The calculation is complete."),
        .structured(#"{"calculation": "15 + 27", "result": 42.0, "verified": true}"#),
      ]),
      UserMessage(text: "Now tell me about the weather in Paris"),
      AIMessage(chunks: [
        .text("Let me check the weather in Paris for you."),
        .toolCall(
          ToolCall(
            id: "call-2",
            toolName: "get_weather",
            arguments: #"{"city": "Paris", "unit": "celsius"}"#
          )),
      ]),
      SwiftAI.ToolOutput(
        id: "call-2",
        toolName: "get_weather",
        chunks: [.text("Weather in Paris: 22°C, sunny")]
      ),
      AIMessage(
        text:
          "The weather in Paris is currently 22°C and sunny. Perfect weather for outdoor activities!"
      ),
      UserMessage(
        text:
          "Please analyze our entire conversation and provide a structured summary including cities mentioned and conversation flow."
      ),
    ]

    let reply = try await llm.reply(
      to: messages,
      tools: [MockCalculatorTool(), MockWeatherTool()],
      returning: ConversationSummary.self,
      options: LLMReplyOptions()
    )

    let summary = reply.content
    #expect(summary.citiesMentioned.contains("Paris"), "Should identify Paris as mentioned city")
    #expect(!summary.conversationSummary.isEmpty, "Should provide conversation summary")
    #expect(summary.conversationSummary.count > 20, "Summary should be substantial")

    #expect(
      reply.history.count >= messages.count + 1,
      "Should contain full history plus new response")
  }

  @Test("History seeding for conversation continuity", .enabled(if: apiKeyIsPresent()))
  func testHistorySeedingConversationContinuity() async throws {
    let llm = OpenaiLLM(model: "gpt-4.1-nano")
    let weatherTool = MockWeatherTool()

    // First inference: Start a conversation about weather
    let initialConversation: [any Message] = [
      SystemMessage(text: "You are a helpful weather assistant."),
      UserMessage(text: "What's the weather like in Tokyo?"),
    ]
    let firstReply = try await llm.reply(
      to: initialConversation,
      tools: [weatherTool],
      returning: String.self,
      options: LLMReplyOptions()
    )

    #expect(!firstReply.content.isEmpty)
    #expect(firstReply.history.count >= 4)  // System + User + AI with tool call + Tool Output + AI

    // Seed the complete history from first reply into second call
    let historyBasedConversation =
      firstReply.history + [
        UserMessage(text: "Which city did I ask about in our conversation?")
      ]
    let secondReply = try await llm.reply(
      to: historyBasedConversation,
      tools: [weatherTool],
      returning: String.self,
      options: LLMReplyOptions()
    )

    // Verify the LLM remembers the city from the conversation history
    #expect(secondReply.content.contains("Tokyo"), "Should remember Tokyo was mentioned")
    // Verify conversation continuity - second reply should build on first
    #expect(
      secondReply.history.count >= historyBasedConversation.count + 1,
      "Should preserve full conversation flow")
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

/// Check if Openai API key is available for integration tests
private func apiKeyIsPresent() -> Bool {
  return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
}
