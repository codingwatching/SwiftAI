import Foundation
import SwiftAI
import Testing

struct StructuredContentTests {

  // MARK: - Basic JSON Parsing Tests

  @Test("Empty object JSON creates object with empty properties")
  func testInitFromJSON_EmptyObject_Succeeds() throws {
    let emptyObject = try StructuredContent(json: "{}")
    #expect(emptyObject.kind == .object([:]))
  }

  @Test("Empty array JSON creates array with no elements")
  func testInitFromJSON_EmptyArray_Succeeds() throws {
    let emptyArray = try StructuredContent(json: "[]")
    #expect(emptyArray.kind == .array([]))
  }

  @Test("Object with primitive types creates correct structured content")
  func testInitFromJSON_ObjectWithPrimitives_ReturnsCorrectContent() throws {
    let objectWithPrimitives = try StructuredContent(
      json: """
        {
          "string": "hello",
          "integer": 42,
          "number": 3.14,
          "boolean": true,
          "null": null
        }
        """)

    let expected = StructuredContent(
      kind: .object([
        "string": StructuredContent(kind: .string("hello")),
        "integer": StructuredContent(kind: .number(42.0)),
        "number": StructuredContent(kind: .number(3.14)),
        "boolean": StructuredContent(kind: .bool(true)),
        "null": StructuredContent(kind: .null),
      ]))

    #expect(objectWithPrimitives == expected)
  }

  @Test("Array with primitive types creates correct structured content")
  func testInitFromJSON_ArrayWithPrimitives_ReturnsCorrectContent() throws {
    let arrayWithPrimitives = try StructuredContent(json: "[1, \"hello\", true, null, 3.14]")

    let expected = StructuredContent(
      kind: .array([
        StructuredContent(kind: .number(1.0)),
        StructuredContent(kind: .string("hello")),
        StructuredContent(kind: .bool(true)),
        StructuredContent(kind: .null),
        StructuredContent(kind: .number(3.14)),
      ]))

    #expect(arrayWithPrimitives == expected)
  }

  @Test("Nested structures with users and scores creates correct hierarchy")
  func testInitFromJSON_NestedStructures_ReturnsCorrectHierarchy() throws {
    let nestedJSON = try StructuredContent(
      json: """
        {
          "users": [
            {
              "id": 1,
              "name": "Alice",
              "active": true,
              "scores": [95.5, 87.2, 92.1]
            },
            {
              "id": 2,
              "name": "Bob",
              "active": false,
              "scores": [78.9, 82.3]
            }
          ],
          "summary": {
            "total": 2,
            "active": 1,
            "averageScore": 87.2
          }
        }
        """)

    let expected = StructuredContent(
      kind: .object([
        "users": StructuredContent(
          kind: .array([
            StructuredContent(
              kind: .object([
                "id": StructuredContent(kind: .number(1.0)),
                "name": StructuredContent(kind: .string("Alice")),
                "active": StructuredContent(kind: .bool(true)),
                "scores": StructuredContent(
                  kind: .array([
                    StructuredContent(kind: .number(95.5)),
                    StructuredContent(kind: .number(87.2)),
                    StructuredContent(kind: .number(92.1)),
                  ])),
              ])),
            StructuredContent(
              kind: .object([
                "id": StructuredContent(kind: .number(2.0)),
                "name": StructuredContent(kind: .string("Bob")),
                "active": StructuredContent(kind: .bool(false)),
                "scores": StructuredContent(
                  kind: .array([
                    StructuredContent(kind: .number(78.9)),
                    StructuredContent(kind: .number(82.3)),
                  ])),
              ])),
          ])),
        "summary": StructuredContent(
          kind: .object([
            "total": StructuredContent(kind: .number(2.0)),
            "active": StructuredContent(kind: .number(1.0)),
            "averageScore": StructuredContent(kind: .number(87.2)),
          ])),
      ]))

    #expect(nestedJSON == expected)
  }

  // MARK: - Edge Cases and Boundary Tests

