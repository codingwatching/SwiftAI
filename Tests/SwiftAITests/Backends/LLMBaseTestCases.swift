import Foundation
import SwiftAI
import Testing

protocol LLMBaseTestCases {
  associatedtype LLMType: LLM

  var llm: LLMType { get }

  // MARK: - Basic Tests
  func testReply_ToPrompt() async throws

  // MARK: - Structured Output Tests
  func testReply_ReturningPrimitives_ReturnsCorrectContent() async throws
  func testReply_ReturningPrimitives_ReturnsCorrectHistory() async throws
  func testReply_ReturningArrays_ReturnsCorrectContent() async throws
  func testReply_ReturningArrays_ReturnsCorrectHistory() async throws
  func testReply_ReturningNestedObjects_ReturnsCorrectContent() async throws

  // MARK: - Threading Tests
  func testReply_InThread_MaintainsContext() async throws

  // MARK: - Tool Calling Tests
  func testReply_WithTools_CallsCorrectTool() async throws
  func testReply_WithMultipleTools_SelectsCorrectTool() async throws
  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent() async throws
  func testReply_WithTools_InThread_MaintainsContext() async throws
  func testReply_WithFailingTool_HandlesErrors() async throws

  // MARK: - Complex Conversation Tests
  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent() async throws
  func testReply_ToSeededHistory_MaintainsContext() async throws
  func testReply_InThread_ReturningStructured_MaintainsContext() async throws
  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent() async throws
  func testReply_ToSystemPrompt_ReturnsCorrectResponse() async throws
}

extension LLMBaseTestCases {
  func testReply_ToPrompt_Impl() async throws {
    let reply = try await llm.reply(
      to: [UserMessage(text: "Say hello in exactly one word.")]
    )

    #expect(!reply.content.isEmpty)
    #expect(reply.history.count == 2)
    #expect(reply.history[0].role == .user)
    #expect(reply.history[1].role == .ai)
  }

  func testReply_ReturningPrimitives_ReturnsCorrectContent_Impl() async throws {
    let reply: LLMReply<SimpleResponse> = try await llm.reply(
      to: "Create a simple response with message 'Hello', count 42, and isValid true",
      returning: SimpleResponse.self
    )

    let expected = SimpleResponse(message: "Hello", count: 42, isValid: true)
    #expect(reply.content == expected)
  }

  func testReply_ReturningPrimitives_ReturnsCorrectHistory_Impl() async throws {
    let reply = try await llm.reply(
      to: "Create a simple response",
      returning: SimpleResponse.self
    )

    #expect(reply.history.count == 2)
    #expect(reply.history[0].role == .user)
    #expect(reply.history[1].role == .ai)

    // Check that the AI message contains structured content
    let aiMessage = reply.history[1]
    #expect(aiMessage.chunks.count == 1)
    if case .structured(let jsonString) = aiMessage.chunks[0] {
      #expect(jsonString.contains("message"))
      #expect(jsonString.contains("count"))
      #expect(jsonString.contains("isValid"))
    } else {
      Issue.record("Expected structured content chunk")
    }
  }

  func testReply_ReturningArrays_ReturnsCorrectContent_Impl() async throws {
    let reply: LLMReply<ArrayResponse> = try await llm.reply(
      to: "Create a response with items ['apple', 'banana'] and numbers [1, 2, 3]",
      returning: ArrayResponse.self
    )

    let expected = ArrayResponse(items: ["apple", "banana"], numbers: [1, 2, 3])
    #expect(reply.content == expected)
  }

  func testReply_ReturningArrays_ReturnsCorrectHistory_Impl() async throws {
    let reply: LLMReply<ArrayResponse> = try await llm.reply(
      to: "Create a response with arrays",
      returning: ArrayResponse.self
    )

    #expect(reply.history.count == 2)
    #expect(reply.history[1].role == .ai)

    let aiMessage = reply.history[1]
    if case .structured(let jsonString) = aiMessage.chunks[0] {
      #expect(jsonString.contains("items"))
      #expect(jsonString.contains("numbers"))
    } else {
      Issue.record("Expected structured content chunk")
    }
  }

