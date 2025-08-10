import SwiftAI
import Testing

struct ToolTests {

  @Test func testDefaultNameImplementation() {
    // Test that default name uses the type name directly
    #expect(GetWeatherTool().name == "GetWeatherTool")
    #expect(SearchContacts().name == "SearchContacts")
  }

  @Test func testJSONCallMethod() async throws {
    // Test that the default call(_ data: Data) implementation works correctly
    let tool = GetWeatherTool()
    let argumentsJSON = """
      {
        "city": "San Francisco"
      }
      """.data(using: .utf8)!

    let result = try await tool.call(argumentsJSON)

    #expect(
      result.chunks.contains { chunk in
        if case .text(let text) = chunk {
          return text == "Weather data for San Francisco"
        }
        return false
      }
    )
  }

  @Test func testJSONCallMethodFailsWithIncompatibleJSON() async throws {
    let tool = GetWeatherTool()

    // Test with missing required field
    let missingFieldJSON = """
      {
        "country": "USA"
      }
      """.data(using: .utf8)!

    await #expect(throws: (any Error).self) {
      try await tool.call(missingFieldJSON)
    }

    // Test with invalid JSON format
    let invalidJSON = "{ invalid json }".data(using: .utf8)!

    await #expect(throws: (any Error).self) {
      try await tool.call(invalidJSON)
    }

    // Test with wrong type for required field
    let wrongTypeJSON = """
      {
        "city": 12345
      }
      """.data(using: .utf8)!

    await #expect(throws: (any Error).self) {
      try await tool.call(wrongTypeJSON)
    }
  }
}

private struct GetWeatherTool: Tool {
  @Generable
  struct Arguments {
    let city: String
  }

  let description = "Gets weather information"

  func call(arguments: Arguments) async throws -> String {
    return "Weather data for \(arguments.city)"
  }
}

private struct SearchContacts: Tool {
  @Generable
  struct Arguments {
    let query: String
  }

  let description = "Searches contacts"

  func call(arguments: Arguments) async throws -> String {
    return "Contact results for \(arguments.query)"
  }
}