  @Test("Extreme numeric values are parsed correctly")
  func testInitFromJSON_ExtremeValues_ReturnsCorrectTypes() throws {
    // Test very large numbers
    let maxInt = try StructuredContent(json: "{\"value\": 9223372036854775807}")
    let expectedMaxInt = StructuredContent(
      kind: .object([
        "value": StructuredContent(kind: .number(Double(9_223_372_036_854_775_807)))
      ]))
    #expect(maxInt == expectedMaxInt)

    let minInt = try StructuredContent(json: "{\"value\": -9223372036854775808}")
    let expectedMinInt = StructuredContent(
      kind: .object([
        "value": StructuredContent(kind: .number(Double(-9_223_372_036_854_775_808)))
      ]))
    #expect(minInt == expectedMinInt)

    // Test very small numbers
    let smallNumber = try StructuredContent(json: "{\"value\": 1.175494351e-38}")
    let expectedSmallNumber = StructuredContent(
      kind: .object([
        "value": StructuredContent(kind: .number(1.175494351e-38))
      ]))
    #expect(smallNumber == expectedSmallNumber)

    // Test very large numbers
    let largeNumber = try StructuredContent(json: "{\"value\": 1.7976931348623157e+308}")
    let expectedLargeNumber = StructuredContent(
      kind: .object([
        "value": StructuredContent(kind: .number(1.7976931348623157e+308))
      ]))
    #expect(largeNumber == expectedLargeNumber)
  }

  @Test("Unicode strings including emojis and special characters are parsed correctly")
  func testInitFromJSON_UnicodeStrings_ReturnsCorrectContent() throws {
    // Test various unicode characters
    let unicodeString = try StructuredContent(json: "{\"text\": \"Hello 世界 🌍 🚀 测试\"}")
    let expectedUnicode = StructuredContent(
      kind: .object([
        "text": StructuredContent(kind: .string("Hello 世界 🌍 🚀 测试"))
      ]))
    #expect(unicodeString == expectedUnicode)

    // Test emoji
    let emojiString = try StructuredContent(json: "{\"text\": \"🎉🎊🎈🎁\"}")
    let expectedEmoji = StructuredContent(
      kind: .object([
        "text": StructuredContent(kind: .string("🎉🎊🎈🎁"))
      ]))
    #expect(emojiString == expectedEmoji)

    // Test special unicode characters
    let specialUnicode = try StructuredContent(
      json: "{\"text\": \"\\u0048\\u0065\\u006C\\u006C\\u006F\"}")
    let expectedSpecial = StructuredContent(
      kind: .object([
        "text": StructuredContent(kind: .string("Hello"))
      ]))
    #expect(specialUnicode == expectedSpecial)
  }

  @Test("Escaped characters in JSON strings are properly unescaped")
  func testInitFromJSON_EscapedCharacters_ReturnsCorrectContent() throws {
    let escapedString = try StructuredContent(
      json: "{\"text\": \"Line 1\\nLine 2\\tTabbed\\\"Quoted\\\"\\/Slash\\\\Backslash\"}")
    let expected = StructuredContent(
      kind: .object([
        "text": StructuredContent(
          kind: .string("Line 1\nLine 2\tTabbed\"Quoted\"/Slash\\Backslash"))
      ]))
    #expect(escapedString == expected)
  }

  // MARK: - Error Handling Tests

  @Test("Invalid JSON strings throw appropriate errors")
  func testInitFromJSON_InvalidJSON_ThrowsError() throws {
    // Test malformed JSON
    #expect(throws: (any Error).self) { try StructuredContent(json: "{ invalid json }") }
    #expect(throws: (any Error).self) { try StructuredContent(json: "[1, 2, 3") }
    #expect(throws: (any Error).self) { try StructuredContent(json: "\"unclosed string") }
    #expect(throws: (any Error).self) { try StructuredContent(json: "1, 2, 3") }
    #expect(throws: (any Error).self) { try StructuredContent(json: "true, false") }

    // Test empty string
    #expect(throws: (any Error).self) { try StructuredContent(json: "") }

    // Test whitespace only
    #expect(throws: (any Error).self) { try StructuredContent(json: "   ") }
  }

  // MARK: - Round-trip Tests

