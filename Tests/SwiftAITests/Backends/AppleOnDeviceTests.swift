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

  let reply: LLMReply<String>
  do {
    reply = try await systemLLM.reply(
      to: [UserMessage(text: "Say hello in exactly one word.")],
    )
  } catch {
    throw error
  }

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

// FIXME: This test is currently disabled because the the conversion to FoundationModels.GenerationSchema is not complete.
@available(iOS 26.0, macOS 26.0, *)
@Test("System LLM with nested structured output", .disabled())
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
#endif