  func testReply_ReturningNestedObjects_ReturnsCorrectContent_Impl() async throws {
    let reply: LLMReply<Person> = try await llm.reply(
      to: "Create a person named John, age 30, living at 123 Main St, New York, 10001",
      returning: Person.self
    )

    let expected = Person(
      name: "John",
      age: 30,
      address: Address(street: "123 Main St", city: "New York", zipCode: 10001)
    )
    #expect(reply.content == expected)
  }

  func testReply_InThread_MaintainsContext_Impl() async throws {
    // Create a new thread for conversation
    var thread = try llm.makeThread()

    // Turn 1: Introduce name
    let reply1 = try await llm.reply(
      to: "Hi my name is Achraf",
      in: &thread
    )

    #expect(!reply1.content.isEmpty)
    #expect(reply1.history.count == 2)  // User message + AI response
    #expect(reply1.history[0].role == Role.user)
    #expect(reply1.history[1].role == Role.ai)

    // Turn 2: Ask for name recall
    let reply2 = try await llm.reply(
      to: "What's my name?",
      in: &thread
    )

    #expect(!reply2.content.isEmpty)
    #expect(reply2.content.contains("Achraf"))  // Should remember the name
    #expect(reply2.history.count == 4)  // Full conversation history: User1 + AI1 + User2 + AI2

    // Turn 3: Request structured output with name context
    let reply3 = try await llm.reply(
      to: "Create a SimpleResponse with my name in the message, count 1, and isValid true",
      returning: SimpleResponse.self,
      in: &thread
    )

    #expect(reply3.content.message.contains("Achraf"))  // Should include name in structured response
    #expect(reply3.content.count == 1)
    #expect(reply3.content.isValid == true)
  }

  // MARK: - Tool Calling Tests

  func testReply_WithTools_CallsCorrectTool_Impl() async throws {
    let calculatorTool = MockCalculatorTool()

    let _ = try await llm.reply(
      to: "Calculate 15 + 27 using the calculator tool",
      tools: [calculatorTool]
    )

    // Verify the calculator tool was called with correct arguments
    #expect(calculatorTool.wasCalledWith != nil)
    if let args = calculatorTool.wasCalledWith {
      #expect(args.operation == "add")
      #expect([args.a, args.b].sorted() == [15.0, 27.0])
    }
  }

  func testReply_WithMultipleTools_SelectsCorrectTool_Impl() async throws {
    let calculatorTool = MockCalculatorTool()
    let weatherTool = MockWeatherTool()

    let _ = try await llm.reply(
      to: "What's the weather in New York?",
      tools: [calculatorTool, weatherTool]
    )

    // Verify the weather tool was called and calculator tool was not
    #expect(weatherTool.wasCalledWith != nil)
    #expect(calculatorTool.wasCalledWith == nil)

    if let args = weatherTool.wasCalledWith {
      #expect(args.city == "New York")
    }
  }