  @Test("Complex structures can be round-tripped through JSON without data loss")
  func testInitFromJSON_RoundTrip_ComplexStructures_ReturnsIdenticalContent() throws {
    let complexStructure = StructuredContent(
      kind: .object([
        "array": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(1))),
            StructuredContent(kind: .string("hello")),
            StructuredContent(kind: .bool(true)),
            StructuredContent(kind: .null),
            StructuredContent(kind: .number(3.14)),
          ])),
        "object": StructuredContent(
          kind: .object([
            "nested": StructuredContent(
              kind: .object([
                "deep": StructuredContent(
                  kind: .array([
                    StructuredContent(
                      kind: .object([
                        "a": StructuredContent(kind: .number(Double(1))),
                        "b": StructuredContent(kind: .number(Double(2))),
                      ])),
                    StructuredContent(
                      kind: .object([
                        "c": StructuredContent(kind: .number(Double(3))),
                        "d": StructuredContent(kind: .number(Double(4))),
                      ])),
                  ]))
              ]))
          ])),
        "mixed": StructuredContent(
          kind: .array([
            StructuredContent(
              kind: .object([
                "type": StructuredContent(kind: .string("user")),
                "active": StructuredContent(kind: .bool(true)),
              ])),
            StructuredContent(
              kind: .object([
                "type": StructuredContent(kind: .string("admin")),
                "active": StructuredContent(kind: .bool(false)),
              ])),
          ])),
      ]))

    try _testRoundTrip(of: complexStructure)
  }

  // MARK: - Performance Tests

  @Test("Large nested structures can be parsed efficiently")
  func testInitFromJSON_Performance_LargeStructure_Succeeds() throws {
    // Create a large nested structure
    var largeObject: [String: Any] = [:]
    for i in 0..<100 {
      largeObject["key\(i)"] = [
        "id": i,
        "name": "Item \(i)",
        "values": Array(0..<10).map { $0 * i },
        "nested": [
          "level1": [
            "level2": [
              "level3": "Deep value \(i)"
            ]
          ]
        ],
      ]
    }

    let jsonData = try JSONSerialization.data(withJSONObject: largeObject)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    // Note: Swift Testing doesn't have a direct equivalent to XCTest's measure
    // This test verifies the parsing works without performance measurement
    let content = try StructuredContent(json: jsonString)
    #expect(content.kind != StructuredContent.Kind.null)
  }

  // MARK: - Memory Tests

  @Test("Deep nesting does not cause stack overflow")
  func testInitFromJSON_Memory_DeepNesting_Succeeds() throws {
    // Test deep nesting to ensure no stack overflow (using reasonable depth)
    var deepJSON = "1"
    for _ in 0..<100 {
      deepJSON = "[\(deepJSON)]"
    }

    // This should not crash or cause stack overflow
    let content = try StructuredContent(json: deepJSON)
    #expect(content.kind != StructuredContent.Kind.null)
  }

  // MARK: - Concurrency Tests

  // MARK: - JSON String Conversion Tests

  @Test("JSON string conversion produces valid parseable JSON")
  func testJsonString_ProducesValidJSON_CanBeParsedBack() throws {
    let content = StructuredContent(
      kind: .object([
        "name": StructuredContent(kind: .string("Test")),
        "values": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(1))),
            StructuredContent(kind: .number(Double(2))),
            StructuredContent(kind: .number(Double(3))),
          ])),
        "nested": StructuredContent(
          kind: .object([
            "key": StructuredContent(kind: .string("value"))
          ])),
      ]))

    try _testRoundTrip(of: content)
  }

  @Test("JSON string conversion handles special characters correctly")
  func testJsonString_HandlesSpecialCharacters_CanBeParsedBack() throws {
    let content = StructuredContent(
      kind: .object([
        "text": StructuredContent(kind: .string("Line 1\nLine 2\tTabbed\"Quoted\""))
      ]))

    try _testRoundTrip(of: content)
  }

  // MARK: - JSON String Property Tests

  @Test("JSON string produces valid JSON for primitive types")
  func testJsonString_PrimitiveTypes_ProducesValidJSON() throws {
    // Test boolean
    let boolContent = StructuredContent(kind: .bool(true))
    let boolJSON = boolContent.jsonString
    #expect(boolJSON == "true")

    // Test null
    let nullContent = StructuredContent(kind: .null)
    let nullJSON = nullContent.jsonString
    #expect(nullJSON == "null")

    // Test integer
    let intContent = StructuredContent(kind: .number(Double(42)))
    let intJSON = intContent.jsonString
    #expect(intJSON == "42")

    // Test number
    let numberContent = StructuredContent(kind: .number(3.14))
    let numberJSON = numberContent.jsonString

    // Parse back to verify it's valid JSON (handles floating-point precision)
    let parsedNumber = try StructuredContent(json: "[\(numberJSON)]")
    #expect(parsedNumber.kind == .array([numberContent]))

    // Test string
    let stringContent = StructuredContent(kind: .string("hello"))
    let stringJSON = stringContent.jsonString
    #expect(stringJSON == "\"hello\"")
  }

  @Test("JSON string produces valid JSON for arrays")
  func testJsonString_Arrays_ProducesValidJSON() throws {
    // Empty array
    let emptyArray = StructuredContent(kind: .array([]))
    let emptyArrayJSON = emptyArray.jsonString
    #expect(emptyArrayJSON == "[]")

    // Array with primitives
    let arrayWithPrimitives = StructuredContent(
      kind: .array([
        StructuredContent(kind: .number(Double(1))),
        StructuredContent(kind: .string("hello")),
        StructuredContent(kind: .bool(true)),
        StructuredContent(kind: .null),
        StructuredContent(kind: .number(3.14)),
      ]))

    try _testRoundTrip(of: arrayWithPrimitives)

    // Nested arrays
    let nestedArray = StructuredContent(
      kind: .array([
        StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(1))),
            StructuredContent(kind: .number(Double(2))),
          ])),
        StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(3))),
            StructuredContent(kind: .number(Double(4))),
          ])),
      ]))
    let nestedArrayJSON = nestedArray.jsonString
    #expect(nestedArrayJSON == "[[1,2],[3,4]]")
  }

  @Test("JSON string produces valid JSON for objects")
  func testJsonString_Objects_ProducesValidJSON() throws {
    // Empty object
    let emptyObject = StructuredContent(kind: .object([:]))
    let emptyObjectJSON = emptyObject.jsonString
    #expect(emptyObjectJSON == "{}")

    // Object with primitives
    let objectWithPrimitives = StructuredContent(
      kind: .object([
        "string": StructuredContent(kind: .string("hello")),
        "integer": StructuredContent(kind: .number(Double(42))),
        "number": StructuredContent(kind: .number(3.14)),
        "boolean": StructuredContent(kind: .bool(true)),
        "null": StructuredContent(kind: .null),
      ]))

    try _testRoundTrip(of: objectWithPrimitives)

    // Nested objects
    let nestedObject = StructuredContent(
      kind: .object([
        "outer": StructuredContent(
          kind: .object([
            "inner": StructuredContent(kind: .string("value"))
          ]))
      ]))

    try _testRoundTrip(of: nestedObject)
  }

  @Test("JSON string handles complex nested structures")
  func testJsonString_ComplexNestedStructures_ProducesValidJSON() throws {
    let complexStructure = StructuredContent(
      kind: .object([
        "users": StructuredContent(
          kind: .array([
            StructuredContent(
              kind: .object([
                "id": StructuredContent(kind: .number(Double(1))),
                "name": StructuredContent(kind: .string("Alice")),
                "scores": StructuredContent(
                  kind: .array([
                    StructuredContent(kind: .number(95.5)),
                    StructuredContent(kind: .number(87.2)),
                  ])),
              ])),
            StructuredContent(
              kind: .object([
                "id": StructuredContent(kind: .number(Double(2))),
                "name": StructuredContent(kind: .string("Bob")),
                "scores": StructuredContent(
                  kind: .array([
                    StructuredContent(kind: .number(78.9))
                  ])),
              ])),
          ])),
        "summary": StructuredContent(
          kind: .object([
            "total": StructuredContent(kind: .number(Double(2))),
            "average": StructuredContent(kind: .number(87.2)),
          ])),
      ]))

    try _testRoundTrip(of: complexStructure)
  }

  @Test("JSON string preserves data types correctly")
  func testJsonString_DataTypes_PreservedCorrectly() throws {
    let numericContent = StructuredContent(
      kind: .object([
        "int": StructuredContent(kind: .number(Double(42))),
        "double": StructuredContent(kind: .number(3.14159)),
        "largeInt": StructuredContent(kind: .number(Double(9_223_372_036_854_775_807))),
        "smallDouble": StructuredContent(kind: .number(1.175494351e-38)),
      ]))

    try _testRoundTrip(of: numericContent)
  }

  @Test("JSON string handles edge cases correctly")
  func testJsonString_EdgeCases_HandledCorrectly() throws {
    // Empty string
    let emptyString = StructuredContent(kind: .string(""))
    let emptyStringJSON = emptyString.jsonString
    #expect(emptyStringJSON == "\"\"")

    // String with special characters
    let specialString = StructuredContent(kind: .string("Line 1\nLine 2\tTabbed\"Quoted\""))
    let specialStringJSON = specialString.jsonString
    #expect(specialStringJSON == "\"Line 1\\nLine 2\\tTabbed\\\"Quoted\\\"\"")

    // Very large numbers
    let largeNumber = StructuredContent(kind: .number(1.7976931348623157e+308))
    let largeNumberJSON = largeNumber.jsonString

    // Parse back to verify it's valid JSON
    let parsedLargeNumber = try StructuredContent(json: "[\(largeNumberJSON)]")
    #expect(parsedLargeNumber.kind == .array([largeNumber]))

    // Zero values
    let zeroInt = StructuredContent(kind: .number(Double(0)))
    let zeroDouble = StructuredContent(kind: .number(0.0))
    let zeroIntJSON = zeroInt.jsonString
    let zeroDoubleJSON = zeroDouble.jsonString

    // Parse back to verify they're valid JSON
    let parsedZeroInt = try StructuredContent(json: "[\(zeroIntJSON)]")
    let parsedZeroDouble = try StructuredContent(json: "[\(zeroDoubleJSON)]")
    #expect(parsedZeroInt.kind == .array([zeroInt]))

    // Note: JSONSerialization doesn't preserve the distinction between 0.0 and 0
    // Both serialize to "0" and parse back as integer 0, which is mathematically correct
    #expect(parsedZeroDouble.kind == .array([zeroInt]))
  }

  @Test("JSON string round-trip preserves exact values")
  func testJsonString_RoundTrip_PreservesExactValues() throws {
    let originalContent = StructuredContent(
      kind: .object([
        "mixed": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(0))),
            StructuredContent(kind: .number(0.0)),
            StructuredContent(kind: .bool(false)),
            StructuredContent(kind: .string("")),
            StructuredContent(kind: .null),
          ]))
      ]))

    let jsonString = originalContent.jsonString
    let roundTripContent = try StructuredContent(json: jsonString)

    // Note: JSONSerialization doesn't preserve the distinction between 0.0 and 0
    // Both serialize to "0" and parse back as integer 0, which is mathematically correct
    // So we test that the round-trip produces semantically equivalent content
    let expectedRoundTrip = StructuredContent(
      kind: .object([
        "mixed": StructuredContent(
          kind: .array([
            StructuredContent(kind: .number(Double(0))),
            StructuredContent(kind: .number(Double(0))),  // 0.0 becomes 0
            StructuredContent(kind: .bool(false)),
            StructuredContent(kind: .string("")),
            StructuredContent(kind: .null),
          ]))
      ]))

    #expect(roundTripContent == expectedRoundTrip)

    // Verify the JSON string can be parsed by standard JSON parsers
    let data = jsonString.data(using: .utf8)!
    let _ = try JSONSerialization.jsonObject(with: data)
  }
}

// TODO: Add a way to test the JSON string as well. `testRoundTrip(of:expectedJSON:)`.
func _testRoundTrip(of content: StructuredContent) throws {
  let got = try StructuredContent(json: content.jsonString)
  #expect(got == content)
}
