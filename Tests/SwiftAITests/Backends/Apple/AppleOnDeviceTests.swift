#if canImport(FoundationModels)
import Foundation
import SwiftAI
import Testing

// TODO: Create a more comprehensive test suite for AppleOnDevice inference.

@available(iOS 26.0, macOS 26.0, *)
@Test func basicTextGeneration() async throws {
  let systemLLM = SystemLLM()

  // Skip test if Apple Intelligence not available
  guard systemLLM.isAvailable else {
    // TODO: How to handle such cases in tests.
    return  // Test passes by skipping
  }

  let reply = try await systemLLM.reply(
    to: [UserMessage(text: "Say hello in exactly one word.")]
  )

  #expect(!reply.content.isEmpty)
  #expect(reply.history.count == 2)
  #expect(reply.history[0].role == .user)
  #expect(reply.history[1].role == .ai)
}

@Generable
struct SimpleResponse: Equatable {
  let message: String
  let count: Int
  let isValid: Bool
}

@available(iOS 26.0, macOS 26.0, *)
@Test func structuredOutput_Primitives_Content() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let reply: LLMReply<SimpleResponse> = try await systemLLM.reply(
    to: "Create a simple response with message 'Hello', count 42, and isValid true",
    returning: SimpleResponse.self
  )

  let expected = SimpleResponse(message: "Hello", count: 42, isValid: true)
  #expect(reply.content == expected)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func structuredOutput_Primitives_History() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let reply: LLMReply<SimpleResponse> = try await systemLLM.reply(
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

@Generable
struct ArrayResponse: Equatable {
  let items: [String]
  let numbers: [Int]
}

@available(iOS 26.0, macOS 26.0, *)
@Test func structuredOutput_WithArrays_Content() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let reply: LLMReply<ArrayResponse> = try await systemLLM.reply(
    to: "Create a response with items ['apple', 'banana'] and numbers [1, 2, 3]",
    returning: ArrayResponse.self
  )

  let expected = ArrayResponse(items: ["apple", "banana"], numbers: [1, 2, 3])
  #expect(reply.content == expected)
}

@available(iOS 26.0, macOS 26.0, *)
@Test func structuredOutput_WithArrays_History() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let reply: LLMReply<ArrayResponse> = try await systemLLM.reply(
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

@Generable
struct Person: Equatable {
  let name: String
  let age: Int
  let address: Address
}

@Generable
struct Address: Equatable {
  let street: String
  let city: String
  let zipCode: Int
}

@available(iOS 26.0, macOS 26.0, *)
@Test("System LLM with nested structured output")
func structuredOutput_NestedObjects_Content() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let reply: LLMReply<Person> = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func threadMaintainsConversationContext() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  // Create a new thread for conversation
  var thread = try systemLLM.makeThread()

  // Turn 1: Introduce name
  let reply1 = try await systemLLM.reply(
    to: "Hi my name is Achraf",
    in: &thread
  )

  #expect(!reply1.content.isEmpty)
  #expect(reply1.history.count == 2)  // User message + AI response
  #expect(reply1.history[0].role == Role.user)
  #expect(reply1.history[1].role == Role.ai)

  // Turn 2: Ask for name recall
  let reply2 = try await systemLLM.reply(
    to: "What's my name?",
    in: &thread
  )

  #expect(!reply2.content.isEmpty)
  #expect(reply2.content.contains("Achraf"))  // Should remember the name
  #expect(reply2.history.count == 4)  // Full conversation history: User1 + AI1 + User2 + AI2

  // Turn 3: Request structured output with name context
  let reply3 = try await systemLLM.reply(
    to: "Create a SimpleResponse with my name in the message, count 1, and isValid true",
    returning: SimpleResponse.self,
    in: &thread
  )

  #expect(reply3.content.message.contains("Achraf"))  // Should include name in structured response
  #expect(reply3.content.count == 1)
  #expect(reply3.content.isValid == true)
}

// MARK: - Tool Calling Tests

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

@Generable
struct CalculationResult: Equatable {
  let calculation: String
  let result: Double
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

@available(iOS 26.0, macOS 26.0, *)
@Test func toolCalling_BasicCalculation() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let calculatorTool = MockCalculatorTool()

  let _ = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func toolCalling_MultipleTools() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let calculatorTool = MockCalculatorTool()
  let weatherTool = MockWeatherTool()

  let _ = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func toolCalling_WithStructuredOutput() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let calculatorTool = MockCalculatorTool()

  let reply: LLMReply<CalculationResult> = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func toolCalling_ThreadedConversation() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let calculatorTool = MockCalculatorTool()
  let weatherTool = MockWeatherTool()

  // Create thread with tools
  var thread = try systemLLM.makeThread(tools: [calculatorTool, weatherTool])

  // First interaction: calculator
  let _ = try await systemLLM.reply(
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
  let _ = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func toolCalling_ErrorHandling() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let failingTool = FailingTool()

  // Test that tool errors are properly handled
  do {
    let _ = try await systemLLM.reply(
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

@Generable
struct ConversationSummary: Equatable {
  @Guide(description: "List of cities mentioned in weather queries")
  let citiesMentioned: [String]

  @Guide(description: "Summary of the conversation flow in 2-3 sentences")
  let conversationSummary: String
}

@available(iOS 26.0, macOS 26.0, *)
@Test func systemLLM_ComplexConversationHistory_StructuredAnalysis() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

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
        "The weather in Paris is currently 22°C and sunny. Perfect weather for outdoor activities!"),
    UserMessage(
      text:
        "Please analyze our entire conversation and provide a structured summary including the number of calculations, cities mentioned, results, and any failures that occurred."
    ),
  ]

  let reply = try await systemLLM.reply(
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

@available(iOS 26.0, macOS 26.0, *)
@Test func systemLLM_HistorySeeding_ConversationContinuity() async throws {
  let systemLLM = SystemLLM()

  guard systemLLM.isAvailable else {
    return  // Skip test if Apple Intelligence not available
  }

  let weatherTool = MockWeatherTool()

  // First inference: Start a conversation about weather
  let initialConversation: [any Message] = [
    SystemMessage(text: "You are a helpful weather assistant."),
    UserMessage(text: "What's the weather like in Tokyo?"),
  ]
  let firstReply = try await systemLLM.reply(
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
  let secondReply = try await systemLLM.reply(
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

#endif
