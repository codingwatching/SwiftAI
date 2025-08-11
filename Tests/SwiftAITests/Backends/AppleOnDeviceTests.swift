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
    to: [UserMessage(text: "Say hello in exactly one word.")],
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
    to: [
      UserMessage(text: "Create a simple response with message 'Hello', count 42, and isValid true")
    ],
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
    to: [UserMessage(text: "Create a simple response")],
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
    to: [
      UserMessage(text: "Create a response with items ['apple', 'banana'] and numbers [1, 2, 3]")
    ],
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
    to: [UserMessage(text: "Create a response with arrays")],
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
    to: [
      UserMessage(
        text: "Create a person named John, age 30, living at 123 Main St, New York, 10001")
    ],
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
  var thread = systemLLM.makeThread(tools: [], messages: [])

  // Turn 1: Introduce name
  let reply1 = try await systemLLM.reply(
    to: "Hi my name is Achraf",
    returning: String.self,
    in: &thread,
    options: .default
  )

  #expect(!reply1.content.isEmpty)
  #expect(reply1.history.count == 2)  // User message + AI response
  #expect(reply1.history[0].role == Role.user)
  #expect(reply1.history[1].role == Role.ai)

  // Turn 2: Ask for name recall
  let reply2 = try await systemLLM.reply(
    to: "What's my name?",
    returning: String.self,
    in: &thread,
    options: .default
  )

  #expect(!reply2.content.isEmpty)
  #expect(reply2.content.contains("Achraf"))  // Should remember the name
  #expect(reply2.history.count == 2)  // Current exchange only

  // Turn 3: Request structured output with name context
  let reply3 = try await systemLLM.reply(
    to: "Create a SimpleResponse with my name in the message, count 1, and isValid true",
    returning: SimpleResponse.self,
    in: &thread,
    options: .default
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
    to: [UserMessage(text: "Calculate 15 + 27 using the calculator tool")],
    tools: [calculatorTool],
    returning: String.self
  )

  // Verify the calculator tool was called with correct arguments
  #expect(calculatorTool.wasCalledWith != nil)
  if let args = calculatorTool.wasCalledWith {
    #expect(args.operation == "add")
    #expect(args.a == 15.0)
    #expect(args.b == 27.0)
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
    to: [UserMessage(text: "What's the weather in New York?")],
    tools: [calculatorTool, weatherTool],
    returning: String.self
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
    to: [UserMessage(text: "Calculate 10 * 5 and return the result in the specified format")],
    tools: [calculatorTool],
    returning: CalculationResult.self
  )

  // Verify the calculator tool was called with correct arguments
  #expect(calculatorTool.wasCalledWith != nil)
  if let args = calculatorTool.wasCalledWith {
    #expect(args.operation == "multiply")
    #expect(args.a == 10.0)
    #expect(args.b == 5.0)
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
  var thread = systemLLM.makeThread(tools: [calculatorTool, weatherTool], messages: [])

  // First interaction: calculator
  let _ = try await systemLLM.reply(
    to: "Calculate 5 + 3",
    returning: String.self,
    in: &thread,
    options: .default
  )

  // Verify calculator was called correctly
  #expect(calculatorTool.wasCalledWith != nil)
  if let args = calculatorTool.wasCalledWith {
    #expect(args.operation == "add")
    #expect(args.a == 5.0)
    #expect(args.b == 3.0)
  }

  // Reset call history for second test
  calculatorTool.resetCallHistory()

  // Second interaction: weather (should maintain context)
  let _ = try await systemLLM.reply(
    to: "Now tell me about the weather in Paris",
    returning: String.self,
    in: &thread,
    options: .default
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
      to: [UserMessage(text: "Use the failing_tool with input 'test'")],
      tools: [failingTool],
      returning: String.self
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

#endif