  func testReply_WithTools_ReturningStructured_ReturnsCorrectContent_Impl() async throws {
    let calculatorTool = MockCalculatorTool()

    let reply: LLMReply<CalculationResult> = try await llm.reply(
      to: "Calculate 10 * 5 and return the result in the specified format",
      tools: [calculatorTool],
      returning: CalculationResult.self
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

  func testReply_WithTools_InThread_MaintainsContext_Impl() async throws {
    let calculatorTool = MockCalculatorTool()
    let weatherTool = MockWeatherTool()

    // Create thread with tools
    var thread = try llm.makeThread(tools: [calculatorTool, weatherTool])

    // First interaction: calculator
    let _ = try await llm.reply(
      to: "Calculate 5 + 3",
      in: &thread
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
      in: &thread
    )

    // Verify weather tool was called and calculator was not called again
    #expect(weatherTool.wasCalledWith != nil)
    #expect(calculatorTool.wasCalledWith == nil)

    if let args = weatherTool.wasCalledWith {
      #expect(args.city == "Paris")
    }
  }

  func testReply_WithFailingTool_HandlesErrors_Impl() async throws {
    let failingTool = FailingTool()

    // Test that tool errors are properly handled
    do {
      let _ = try await llm.reply(
        to: "Use the failing_tool with input 'test'",
        tools: [failingTool]
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

  // MARK: - Phase 6 Tests: Complex Conversation Scenarios

  func testReply_ToComplexHistory_ReturningStructured_ReturnsCorrectContent_Impl() async throws {
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
          "Please analyze our entire conversation and provide a structured summary including the number of calculations, cities mentioned, results, and any failures that occurred."
      ),
    ]

    let reply = try await llm.reply(
      to: messages,
      tools: [MockCalculatorTool(), MockWeatherTool()],
      returning: ConversationSummary.self
    )

    let summary = reply.content
    #expect(summary.citiesMentioned.contains("Paris"), "Should identify Paris as mentioned city")
    #expect(!summary.conversationSummary.isEmpty, "Should provide conversation summary")
    #expect(summary.conversationSummary.count > 20, "Summary should be substantial")

    #expect(
      reply.history.count >= messages.count + 1,
      "Should contain full history plus new response")
  }

  func testReply_ToSeededHistory_MaintainsContext_Impl() async throws {
    let weatherTool = MockWeatherTool()

    // First inference: Start a conversation about weather
    let initialConversation: [any Message] = [
      SystemMessage(text: "You are a helpful weather assistant."),
      UserMessage(text: "What's the weather like in Tokyo?"),
    ]
    let firstReply = try await llm.reply(
      to: initialConversation,
      tools: [weatherTool]
    )

    #expect(!firstReply.content.isEmpty)
    #expect(firstReply.history.count == 5)  // System + User + Tool Call + Tool Output + AI

    // Seed the complete history from first reply into second call
    let historyBasedConversation =
      firstReply.history + [
        UserMessage(text: "Which city did I ask about in our conversation?")
      ]
    let secondReply = try await llm.reply(
      to: historyBasedConversation,
      tools: [weatherTool]
    )

    // Verify the LLM remembers the city from the conversation history
    #expect(secondReply.content.contains("Tokyo"), "Should remember Tokyo was mentioned")
    // Verify conversation continuity - second reply should build on first
    #expect(
      secondReply.history.count >= historyBasedConversation.count + 1,
      "Should preserve full conversation flow")
  }

  func testReply_InThread_ReturningStructured_MaintainsContext_Impl() async throws {
    // Create thread with initial context
    var thread = try llm.makeThread(
      messages: [SystemMessage(text: "You are a helpful assistant that creates user profiles.")]
    )

    // First exchange - create a user profile
    let firstResponse = try await llm.reply(
      to: "Create a profile for Alice Johnson, age 25",
      returning: UserProfile.self,
      in: &thread
    )

    #expect(firstResponse.content.name.lowercased() == "alice johnson")
    #expect(firstResponse.content.age == 25)

    // Second exchange - should remember the context and create another profile
    let secondResponse = try await llm.reply(
      to: "What's the age of Alice?",
      in: &thread
    )

    #expect(secondResponse.content.contains("25"))
  }

  func testReply_ReturningConstrainedTypes_ReturnsCorrectContent_Impl() async throws {
    let response = try await llm.reply(
      to: """
        Create comprehensive data: email john@test.com, age 30, priority high, price 25.99, 
        verified true, not active, exactly 3 tags, and no description. For others use sensible defaults.
        """,
      returning: ComprehensiveProfile.self
    )

    // String pattern constraint
    #expect(response.content.email == "john@test.com")

    // String enum constraint
    #expect(response.content.priority == "high")

    // String constant constraint
    #expect(response.content.category == "default")

    // Integer range constraints
    #expect(response.content.age == 30)
    // FIXME: Enable when Openai numeric constraints are working.
    // #expect(response.content.score >= 0 && response.content.score <= 100)
    // #expect(response.content.rating >= 1 && response.content.rating <= 5)

    // Double range constraints
    #expect(response.content.price == 25.99)
    // FIXME: Enable when Openai numeric constraints are working.
    // #expect(response.content.weight == 0.1)

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

  func testReply_ToSystemPrompt_ReturnsCorrectResponse_Impl() async throws {
    let messages: [any Message] = [
      SystemMessage(text: "You are a helpful math tutor. Always show your work."),
      UserMessage(text: "What is 15 × 7?"),
    ]

    let response = try await llm.reply(
      to: messages
    )

    #expect(!response.content.isEmpty)
    #expect(response.history.count == 3)  // System + User + AI
    #expect(response.history.first?.role == .system)
    #expect(response.history.last?.role == .ai)
    #expect(response.content.localizedCaseInsensitiveContains("105"))
    #expect(response.content.count > 3)  // Should show work
  }

}

// MARK: - Test Types
@Generable
struct SimpleResponse: Equatable {
  let message: String
  let count: Int
  let isValid: Bool
}

@Generable
struct ArrayResponse: Equatable {
  let items: [String]
  let numbers: [Int]
}

@Generable
struct Address: Equatable {
  let street: String
  let city: String
  let zipCode: Int
}

@Generable
struct Person: Equatable {
  let name: String
  let age: Int
  let address: Address
}

@Generable
struct CalculationResult: Equatable {
  let calculation: String
  let result: Double
}

@Generable
struct ConversationSummary: Equatable {
  @Guide(description: "List of cities mentioned in weather queries")
  let citiesMentioned: [String]

  @Guide(description: "Summary of the conversation flow in 2-3 sentences")
  let conversationSummary: String
}

@Generable
struct UserProfile: Equatable {
  let name: String
  @Guide(.minimum(1), .maximum(120))
  let age: Int
  let email: String?
}

@Generable
struct ComprehensiveProfile: Equatable {
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

// MARK: - Mock Tools

final class MockWeatherTool: @unchecked Sendable, Tool {
  @Generable
  struct Arguments {
    let city: String
    @Guide(description: "Unit for temperature", .anyOf(["celsius", "fahrenheit"]))
    let unit: String?
  }

  let name = "get_weather"
  let description = "Gets the current weather for a city"

  private(set) var callHistory: [Arguments] = []
  var wasCalledWith: Arguments?

  func resetCallHistory() {
    callHistory.removeAll()
    wasCalledWith = nil
  }

  func call(arguments: Arguments) async throws -> String {
    callHistory.append(arguments)
    wasCalledWith = arguments

    let unit = arguments.unit ?? "celsius"
    return "Weather in \(arguments.city): 22°\(unit == "fahrenheit" ? "F" : "C"), sunny"
  }
}

/// Mock tool for testing tool calling functionality
final class MockCalculatorTool: @unchecked Sendable, Tool {
  @Generable
  struct Arguments {
    @Guide(
      description: "The operation to perform", .anyOf(["add", "subtract", "multiply", "divide"]))
    let operation: String
    let a: Double
    let b: Double
  }

  let name = "calculator"
  let description = "Performs basic arithmetic operations"

  private(set) var callHistory: [Arguments] = []
  var wasCalledWith: Arguments?

  func resetCallHistory() {
    callHistory.removeAll()
    wasCalledWith = nil
  }

  func call(arguments: Arguments) async throws -> String {
    callHistory.append(arguments)
    wasCalledWith = arguments

    switch arguments.operation {
    case "add":
      return "Result: \(arguments.a + arguments.b)"
    case "multiply":
      return "Result: \(arguments.a * arguments.b)"
    case "subtract":
      return "Result: \(arguments.a - arguments.b)"
    case "divide":
      guard arguments.b != 0 else {
        throw LLMError.generalError("Division by zero")
      }
      return "Result: \(arguments.a / arguments.b)"
    default:
      throw LLMError.generalError("Unsupported operation: \(arguments.operation)")
    }
  }
}

final class FailingTool: @unchecked Sendable, Tool {
  @Generable
  struct Arguments {
    let input: String
  }

  let name = "failing_tool"
  let description = "A tool that always fails"

  private(set) var callHistory: [Arguments] = []
  var wasCalledWith: Arguments?

  func resetCallHistory() {
    callHistory.removeAll()
    wasCalledWith = nil
  }

  func call(arguments: Arguments) async throws -> String {
    callHistory.append(arguments)
    wasCalledWith = arguments

    throw LLMError.generalError("Tool execution failed deliberately")
  }
}
